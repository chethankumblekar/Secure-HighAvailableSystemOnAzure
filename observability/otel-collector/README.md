# OpenTelemetry Collector

Phase 4 of [the roadmap](../../docs/roadmap.md). Pull-based metrics gateway
between `sample-service` and Prometheus — see
[ADR-0004](../../docs/adr/0004-stdlib-metrics-not-otel-sdk.md) for why this
is a scrape (not an OTLP push) at the first hop, and
[`docs/architecture.md`](../../docs/architecture.md) for where this sits in
the overall telemetry chain.

## What's here

- `namespace.yaml` — the `observability` namespace everything in this
  directory lives in.
- `configmap.yaml` — the collector config: a `prometheus` receiver scrapes
  `sample-service.default.svc.cluster.local:80/metrics` every 15s, a
  `resource` processor tags everything `deployment.environment=local`, and
  a `prometheus` exporter re-exposes it all on `:8889` for the real
  Prometheus to scrape.
- `deployment.yaml`, `service.yaml` — the collector itself
  (`otel/opentelemetry-collector-contrib`), one replica, sized for a `kind`
  node.

## Try it locally

Requires `sample-service` already deployed (see
[`workloads/sample-service/README.md`](../../workloads/sample-service/README.md))
and a `kind` cluster:

```bash
kubectl apply -f observability/otel-collector/namespace.yaml
kubectl apply -f observability/otel-collector/configmap.yaml
kubectl apply -f observability/otel-collector/deployment.yaml
kubectl apply -f observability/otel-collector/service.yaml
kubectl -n observability rollout status deploy/otel-collector

# confirm it's actually scraping sample-service and re-exposing real data
kubectl -n observability port-forward svc/otel-collector 8889:8889
curl -s localhost:8889/metrics | grep http_requests_total
```

Deployed via ArgoCD instead in the full GitOps flow — see
`platform/argocd/overlays/local/observability-app.yaml`.

## Not yet wired up

- Metrics only. No `otlp` receiver — nothing pushes traces or metrics to
  this collector yet, since `sample-service` deliberately has zero
  OpenTelemetry SDK dependencies ([ADR-0004](../../docs/adr/0004-stdlib-metrics-not-otel-sdk.md)).
  A future workload that wants traces would add an `otlp` receiver here and
  push to it directly.
- No trace backend (Tempo/Jaeger) — out of scope for this phase; the
  collector pipeline exists to prove the metrics path end-to-end first.
