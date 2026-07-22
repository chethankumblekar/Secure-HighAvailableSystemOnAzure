# Orphan-resource cleanup bot

Phase 6 of [the roadmap](../../docs/roadmap.md). A Python/boto3 script
that finds AWS resources tagged (or named-prefixed) `tenantforge` and
left running outside the apply-demo-destroy pattern — the ones that
silently bleed money after a demo if nobody remembers to
`terraform destroy`. Covers what `infra/terraform/aws` actually
provisions and what costs money while idle: EKS clusters, EC2 instances,
NAT Gateways (the single most common source of a silent bleed — they bill
hourly regardless of traffic), unassociated Elastic IPs, and unattached
EBS volumes.

Built AWS-first, not Azure — this repo's AWS reference implementation is
the cloud that's actually had real infrastructure applied and torn down
(Phase 1b); Azure (Phase 1) hasn't been applied yet, so there's nothing
real to scan there. Extending this to Azure once Phase 1 lands is
straightforward (same structure, `azure-mgmt-resource` instead of
`boto3`) but premature before then.

## Use it

```bash
pip install -r requirements.txt

python3 orphan_cleanup.py --project tenantforge --region eu-north-1
# dry run by default — lists what it finds, deletes nothing

python3 orphan_cleanup.py --project tenantforge --region eu-north-1 --delete
# actually deletes everything it found
```

Exit code is `0` if nothing was found, `1` if orphans exist (dry run) —
scriptable for a cron job or CI check that alerts without deleting
anything automatically.

## Verified for real

Run dry-run against the live account after Phase 1b's AWS resources were
torn down: found zero orphans, independently cross-checked against raw
`aws ec2 describe-instances` / `describe-nat-gateways` / `eks
list-clusters` calls returning empty too — confirming the Phase 1b
cleanup was actually clean, not just assumed clean. That only proves the
"nothing found" case works, though; `test_orphan_cleanup.py` uses
[moto](https://github.com/getmoto/moto) to mock AWS and prove the
positive case — that a matching resource *is* found, a non-matching one
isn't, and `--delete` actually removes what it found:

```bash
pip install -r requirements-dev.txt
pytest test_orphan_cleanup.py -v
```

## Not yet wired up

- No scheduled run (cron / GitHub Actions on a schedule) — invoked
  manually today.
- No Slack/email notification on found orphans, just stdout + exit code.
- Azure support, once Phase 1 applies real Azure infrastructure to scan.
