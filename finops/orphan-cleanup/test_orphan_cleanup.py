"""Unit tests for orphan_cleanup.py against mocked AWS (moto) — no real
account, no real spend. The live-account dry run only proves "found
nothing," which is exactly as true if the matching logic were silently
broken as if it were correct. These tests prove the positive case: given
a resource that should match, it's found; given one that shouldn't, it
isn't.
"""
import boto3
import pytest
from moto import mock_aws

from orphan_cleanup import delete_orphan, scan


@pytest.fixture
def session():
    with mock_aws():
        yield boto3.Session(region_name="eu-north-1")


def test_finds_ec2_instance_by_tag(session):
    ec2 = session.client("ec2")
    ami = ec2.describe_images()["Images"][0]["ImageId"] if ec2.describe_images()["Images"] else "ami-12345678"
    ec2.run_instances(
        ImageId=ami,
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{"ResourceType": "instance", "Tags": [{"Key": "project", "Value": "tenantforge"}]}],
    )

    result = scan(session, "tenantforge")

    assert any(o.kind == "EC2 instance" for o in result.orphans)


def test_ignores_instance_from_other_project(session):
    ec2 = session.client("ec2")
    images = ec2.describe_images()["Images"]
    ami = images[0]["ImageId"] if images else "ami-12345678"
    ec2.run_instances(
        ImageId=ami,
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{"ResourceType": "instance", "Tags": [{"Key": "project", "Value": "some-other-project"}]}],
    )

    result = scan(session, "tenantforge")

    assert result.orphans == []


def test_finds_instance_by_name_prefix_without_project_tag(session):
    ec2 = session.client("ec2")
    images = ec2.describe_images()["Images"]
    ami = images[0]["ImageId"] if images else "ami-12345678"
    ec2.run_instances(
        ImageId=ami,
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{"ResourceType": "instance", "Tags": [{"Key": "Name", "Value": "tenantforge-dev-node"}]}],
    )

    result = scan(session, "tenantforge")

    assert any(o.kind == "EC2 instance" and o.name == "tenantforge-dev-node" for o in result.orphans)


def test_finds_unassociated_elastic_ip(session):
    ec2 = session.client("ec2")
    alloc = ec2.allocate_address(Domain="vpc", TagSpecifications=[
        {"ResourceType": "elastic-ip", "Tags": [{"Key": "project", "Value": "tenantforge"}]}
    ])

    result = scan(session, "tenantforge")

    assert any(o.kind == "Unassociated Elastic IP" and o.id == alloc["AllocationId"] for o in result.orphans)


def test_finds_unattached_ebs_volume(session):
    ec2 = session.client("ec2")
    vol = ec2.create_volume(
        AvailabilityZone="eu-north-1a",
        Size=8,
        TagSpecifications=[{"ResourceType": "volume", "Tags": [{"Key": "project", "Value": "tenantforge"}]}],
    )

    result = scan(session, "tenantforge")

    assert any(o.kind == "Unattached EBS volume" and o.id == vol["VolumeId"] for o in result.orphans)


def test_delete_orphan_removes_unattached_volume(session):
    ec2 = session.client("ec2")
    vol = ec2.create_volume(
        AvailabilityZone="eu-north-1a",
        Size=8,
        TagSpecifications=[{"ResourceType": "volume", "Tags": [{"Key": "project", "Value": "tenantforge"}]}],
    )
    result = scan(session, "tenantforge")
    orphan = next(o for o in result.orphans if o.kind == "Unattached EBS volume")

    delete_orphan(session, orphan)

    remaining_ids = [v["VolumeId"] for v in ec2.describe_volumes()["Volumes"]]
    assert vol["VolumeId"] not in remaining_ids


def test_finds_nat_gateway(session):
    ec2 = session.client("ec2")
    vpc_id = ec2.create_vpc(CidrBlock="10.0.0.0/16")["Vpc"]["VpcId"]
    subnet_id = ec2.create_subnet(VpcId=vpc_id, CidrBlock="10.0.0.0/24")["Subnet"]["SubnetId"]
    alloc_id = ec2.allocate_address(Domain="vpc")["AllocationId"]

    nat = ec2.create_nat_gateway(
        SubnetId=subnet_id,
        AllocationId=alloc_id,
        TagSpecifications=[{"ResourceType": "natgateway", "Tags": [{"Key": "project", "Value": "tenantforge"}]}],
    )["NatGateway"]

    result = scan(session, "tenantforge")

    assert any(o.kind == "NAT Gateway" and o.id == nat["NatGatewayId"] for o in result.orphans)


def test_no_orphans_returns_empty_result(session):
    result = scan(session, "tenantforge")

    assert result.orphans == []
