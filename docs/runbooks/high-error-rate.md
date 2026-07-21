# Runbook: `SampleServiceHighErrorRate`

Fires when `sample_service:error_ratio:rate5m` (5xx responses / total
responses, per route) stays above 5% for 5 minutes. Defined in
[`observability/prometheus/slo-rules.yaml`](../../observability/prometheus/slo-rules.yaml).

## Check first

1. Which route? The alert's `route` label narrows it to one endpoint —
   `GET /tenants/{tenantID}/notes`, `POST /tenants/{tenantID}/notes`, or
   `GET /tenants/{tenantID}/notes/{id}`.
2. Grafana → "sample-service SLOs" dashboard → confirm the error-ratio panel
   agrees with the alert and check whether it's climbing, flat, or already
   recovering.
3. `kubectl -n default get pods -l app.kubernetes.io/name=sample-service` —
   are pods crash-looping or freshly restarted? `kubectl -n default logs
   -l app.kubernetes.io/name=sample-service --since=15m | grep -i error`.

## Likely causes

- A bad deploy: check `kubectl -n argocd get application sample-service` and
  whether the synced revision changed recently (`argocd app history
  sample-service`).
- Client-side misuse: 400s are 4xx, not counted here — if the ratio is real
  5xx, it's a server-side fault (panic recovered by the stdlib default
  handler returns 500, decode errors return 400 and don't count).
- Resource pressure: `kubectl -n default top pod -l
  app.kubernetes.io/name=sample-service` against the Helm chart's
  `resources.limits` in `workloads/sample-service/helm/values.yaml`.

## Remediation

- If a recent deploy caused it: `argocd app rollback sample-service
  <previous-revision-id>`, or revert the git commit that changed
  `workloads/sample-service/helm` / bumped `image.tag` and let ArgoCD
  self-heal back.
- If it's resource exhaustion: bump `resources.limits` in
  `helm/values.yaml`, or scale `replicaCount` — this workload has no
  autoscaling enabled by default (`autoscaling.enabled: false`).
- Confirm recovery in the Grafana dashboard before closing out — the alert
  clears itself once `sample_service:error_ratio:rate5m` drops under 5% for
  a full 5m window.

## Escalation

This is a portfolio/demo system with no on-call — there's no pager to
escalate to. In a real deployment this section would name the owning team
and their paging channel.
