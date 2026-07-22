# Runbook: `SampleServiceDown`

Fires when `up{job="sample-service"}` is `0` for 5 minutes — Prometheus
(scraping the OTel collector, which itself scrapes `sample-service`'s
`/metrics`) has lost the target entirely. This is more severe than
`SampleServiceHighErrorRate`: that alert means the service is answering
badly; this one means nothing is answering at all. Defined in
[`observability/prometheus/slo-rules.yaml`](../../observability/prometheus/slo-rules.yaml).

## Check first

1. `kubectl -n default get pods -l app.kubernetes.io/name=sample-service` —
   is there a pod at all? `0/1` ready, `CrashLoopBackOff`, or nothing
   scheduled are all different problems.
2. `kubectl -n default get events --sort-by=.lastTimestamp | tail -20` —
   `ImagePullBackOff` (bad `image.tag` in `helm/values.yaml`),
   `CreateContainerConfigError` (see the `runAsNonRoot`/`runAsUser` note in
   `workloads/sample-service/README.md`), or `OOMKilled` all show up here.
3. Is it the workload or the pipeline? `kubectl -n observability get pods
   -l app.kubernetes.io/name=otel-collector` — if the collector itself is
   down or its `/etc/otel/config.yaml` scrape target is unreachable,
   Prometheus loses this target even though `sample-service` may be
   perfectly healthy. `kubectl -n observability logs -l
   app.kubernetes.io/name=otel-collector` will show scrape failures
   directly.

## Likely causes

- Bad deploy: image tag doesn't exist / doesn't pull
  (`ImagePullBackOff` — see [ADR-0003](../adr/0003-ghcr-over-acr.md) on GHCR
  package visibility).
- `CreateContainerConfigError` from a `securityContext` mismatch — this bit
  the project once already during Phase 2's local `kind` verification (see
  `workloads/sample-service/README.md`'s `runAsNonRoot` note); a values
  change that regresses `runAsUser: 65532` would reproduce it.
- The OTel collector pod itself crashed (`kubectl -n observability logs
  -l app.kubernetes.io/name=otel-collector`) — the workload can be fine and
  this alert can still fire.
- Node pressure evicted the pod: `kubectl -n default describe pod
  <pod>` for `Evicted`/`OOMKilled`.

## Remediation

- Bad deploy: `argocd app rollback sample-service <previous-revision-id>`.
- Config error: fix `workloads/sample-service/helm/values.yaml`, commit,
  let ArgoCD self-heal (`syncPolicy.automated.selfHeal: true` is already
  set in `platform/argocd/overlays/local/sample-service-app.yaml`).
- Collector down: `kubectl -n observability rollout restart deployment
  otel-collector` — its config is entirely declarative
  (`observability/otel-collector/configmap.yaml`), safe to restart.
- Confirm recovery: the target reappears as `up{job="sample-service"} == 1`
  in Prometheus within one scrape interval (15s) of the pod becoming ready
  again; the alert itself clears after 5m of that.

## Escalation

There is no on-call rotation for this system. In a production deployment
this section would name the owning team and their paging channel.
