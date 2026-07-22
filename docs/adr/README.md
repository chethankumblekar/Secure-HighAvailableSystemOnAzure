# Architecture Decision Records

Numbered sequentially, never renumbered or deleted — a superseded ADR says
so in its own Status line and links to the one that replaces it. See
[CONTRIBUTING.md](../../CONTRIBUTING.md) for when to write one.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-architecture-foundations.md) | Platform architecture foundations — CI/CD, IaC, cost tiers, DR strategy | Accepted (partially superseded by 0002) |
| [0002](0002-appservice-to-aks-pivot.md) | Compute layer: App Service → AKS | Accepted |
| [0003](0003-ghcr-over-acr.md) | GHCR over ACR for the public demo registry | Accepted |
| [0004](0004-stdlib-metrics-not-otel-sdk.md) | Hand-rolled Prometheus metrics in the workload, not the OTel SDK | Accepted |
