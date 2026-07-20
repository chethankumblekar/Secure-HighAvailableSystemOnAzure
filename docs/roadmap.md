# Roadmap

Durable phase tracker for TenantForge. Update the checkbox and the "Notes"
column as work lands — this file is the source of truth for project status
across sessions, not any ephemeral chat history.

| Phase | Deliverable | Status | Notes |
|---|---|---|---|
| 0 — Plan | ADRs, architecture doc, repo scaffolded | ✅ Done | `docs/adr/0001`, `docs/adr/0002`, `docs/architecture.md`, full target tree scaffolded |
| 1 — Landing zone | Terraform modules: network, AKS, Key Vault, monitoring, policy, remote state | 🚧 In progress | `infra/terraform/azure` wired; not yet `terraform apply`'d against real Azure |
| 1b — AWS reference impl | Terraform modules: VPC, EKS, IAM/IRSA, ALB | ✅ Done | `infra/terraform/aws` wired (vpc → eks → alb → iam) and `terraform apply`'d for real against AWS eu-north-1 (TFC workspace `tenantforge-aws-dev`): VPC + NAT + EKS cluster + node group verified live, `kubectl get nodes` shows 1 Ready node. IRSA role for AWS Load Balancer Controller wired via OIDC (controller itself not yet installed via Helm/ArgoCD — same Helm/ArgoCD definitions from `platform/argocd` still need to target this cluster to prove full portability) |
| 2 — Reference workload | Sample multi-tenant service, containerized, Helm chart | ✅ Done | `workloads/sample-service` — Go notes API, distroless image (~13MB), Helm chart verified end-to-end on local `kind` |
| 3 — CI/CD + GitOps | GitHub Actions (SAST/scan/SBOM/sign) → ArgoCD auto-deploy | ✅ Done | `ci.yml` live and green: build/test → Trivy → Syft → GHCR push → cosign sign + SBOM attest, all verified for real (not just offline) — image confirmed publicly pullable, cosign signature independently verified against Rekor with `cosign verify`. `codeql.yml` passing. `platform/argocd` app-of-apps verified end-to-end: fresh local `kind` cluster + ArgoCD auto-discovered and synced `sample-service` from git, pulling the real published GHCR image, reaching Healthy and serving traffic |
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
