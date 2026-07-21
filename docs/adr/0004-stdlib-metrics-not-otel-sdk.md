# ADR-0004: Hand-rolled Prometheus metrics in the workload, not the OTel SDK

## Status
Accepted

## Context
Phase 4 needs `sample-service` to emit real request/latency metrics so the
observability stack (`docs/architecture.md`'s `OTel --> Prom --> Graf -->
SLO` chain) has something genuine to scrape, not the `sample_service_up 1`
placeholder Phase 2 shipped.

The obvious "correct" choice is the OpenTelemetry Go SDK
(`go.opentelemetry.io/otel/sdk/metric` + an OTLP exporter), pushing metrics
to the collector instead of being scraped. But `ci.yml` currently has:

```
cache: false # no go.sum — zero external dependencies, nothing to cache
```

That's not an oversight — Phase 2 deliberately kept this "boring" reference
service on the standard library only, to keep the thing being proven
(container → Helm → AKS → ArgoCD → observability) decoupled from any one
instrumentation vendor's SDK weight and transitive-dependency surface.
Pulling in the OTel Go SDK (and its gRPC/HTTP exporter deps) for a demo
service whose own business logic is intentionally minimal would invert that
trade-off for one feature.

## Decision
`sample-service` hand-rolls a small Prometheus text-exposition-format
registry in `internal/metrics` (stdlib only: `sync`, `time`, `strconv`,
`io`) — a request counter and a duration histogram, both labeled by method
and route pattern (not raw path, to avoid tenant-ID cardinality blowup).
`GET /metrics` serves it directly.

The OTel collector (`observability/otel-collector`) pulls this endpoint via
its `prometheus` receiver, rather than the workload pushing OTLP to the
collector. The collector still sits in the pipeline exactly as
`docs/architecture.md` draws it (workload → OTel → Prometheus → Grafana →
SLO alerting) — it's a pull instead of a push at the first hop, which is a
detail, not a different shape. Prometheus (via kube-prometheus-stack)
scrapes the collector's re-exported `:8889/metrics`, never the workload
directly, so the collector is still the one place all telemetry egress is
vendor-neutral and swappable.

## Consequences
- `sample-service` stays at zero external Go dependencies; `ci.yml`'s
  `cache: false` comment stays true.
- The hand-rolled histogram only supports fixed buckets and two metric
  families — good enough for this reference workload's SLOs (error rate,
  p95 latency), not a general-purpose client library. If a future workload
  in this repo needs traces or more metric types, reach for the real OTel
  SDK then rather than extending this by hand.
- This is a demo-scale call, not a template for a real multi-service
  platform: a fleet of services should standardize on one instrumentation
  library (OTel SDK) rather than each hand-rolling exposition format. Worth
  saying exactly that if asked in an interview, same as [ADR-0003](0003-ghcr-over-acr.md)'s GHCR-over-ACR tradeoff.
