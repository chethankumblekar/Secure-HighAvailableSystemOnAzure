# Roadmap

Durable phase tracker for TenantForge. Update the checkbox and the "Notes"
column as work lands — this file is the source of truth for project status
across sessions, not any ephemeral chat history.

| Phase | Deliverable | Status | Notes |
|---|---|---|---|
| 0 — Plan | ADRs, architecture doc, repo scaffolded | ✅ Done | `docs/adr/0001`, `docs/adr/0002`, `docs/architecture.md`, full target tree scaffolded |
| 1 — Landing zone | Terraform modules: network, AKS, Key Vault, monitoring, policy, remote state | 🚧 In progress | `infra/terraform/azure` wired; not yet `terraform apply`'d against real Azure |
| 1b — AWS reference impl | Terraform modules: VPC, EKS, IAM/IRSA, ALB | ⬜ Not started | Proves portability; same Helm/ArgoCD definitions target both clouds |
| 2 — Reference workload | Sample multi-tenant service, containerized, Helm chart | ⬜ Not started | `workloads/sample-service` |
| 3 — CI/CD + GitOps | GitHub Actions (SAST/scan/SBOM/sign) → ArgoCD auto-deploy | ⬜ Not started | `ci.yml` still a stub; `platform/argocd` empty |
| 4 — Observability | OTel + Prometheus + Grafana, SLOs, alerting, runbooks | ⬜ Not started | `observability/` |
| 5 — Security hardening | Workload Identity (done for AKS↔KV), NetworkPolicies, WAF | 🚧 Partial | AKS workload identity + Key Vault RBAC done in Phase 1; rest is `security/` |
| 6 — FinOps | Cost dashboards, orphan-cleanup bot | ⬜ Not started | `finops/` — port from the `cloud-control-plane` repo's existing cost-calc scripts and OPA policies |
| 7 — Platform/IDP | Backstage golden-path templates | ⬜ Not started | `platform/backstage` |
| 8 — AI ops assistant | Alert-triage assistant (stretch) | ⬜ Not started | `ai-ops-assistant` |
| 9 — Load test, DR drill, write-up | k6 report, DR drill log, blog post, demo video | ⬜ Not started | `docs/runbooks` |

## Cost tiers (from ADR-0001)

- **Tier 1 — Local, $0**: `kind` cluster for daily iteration on the workload,
  Helm, ArgoCD, Prometheus/Grafana/OTel, Backstage.
- **Tier 2 — GitHub free tier, $0**: GitHub Actions + GHCR on this public repo.
- **Tier 3 — Real Azure/AWS, short paid bursts only**: `terraform apply` →
  screenshot/demo → `terraform destroy`. Set an Azure budget + spend alert
  before the first real apply (not yet done — do this before Phase 1's
  first `terraform apply`).
