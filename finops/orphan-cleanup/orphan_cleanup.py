#!/usr/bin/env python3
"""Finds AWS resources left running outside TenantForge's apply-demo-destroy
cost pattern (see docs/adr/0001-architecture-foundations.md and
docs/roadmap.md's cost tiers).

Matches on the exact tagging convention infra/terraform/aws actually
uses (envs/dev/dev.tfvars): tag `project` = the given --project value, or
a resource name prefixed `<project>-`. Covers the resources that module
set provisions and that cost money while idle: EKS clusters, EC2
instances, NAT Gateways, unassociated Elastic IPs, and unattached EBS
volumes.

Dry-run by default — lists what it finds and does nothing else. Pass
--delete to actually terminate/release what it finds; every deletion is
logged individually and the run summary reports what was (or would be)
removed.
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass, field

import boto3
from botocore.exceptions import ClientError


@dataclass
class Orphan:
    kind: str
    id: str
    name: str
    extra: str = ""


@dataclass
class ScanResult:
    orphans: list[Orphan] = field(default_factory=list)

    def add(self, kind: str, id: str, name: str, extra: str = "") -> None:
        self.orphans.append(Orphan(kind, id, name, extra))


def _matches_project(project: str, name: str | None, tags: dict[str, str]) -> bool:
    if tags.get("project") == project:
        return True
    return bool(name) and name.startswith(f"{project}-")


def _tag_dict(tag_list) -> dict[str, str]:
    return {t["Key"]: t.get("Value", "") for t in (tag_list or [])}


def scan_eks_clusters(session: boto3.Session, project: str, result: ScanResult) -> None:
    eks = session.client("eks")
    for name in eks.list_clusters().get("clusters", []):
        cluster = eks.describe_cluster(name=name)["cluster"]
        tags = cluster.get("tags", {})
        if _matches_project(project, name, tags):
            result.add("EKS cluster", cluster["arn"], name, f"status={cluster['status']}")


def scan_ec2_instances(session: boto3.Session, project: str, result: ScanResult) -> None:
    ec2 = session.client("ec2")
    paginator = ec2.get_paginator("describe_instances")
    for page in paginator.paginate(
        Filters=[{"Name": "instance-state-name", "Values": ["running", "stopped", "pending", "stopping"]}]
    ):
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                tags = _tag_dict(instance.get("Tags"))
                name = tags.get("Name", "")
                if _matches_project(project, name, tags):
                    result.add(
                        "EC2 instance",
                        instance["InstanceId"],
                        name or instance["InstanceId"],
                        f"state={instance['State']['Name']}, type={instance['InstanceType']}",
                    )


def scan_nat_gateways(session: boto3.Session, project: str, result: ScanResult) -> None:
    ec2 = session.client("ec2")
    for gw in ec2.describe_nat_gateways(Filter=[{"Name": "state", "Values": ["available", "pending"]}])[
        "NatGateways"
    ]:
        tags = _tag_dict(gw.get("Tags"))
        name = tags.get("Name", "")
        if _matches_project(project, name, tags):
            # NAT Gateways bill hourly regardless of traffic — the single
            # most common source of a silent bleed after a demo.
            result.add("NAT Gateway", gw["NatGatewayId"], name or gw["NatGatewayId"], "bills hourly while it exists")


def scan_unassociated_eips(session: boto3.Session, project: str, result: ScanResult) -> None:
    ec2 = session.client("ec2")
    for addr in ec2.describe_addresses()["Addresses"]:
        if addr.get("AssociationId"):
            continue  # in use, not an orphan
        tags = _tag_dict(addr.get("Tags"))
        name = tags.get("Name", "")
        if _matches_project(project, name, tags):
            result.add(
                "Unassociated Elastic IP", addr.get("AllocationId", addr.get("PublicIp", "")), name or addr.get("PublicIp", ""), "AWS bills unattached EIPs"
            )


def scan_unattached_volumes(session: boto3.Session, project: str, result: ScanResult) -> None:
    ec2 = session.client("ec2")
    for vol in ec2.describe_volumes(Filters=[{"Name": "status", "Values": ["available"]}])["Volumes"]:
        tags = _tag_dict(vol.get("Tags"))
        name = tags.get("Name", "")
        if _matches_project(project, name, tags):
            result.add(
                "Unattached EBS volume", vol["VolumeId"], name or vol["VolumeId"], f"{vol['Size']}GiB, orphaned from a deleted node"
            )


SCANNERS = [scan_eks_clusters, scan_ec2_instances, scan_nat_gateways, scan_unassociated_eips, scan_unattached_volumes]


def scan(session: boto3.Session, project: str) -> ScanResult:
    result = ScanResult()
    for scanner in SCANNERS:
        try:
            scanner(session, project, result)
        except ClientError as exc:
            print(f"warning: {scanner.__name__} failed: {exc}", file=sys.stderr)
    return result


def delete_orphan(session: boto3.Session, orphan: Orphan) -> None:
    ec2 = session.client("ec2")
    eks = session.client("eks")
    if orphan.kind == "EKS cluster":
        eks.delete_cluster(name=orphan.name)
    elif orphan.kind == "EC2 instance":
        ec2.terminate_instances(InstanceIds=[orphan.id])
    elif orphan.kind == "NAT Gateway":
        ec2.delete_nat_gateway(NatGatewayId=orphan.id)
    elif orphan.kind == "Unassociated Elastic IP":
        ec2.release_address(AllocationId=orphan.id)
    elif orphan.kind == "Unattached EBS volume":
        ec2.delete_volume(VolumeId=orphan.id)
    else:
        raise ValueError(f"no delete handler for kind {orphan.kind!r}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="tenantforge", help="tag/name prefix to match (default: tenantforge)")
    parser.add_argument("--region", default=None, help="AWS region (default: your AWS CLI/env default)")
    parser.add_argument("--delete", action="store_true", help="actually delete found resources (default: dry run)")
    args = parser.parse_args(argv)

    session = boto3.Session(region_name=args.region)
    result = scan(session, args.project)

    if not result.orphans:
        print(f"No orphaned '{args.project}' resources found in {session.region_name}.")
        return 0

    print(f"Found {len(result.orphans)} '{args.project}' resource(s) in {session.region_name}:\n")
    for o in result.orphans:
        print(f"  [{o.kind}] {o.name} ({o.id}) — {o.extra}")

    if not args.delete:
        print("\nDry run — nothing deleted. Re-run with --delete to remove these.")
        return 1

    print()
    for o in result.orphans:
        print(f"  deleting [{o.kind}] {o.name} ({o.id})...")
        delete_orphan(session, o)
    print(f"\nDeleted {len(result.orphans)} resource(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
