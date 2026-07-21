# Grafana

Phase 4 of [the roadmap](../../docs/roadmap.md). Deployed as part of the
`kube-prometheus-stack` Helm release (see
[`observability/prometheus/README.md`](../prometheus/README.md)) — nothing
separate to install here.

## What's here

- `dashboard-configmap.yaml` — the "sample-service SLOs" dashboard (request
  rate, error ratio, p95 latency, up/down status), as a `ConfigMap` labeled
  `grafana_dashboard: "1"`. `kube-prometheus-stack`'s Grafana sidecar
  (`values.yaml`: `grafana.sidecar.dashboards`, `searchNamespace: ALL`)
  auto-imports any ConfigMap with that label from any namespace — no manual
  "upload JSON" step, and it's git-managed like everything else.

## Try it locally

Requires `kube-prometheus-stack` already installed (see
[`observability/prometheus/README.md`](../prometheus/README.md)):

```bash
kubectl apply -f observability/grafana/dashboard-configmap.yaml

kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000 — admin / admin (values.yaml sets this for the local demo only)
# Dashboards -> "sample-service SLOs" should already be there via the sidecar
```

Generate some traffic first so the panels aren't empty:

```bash
kubectl -n default port-forward svc/sample-service 8080:80
for i in $(seq 1 50); do curl -s -X POST localhost:8080/tenants/demo/notes -d '{"text":"load"}' >/dev/null; done
```

## Not yet wired up

- Cluster-health and FinOps cost dashboards — this phase only covers the
  reference workload's own SLOs. Cost data lands in Phase 6
  (`finops/cost-dashboards`).
