# Testing

What's automated, what isn't, and how to run all of it. If you're about
to open a PR, run [`scripts/test-all.sh`](scripts/test-all.sh) first —
it's the same thing CI runs, just faster to iterate on locally.

```bash
scripts/test-all.sh              # everything, including Backstage's jest suite
scripts/test-all.sh --skip-backstage   # skip the slowest section
```

## What's tested, and where

| Component | What's tested | Run locally | CI |
|---|---|---|---|
| `workloads/sample-service` | HTTP handlers (routing, status codes, tenant isolation, `/metrics` reflects real traffic), the notes store, the metrics registry | `cd workloads/sample-service && go vet ./... && go test ./...` | `ci.yml` → `build-test` |
| `workloads/sample-service/helm` | Chart lints; renders with default values and with `ingress`/`autoscaling` enabled; rendered output is schema-valid Kubernetes | `helm lint` + `helm template` + `kubeconform` (see `scripts/test-all.sh`) | `validate.yml` → `helm` |
| `infra/terraform/{azure,aws}` | `terraform fmt` compliance, `terraform validate` (types, references, provider schemas) across every module | `terraform fmt -check -recursive` + `terraform validate` per cloud | `validate.yml` → `terraform` (matrix: azure, aws) |
| `security/policies/gatekeeper` | Every `ConstraintTemplate`'s Rego, extracted from the CRD YAML and unit-tested with `opa test` — violation and non-violation cases per constraint | `security/policies/gatekeeper/tests/run.sh` | `validate.yml` → `opa` |
| `observability/`, `platform/argocd/`, `security/policies/gatekeeper` (raw manifests) | Schema validation against upstream + community CRD schemas (ArgoCD `Application`, Prometheus Operator's `ServiceMonitor`/`PrometheusRule`) | `scripts/validate-manifests.sh` | `validate.yml` → `k8s-manifests` |
| `platform/backstage` | `create-app`'s generated unit tests (`App.test.tsx`) — confirms the app still renders after catalog/template changes | `cd platform/backstage && node_modules/.bin/jest --config node_modules/@backstage/cli-module-test-jest/config/jest.js --watchAll=false --ci` (not `backstage-cli repo test` — see below) | `validate.yml` → `backstage` |
| `workloads/sample-service` image | SAST (CodeQL), image scan (Trivy), SBOM (Syft), signing (cosign) | — (runs against the built image, not source) | `ci.yml` → `scan`, `publish`; `codeql.yml` |

## A gotcha worth knowing: `backstage-cli repo test` can hang

Don't run the Backstage suite as `yarn backstage-cli repo test --ci`. That
wrapper defaults to `--onlyChanged` — jest's "only test files related to
what changed since the last commit" mode. With nothing changed relative
to `HEAD` (or against `actions/checkout`'s shallow history in CI), it
prints `No tests found related to files changed since last commit.` and
then hangs instead of exiting, which reads as a slow test run rather than
a stuck one — it cost real time to notice while wiring this up.
`scripts/test-all.sh` and `validate.yml` both invoke jest directly with
the same config instead, which runs the full suite and exits properly.

## Why the Gatekeeper tests matter more than they look

`security/policies/gatekeeper/tests/` isn't boilerplate — it caught a real
bug. The `required-resources` constraint's Rego computed
`required - provided` where `required` came from `input.parameters.requests`
(an array, per the constraint's own schema) and `provided` was a set. In
Rego, subtracting a set from an array is undefined rather than an error,
so the rule silently never matched: Gatekeeper reported the constraint
"enforced" while it admitted every pod regardless of resource limits. Manual
testing on a live cluster caught it (see `docs/roadmap.md`'s Phase 5
entry); `required_resources_test.rego`'s
`test_violates_when_resources_entirely_missing` now fails immediately
under that exact bug — reintroduce it and `opa test` catches it in
milliseconds instead of a `kind` cluster and a crafted pod. That's the
model for the rest of this policy tests: assert both "bad input is
rejected" and "good input is admitted," never only one side.

## What's NOT automated

Some things are only practical to verify against a live cluster, and are
checked manually rather than in CI — each is documented with the exact
steps used the last time it was verified:

- **NetworkPolicy enforcement** — `kind`'s default CNI doesn't enforce
  `NetworkPolicy` at all, so this needs a Calico-enabled cluster. See
  [`security/policies/README.md`](security/policies/README.md)'s "Try it
  locally" for the exact commands (deploy, then prove both the allow and
  the deny cases with a real curl from inside and outside the namespace).
- **ArgoCD GitOps sync** — that the app-of-apps pattern actually
  discovers, syncs, and self-heals every `Application` from git. See
  [`platform/argocd/README.md`](platform/argocd/README.md).
- **The full observability pipeline** — that metrics actually flow
  `sample-service → OTel collector → Prometheus → Grafana`, with correct
  labels (this is where `honorLabels: true` mattering was discovered) and
  that SLO alerts evaluate without error. See
  [`observability/prometheus/README.md`](observability/prometheus/README.md).
- **The Backstage scaffolder end-to-end** — that the `tenant-service`
  golden path actually generates correct, complete files through the real
  UI. See [`platform/backstage/README.md`](platform/backstage/README.md).
- **Real cloud infrastructure** — `infra/terraform/aws` is `terraform
  apply`'d and verified against a live AWS account (see
  `docs/roadmap.md`'s Phase 1b entry); `infra/terraform/azure` validates
  but isn't applied yet. Terraform validation catches type/reference
  errors, not "does this actually provision the right thing" — that only
  a real `apply` proves.

If you change something in one of these areas, re-verify it manually
using the linked README before merging, and update the roadmap/README
with what you actually confirmed — this project's convention is "verified
end-to-end" means someone ran it for real, not that the YAML looks right.
