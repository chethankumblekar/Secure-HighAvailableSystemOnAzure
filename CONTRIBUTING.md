# Contributing to TenantForge

Thanks for your interest in TenantForge. This is a platform-engineering
reference project developed against a phased roadmap
([docs/roadmap.md](docs/roadmap.md)), so contributions are welcome but
work best when they fit into that structure rather than going around it.

## Before you start

- Read [docs/architecture.md](docs/architecture.md) and
  [docs/roadmap.md](docs/roadmap.md) first — they explain what's built,
  what's intentionally deferred, and why. A change that looks like a gap
  may already be a documented, deliberate scope decision (check
  `docs/adr/` before assuming it's an oversight).
- For anything beyond a small fix, open an issue describing what you want
  to change and why before writing code — this avoids duplicated effort on
  a project with one primary maintainer.

## Development workflow

1. Fork the repo and create a branch off `main`.
2. Make your change. Each subproject has its own README with local
   run/test instructions (`workloads/sample-service/README.md`,
   `observability/*/README.md`, `security/policies/README.md`,
   `platform/backstage/README.md`, `platform/argocd/README.md`).
3. Run `scripts/test-all.sh` before opening a PR — it runs every
   automated check (Go, Helm, Terraform, OPA/Gatekeeper, Kubernetes
   manifests, Backstage) in the same order CI does. See
   [TESTING.md](TESTING.md) for what each check covers, and for the parts
   that are only practically verified against a live cluster (NetworkPolicy
   enforcement, ArgoCD sync, the full observability pipeline, the
   Backstage scaffolder) — if you touch one of those, re-verify it
   manually using the linked README and say what you ran in the PR
   description.
4. Add a test for new behavior. A new Gatekeeper constraint needs a
   `_test.rego` (see `security/policies/gatekeeper/tests/`); a new HTTP
   handler needs a case in `cmd/server/main_test.go`; a new Terraform
   module needs to pass `validate` at minimum.
5. Open a PR against `main` with a clear description of what changed and
   why, and what you verified (the PR template asks for this explicitly).
   Link the roadmap phase or issue it relates to.

## Architecture Decision Records

Non-trivial decisions (a tradeoff, a pivot, a "why not the obvious
choice") get an ADR in `docs/adr/`, numbered sequentially. Look at an
existing one (e.g. [ADR-0004](docs/adr/0004-stdlib-metrics-not-otel-sdk.md))
for the expected shape: Status, Context, Decision, Consequences. If your
PR makes a decision like this, include the ADR in the same PR.

## Code conventions

- Go (`workloads/sample-service`): standard library only, by design — see
  [ADR-0004](docs/adr/0004-stdlib-metrics-not-otel-sdk.md). `gofmt` and
  `go vet` clean, tests for new behavior.
- Terraform: modules stay cloud-specific under
  `infra/terraform/<azure|aws>/modules`, environments under `envs/<name>`.
- Keep the reference workload (`workloads/sample-service`) minimal — its
  job is to prove the platform, not to grow business logic.

## Reporting bugs and requesting features

Use the issue templates — they ask for the context needed to act on a
report (what phase/subproject, what you expected, what happened, repro
steps for bugs).

## Security issues

Don't open a public issue for a security vulnerability — see
[SECURITY.md](SECURITY.md).
