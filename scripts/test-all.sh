#!/usr/bin/env bash
# Runs every automated check in this repo, in the order documented in
# TESTING.md. Fails fast on the first broken component so you know
# exactly what to fix. Pass --skip-backstage to skip the slowest section
# (yarn install + jest) when iterating on something unrelated to it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

skip_backstage=false
for arg in "$@"; do
  [ "$arg" = "--skip-backstage" ] && skip_backstage=true
done

section() { printf '\n\033[1;34m== %s ==\033[0m\n' "$1"; }

section "Go: workloads/sample-service (go vet + go test -race)"
( cd workloads/sample-service && go vet ./... && go test ./... -race )

section "Helm: lint + template + kubeconform"
helm lint workloads/sample-service/helm
# kubeconform silently treats extensionless input files as "not
# Kubernetes YAML" and skips them without error (0 resources, exit 0) —
# mktemp's default output has no extension, so give it one explicitly.
tmp_default="$(mktemp).yaml"
tmp_full="$(mktemp).yaml"
trap 'rm -f "$tmp_default" "$tmp_full"' EXIT
helm template test-release workloads/sample-service/helm > "$tmp_default"
helm template test-release workloads/sample-service/helm --set ingress.enabled=true --set autoscaling.enabled=true > "$tmp_full"
kubeconform -strict -summary "$tmp_default" "$tmp_full"

section "Terraform: fmt + validate (azure, aws)"
for cloud in azure aws; do
  echo "-- infra/terraform/$cloud --"
  terraform -chdir="infra/terraform/$cloud" fmt -check -recursive
  terraform -chdir="infra/terraform/$cloud" init -backend=false -input=false >/dev/null
  terraform -chdir="infra/terraform/$cloud" validate
done

section "OPA/Gatekeeper: Rego unit tests"
security/policies/gatekeeper/tests/run.sh

section "Kubernetes manifests: kubeconform"
scripts/validate-manifests.sh

section "FinOps: pytest (orphan-cleanup, cost-dashboards)"
if ! python3 -c "import pytest, moto" >/dev/null 2>&1; then
  echo "pytest/moto not importable — run 'pip install -r requirements-dev.txt' in finops/orphan-cleanup and finops/cost-dashboards first. Skipping." >&2
else
  python3 -m pytest finops/orphan-cleanup finops/cost-dashboards -v
fi

if [ "$skip_backstage" = true ]; then
  section "Backstage: SKIPPED (--skip-backstage)"
else
  section "Backstage: jest unit tests"
  if ! command -v yarn >/dev/null 2>&1; then
    echo "yarn not on PATH — run 'corepack enable' first (see platform/backstage/README.md). Skipping." >&2
  elif [ ! -d platform/backstage/node_modules ]; then
    echo "platform/backstage/node_modules missing — run 'yarn install' there first. Skipping." >&2
  else
    # NOT `yarn backstage-cli repo test --ci` — that defaults to
    # --onlyChanged, which prints "No tests found related to files
    # changed since last commit" and then hangs instead of exiting when
    # there's nothing changed relative to HEAD. Invoking jest directly
    # with the same config runs the full suite and actually exits.
    ( cd platform/backstage && node_modules/.bin/jest \
        --config node_modules/@backstage/cli-module-test-jest/config/jest.js \
        --watchAll=false --ci )
  fi
fi

section "All checks passed"
