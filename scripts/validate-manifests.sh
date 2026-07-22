#!/usr/bin/env bash
# Schema-validates every plain Kubernetes manifest in the repo (not the
# Helm chart — that's rendered and validated separately, see
# scripts/test-all.sh) using kubeconform. The datreeio CRDs-catalog schema
# location covers third-party CRDs actually used here (ArgoCD Application,
# Prometheus Operator's ServiceMonitor/PrometheusRule); Gatekeeper's
# dynamically-named constraint kinds (K8sRequiredResources etc.) have no
# schema anywhere by construction, so -ignore-missing-schemas skips those
# rather than failing on them.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

kubeconform \
  -strict -summary \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -ignore-missing-schemas \
  observability/otel-collector/*.yaml \
  observability/grafana/*.yaml \
  observability/prometheus/servicemonitor.yaml \
  observability/prometheus/slo-rules.yaml \
  security/policies/gatekeeper/constrainttemplates/*.yaml \
  security/policies/gatekeeper/constraints/*.yaml \
  platform/argocd/app-of-apps/*.yaml \
  platform/argocd/overlays/local/*.yaml \
  platform/argocd/overlays/azure/*.yaml
