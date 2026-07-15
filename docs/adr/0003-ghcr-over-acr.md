# ADR-0003: GHCR over ACR for the public demo

## Status
Accepted

## Context
[ADR-0001](0001-architecture-foundations.md) commits this project to a
tiered cost strategy where anything that can run on a free tier should.
Phase 3 needs a container registry to push the reference workload's image
to, and to pull it from during ArgoCD sync onto AKS.

Azure Container Registry (ACR) is the "enterprise-correct" choice — same
cloud as the rest of the landing zone, private by default, integrates
cleanly with AKS via `AcrPull` role assignment instead of a token. It also
has an ongoing cost (even the Basic SKU bills per day) and would need to
exist before Phase 3's CI pipeline could push anything, pulling a paid
Azure resource into what should be a $0 tier.

GitHub Container Registry (GHCR) is free and unlimited for public images on
a public repo, authenticates in Actions with the built-in `GITHUB_TOKEN`
(no extra secret to manage), and this repo is already public.

## Decision
Use GHCR for the CI pipeline's image push, SBOM attachment, and cosign
signing in Phase 3. `ghcr.io/<owner>/tenantforge-sample-service` is the
image name — independent of the repo's own name so it survives the
pending GitHub rename ([[project-tenantforge]] memory has that context).

## Consequences
- AKS needs `imagePullSecrets` (a GHCR PAT or fine-grained token) to pull a
  private GHCR image, or the package needs to be set public — verify
  package visibility after the first push; GHCR's default for
  `GITHUB_TOKEN`-published packages isn't guaranteed public.
- This is a deliberate tradeoff, not the "correct" enterprise answer: in a
  real multi-tenant platform with a paying customer, ACR (or ECR for the
  AWS reference impl) with private endpoints and no public registry
  exposure is the right call. Worth saying exactly that in an interview if
  asked why GHCR is here instead of ACR.
