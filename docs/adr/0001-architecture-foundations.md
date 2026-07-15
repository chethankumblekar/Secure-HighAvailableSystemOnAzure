# ADR-0001: Platform Architecture Foundations

## Status
Accepted (superseded in part by [ADR-0002](0002-appservice-to-aks-pivot.md) — compute layer)

## Context
The goal is to build a secure, well-architected multi-tenant platform on
Azure — TenantForge — that demonstrates CI/CD, Infrastructure as Code,
security, rollback, and disaster recovery while keeping ongoing cloud costs
near zero.

## Decision
- Use GitHub Actions for CI/CD
- Use Terraform (with a Terraform Cloud remote backend) for Infrastructure as Code
- Design enterprise-grade architecture, validated against free/minimal Azure SKUs
- Use a cold-standby DR strategy (`dev` + `dr` environments, same modules, different region)
- Split the build into cost tiers: local (`kind`) for daily iteration, GitHub's
  free tier for CI, short paid Azure bursts (apply → demo → destroy) for
  anything that needs real cloud resources

## Consequences
- Some enterprise services are designed but not run continuously
- Infrastructure is deployed on-demand and destroyed after validation
- Architecture is fully reproducible via code