# Requirements

## Goal

Prove, with a real running system rather than a slide deck, that the
infrastructure and delivery platform underneath a product can be designed
and operated end-to-end — not just deployed once and left alone.

## Functional requirements

- Provision a repeatable, multi-environment (`dev`, `dr`) Azure landing zone
  via Terraform: resource group, network, AKS, Key Vault, monitoring, policy.
- Run a containerized reference workload on AKS, deployed via Helm and
  synced by ArgoCD from a GitOps repo.
- Enforce a supply-chain-secure CI pipeline: SAST, image scanning, SBOM
  generation, image signing, before anything reaches the cluster.
- Provide self-service onboarding for a new tenant/service via a Backstage
  golden-path template.
- Surface cost and reliability data (dashboards, alerts) as first-class
  outputs, not afterthoughts.

## Non-functional requirements, mapped to the Well-Architected Framework

See [docs/well-architected-review.md](docs/well-architected-review.md) for
the live status of each; summarized targets:

- **Reliability** — the platform survives a regional failover drill
  (`dev` → `dr`) with a documented runbook, not just in theory.
- **Security** — zero static cloud secrets in CI or in-cluster (OIDC +
  workload identity everywhere); every image scanned and signed before
  deploy.
- **Cost Optimization** — total spend for the build stays in the $0–10
  range; nothing runs 24/7 that doesn't need to.
- **Operational Excellence** — every change to infrastructure is
  code-reviewable and auditable via GitOps; every non-trivial decision has
  an ADR in `docs/adr/`.
- **Performance Efficiency** — the reference workload autoscales under load
  and has a load-test report (k6) with before/after numbers.

## Explicit non-goals

- This is not a production system serving real users — resources are
  deployed on-demand and destroyed after validation (see the cost tiers in
  [docs/roadmap.md](docs/roadmap.md)).
- The reference workload's own business logic is intentionally minimal —
  the platform underneath it is what's being evaluated.
