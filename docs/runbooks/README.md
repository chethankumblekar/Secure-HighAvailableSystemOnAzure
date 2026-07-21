# Runbooks

## Alert runbooks (Phase 4)

Every alert in
[`observability/prometheus/slo-rules.yaml`](../../observability/prometheus/slo-rules.yaml)
carries a `runbook_url` annotation pointing here:

| Alert | Runbook |
|---|---|
| `SampleServiceHighErrorRate` | [high-error-rate.md](high-error-rate.md) |
| `SampleServiceHighLatency` | [high-latency.md](high-latency.md) |
| `SampleServiceDown` | [service-down.md](service-down.md) |

## Not yet written — Phase 9 of [the roadmap](../roadmap.md)

A DR drill log (what broke during a real failover attempt, what we'd
change), an incident postmortem for a simulated production issue, and a
Key-Vault-secret-rotation runbook.
