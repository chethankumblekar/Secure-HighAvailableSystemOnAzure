# Runbook: `SampleServiceHighLatency`

Fires when p95 request duration for any route stays above 500ms for 10
minutes:
`histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="sample-service"}[5m])) by (le, route))`.
Defined in
[`observability/prometheus/slo-rules.yaml`](../../observability/prometheus/slo-rules.yaml).

## Check first

1. Grafana → "sample-service SLOs" dashboard, "p95 latency by route" panel —
   which route, and is it one spike or sustained?
2. Cross-reference against the request-rate panel on the same dashboard —
   did traffic increase at the same time (load-related), or is latency up
   with flat/low traffic (something else is slow)?
3. `kubectl -n default top pod -l app.kubernetes.io/name=sample-service` —
   CPU throttling against the Helm chart's `resources.limits.cpu` (`250m`
   by default in `workloads/sample-service/helm/values.yaml`) is the most
   likely cause given this service's in-memory store has no external
   dependency to be slow.

## Likely causes

- CPU throttling under load — the default `resources.limits.cpu: 250m` is
  deliberately small (this is a $0-tier demo, not a sized-for-production
  service).
- Node-level noisy neighbor on a shared `kind` node — check
  `kubectl top nodes`.
- A regression in a recent deploy (unlikely given how small this handler
  path is, but check `argocd app history sample-service` anyway).

## Remediation

- Raise `resources.requests`/`resources.limits` in
  `workloads/sample-service/helm/values.yaml` and let ArgoCD sync the
  change, or enable `autoscaling.enabled: true` (HPA template already
  exists, disabled by default) so replica count absorbs load instead of
  single-pod CPU limits.
- If it's a bad deploy: `argocd app rollback sample-service
  <previous-revision-id>`.
- Confirm recovery in the Grafana dashboard — the alert needs p95 back
  under 500ms for a full 10m window before it clears.

## Escalation

Portfolio/demo system, no on-call. In a real deployment this section would
name the owning team and their paging channel.
