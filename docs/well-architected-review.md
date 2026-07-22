# Well-Architected Review

Mapped against Microsoft's five pillars: Reliability, Security, Cost
Optimization, Operational Excellence, Performance Efficiency. Filled in as
each phase lands — this is a living document, not written once at the end.

| Pillar | What's implemented | What's written up | Status |
|---|---|---|---|
| Reliability | `dev`/`dr` environments on the same modules, different regions | — | Landing zone only; PodDisruptionBudgets/health probes land with the reference workload (Phase 2) |
| Security | Key Vault (RBAC), AKS workload identity + OIDC issuer, resource-group policy assignment, SAST/scan/SBOM/signing (Phase 3), tenant NetworkPolicy + OPA/Gatekeeper admission policy (Phase 5) | — | WAF is cloud-specific infra, waits on Phase 1's real `terraform apply` |
| Cost Optimization | Free AKS control-plane SKU, single burstable node, apply-demo-destroy workflow, orphan-resource scanning + real cost reporting (`finops/`) — verified against the live AWS account: zero orphans, $0.00 actual spend across Phase 1b's full apply/verify/destroy cycle | — | Grafana cost dashboard integration, scheduled runs, budget alerts, spot node pool, Azure equivalents are still open |
| Operational Excellence | GitOps-ready module layout, ADRs (`docs/adr/`), per-alert runbooks (`docs/runbooks/`), self-service tenant onboarding via Backstage (`platform/backstage`), automated tests across every component wired into CI (`TESTING.md`, `scripts/test-all.sh`) | — | Blameless postmortem template, DR drill log are Phase 9 |
| Performance Efficiency | SLO-based latency alerting (p95 < 500ms) via `observability/prometheus/slo-rules.yaml`; k6 load test (`loadtest/k6/`) found and confirmed the single-replica CPU-limit ceiling for real — see [`docs/load-test-report.md`](load-test-report.md) | — | HPA/KEDA and Front Door caching are Phase 2/6; a load test run with autoscaling enabled to show it actually absorbing load is a natural follow-up |

See [docs/roadmap.md](roadmap.md) for the phase-by-phase plan.
