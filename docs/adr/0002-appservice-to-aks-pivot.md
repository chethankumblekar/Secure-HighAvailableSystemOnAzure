# ADR-0002: Compute layer — App Service to AKS

## Status
Accepted

## Context
[ADR-0001](0001-architecture-foundations.md) originally targeted Azure App
Service (Linux Web App + deployment slots) as the compute layer, chosen for
its free/cheap F1/B1 tier and built-in slot-swap rollback.

The project's purpose changed: this repo is no longer a generic "secure
Azure app" demo, it's TenantForge — a platform-engineering flagship meant to
prove Kubernetes, Helm, and GitOps depth for a Senior DevOps/Platform
Engineer interview track. App Service demonstrates none of that; it hides
the exact layer (container orchestration, workload identity federation into
a cluster, Helm-packaged services, ArgoCD sync) the project exists to prove.

## Decision
- Replace the `appservice` Terraform module with an `aks` module:
  AKS with a **Free** control-plane SKU tier (no ongoing control-plane cost),
  a single small burstable system node pool (`Standard_B2s`, cost-conscious
  default), Azure CNI Overlay, and `oidc_issuer_enabled` +
  `workload_identity_enabled` turned on from day one.
- `keyvault` now grants `Key Vault Secrets User` to the AKS kubelet identity
  instead of an App Service managed identity — same zero-trust pattern
  (no static secrets), different federation target.
- The App Service module is removed from the working tree. It's fully
  recoverable from git history (this repo's pre-rename commits) if ever
  needed for comparison.
- Rollback is no longer a landing-zone concern (there's no more slot swap).
  It becomes workload-level — Helm release rollback or Argo Rollouts — and
  lands with GitOps in Phase 3.

## Consequences
- AKS nodes are not free the way App Service's F1 tier was; the project
  leans harder on the apply-demo-destroy cost strategy from ADR-0001 for
  anything beyond `terraform validate`.
- The reference workload (Phase 2) must be containerized and Helm-packaged
  from the start rather than deployed as a zip/container to App Service.
- `docs/legacy/architecture-appservice.drawio` is kept for historical
  reference but no longer reflects the current architecture.
