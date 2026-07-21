# Prometheus

Phase 4 of [the roadmap](../../docs/roadmap.md). `kube-prometheus-stack`
(Prometheus Operator + Prometheus + Alertmanager + Grafana) scraping the
[OTel collector](../otel-collector/README.md), with SLO recording/alerting
rules for `sample-service`.

## What's here

- `values.yaml` — Helm values for the `kube-prometheus-stack` chart, sized
  for a local `kind` node and with the etcd/scheduler/controller-manager
  ServiceMonitors disabled (kind's control plane doesn't expose those the
  way a kubeadm/managed cluster does — see the comments in the file).
- `servicemonitor.yaml` — tells Prometheus to scrape the OTel collector's
  `:8889/metrics`, with `honorLabels: true` so the workload's own
  `job`/`instance` labels (round-tripped through the collector) survive
  instead of being overwritten with the collector's own identity.
- `slo-rules.yaml` — a `PrometheusRule`: recording rules for request rate
  and error ratio, and three alerts (`SampleServiceHighErrorRate`,
  `SampleServiceHighLatency`, `SampleServiceDown`), each linking a runbook
  in [`docs/runbooks/`](../../docs/runbooks/).

## Try it locally

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --version 87.18.0 \
  --namespace observability --create-namespace \
  -f observability/prometheus/values.yaml \
  --wait

kubectl apply -f observability/prometheus/servicemonitor.yaml
kubectl apply -f observability/prometheus/slo-rules.yaml

# confirm the target is up
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# open http://localhost:9090/targets — look for job="sample-service" (via the otel-collector ServiceMonitor)
# open http://localhost:9090/alerts — the three SLO alerts should be listed (inactive until they fire)
```

Deployed via ArgoCD instead in the full GitOps flow — see
`platform/argocd/overlays/local/kube-prometheus-stack-app.yaml` (the Helm
chart itself) and `platform/argocd/overlays/local/observability-app.yaml`
(this directory's `ServiceMonitor`/`PrometheusRule`).

## Not yet wired up

- No Alertmanager receiver beyond the chart default (alerts fire and show
  in the UI; nothing pages anywhere — there's no on-call for a portfolio
  project). A real deployment would wire a Slack/PagerDuty receiver here.
- `retention: 6h` — this is a demo cluster torn down after each session,
  not a system that needs long-term metrics retention.
