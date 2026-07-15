# Security policies

Placeholder — Phase 5 of [the roadmap](../../docs/roadmap.md).

Will hold OPA/Gatekeeper policies enforced in-cluster (beyond the single
Azure Policy assignment already in `infra/terraform/azure/modules/policy`)
— NetworkPolicy requirements, image-provenance checks, least-privilege RBAC
rules. `cloud-control-plane` (sibling repo) already has real OPA rego to
draw from.
