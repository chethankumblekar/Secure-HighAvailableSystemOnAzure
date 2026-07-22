# Cost dashboards

Phase 6 of [the roadmap](../../docs/roadmap.md). A real AWS Cost Explorer
report (`cost_report.py`) — actual spend, grouped by service, over a
given date range. Built AWS-first for the same reason as
[`finops/orphan-cleanup`](../orphan-cleanup/README.md): AWS is the cloud
with real applied-and-torn-down infrastructure to report on; Azure isn't
applied yet.

Groups by `SERVICE`, not by the `project` cost-allocation tag — tag-based
grouping in Cost Explorer requires the tag to be manually activated in
the Billing console first, with up to a 24h propagation delay, which
isn't something this script can do on its own. `SERVICE` grouping works
immediately on any account with no setup.

## Use it

```bash
pip install -r requirements.txt
python3 cost_report.py --days 30
```

## Verified for real

Run against the live account for the 60 days spanning Phase 1b's AWS
apply-verify-destroy cycle: **$0.00** across every period. That's not a
placeholder number — it's the actual Cost Explorer response, and it's the
apply-demo-destroy cost tier from
[ADR-0001](../../docs/adr/0001-architecture-foundations.md) working
exactly as designed: infrastructure existed just long enough to verify,
then was gone before it accrued billable cost.

`fetch_cost_and_usage` (the AWS call) isn't unit-tested — moto doesn't
simulate real billing data, so mocking Cost Explorer would only prove the
mock returns what it was told to return. `format_report` (turning a real
API response into the report above) is what actually has parsing/logic
worth testing, and is:

```bash
pip install -r requirements-dev.txt
pytest test_cost_report.py -v
```

## Not yet wired up

- **Grafana** — this is a CLI report today, not a dashboard panel. The
  natural next step is a small exporter (cron job writing to a
  Prometheus Pushgateway, or a Grafana AWS Cost Explorer data source
  plugin) feeding the same `kube-prometheus-stack` Grafana instance
  `observability/grafana` already provisions, so cost sits next to
  latency/error-rate on one dashboard instead of a separate tool.
- **Tag-based grouping** — once the `project` tag is activated as a cost
  allocation tag, switching `GroupBy` from `SERVICE` to `TAG` narrows
  this to TenantForge's own spend specifically, useful once this account
  runs anything else.
- Azure Cost Management API, once Phase 1 applies real Azure infrastructure.
