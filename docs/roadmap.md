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
| 4 — Observability | OTel + Prometheus + Grafana, SLOs, alerting, runbooks | ✅ Done | `observability/` — verified end-to-end on local `kind`: `sample-service` emits real Prometheus-format metrics (`internal/metrics`, stdlib only, [ADR-0004](adr/0004-stdlib-metrics-not-otel-sdk.md)); OTel collector scrapes it and re-exposes with `job`/`instance` round-tripped intact; `kube-prometheus-stack`'s Prometheus picks that up via `honorLabels: true` ServiceMonitor (confirmed `job="sample-service"` survives, not overwritten by the collector's own identity); SLO `PrometheusRule` recording/alerting rules confirmed `health: ok` and correctly inactive under healthy traffic; Grafana dashboard confirmed auto-provisioned via the chart's sidecar. Three alerts (`SampleServiceHighErrorRate/HighLatency/Down`) each link a runbook in `docs/runbooks/`. Full GitOps path also verified: fresh `kind` cluster, ArgoCD app-of-apps synced `kube-prometheus-stack-app.yaml` and `observability-app.yaml` straight from `origin`, all four Applications reached Synced/Healthy. Found and fixed one real issue along the way — kube-prometheus-stack's CRDs are too large for client-side apply's annotation limit, permanently `SyncFailed` until `ServerSideApply=true` is set on the Application. |
| 5 — Security hardening | Workload Identity (done for AKS↔KV), NetworkPolicies, OPA/Gatekeeper, WAF | 🚧 Partial | AKS workload identity + Key Vault RBAC done in Phase 1. NetworkPolicy (`workloads/sample-service/helm/templates/networkpolicy.yaml`) and Gatekeeper constraints (`security/policies/gatekeeper/`) verified on a Calico-enabled `kind` cluster: cross-namespace traffic to `sample-service` confirmed blocked while the OTel collector's scrape and same-namespace traffic stay allowed; a deliberately non-compliant pod (wrong registry, root, no resource limits) confirmed rejected by all three Gatekeeper constraints independently. Found and fixed a real Rego bug along the way (`required - provided` silently no-ops when subtracting a set from an array instead of a set). WAF is cloud-specific infra, not done — waits on Phase 1's real `terraform apply`. |
| 6 — FinOps | Cost dashboards, orphan-cleanup bot | ⬜ Not started | `finops/` — port from the `cloud-control-plane` repo's existing cost-calc scripts and OPA policies |
| 7 — Platform/IDP | Backstage golden-path templates | ✅ Done | `platform/backstage` — real Backstage instance (`@backstage/create-app`, SQLite), one software template (`tenant-service`) scaffolding a Go HTTP service + Dockerfile + Helm chart (same distroless/non-root/NetworkPolicy pattern as `workloads/sample-service`). Verified for real by driving the actual UI (fill form → run task) and confirming all 15 templated files wrote correctly with substituted values in the task log. Publishing to a real repo and Terraform/ArgoCD invocation are manual follow-ups — see `platform/backstage/README.md`'s "Not yet wired up". |
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
