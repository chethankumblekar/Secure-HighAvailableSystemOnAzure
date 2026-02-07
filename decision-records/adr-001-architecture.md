# ADR-001: DevOps Platform Architecture

## Status
Accepted

## Context
The goal is to build a secure, highly available DevOps platform on Azure
that demonstrates CI/CD, Infrastructure as Code, security, rollback,
and disaster recovery while avoiding ongoing cloud costs.

## Decision
- Use GitHub Actions for CI/CD
- Use Terraform for Infrastructure as Code
- Design enterprise-grade architecture
- Validate using free/minimal Azure SKUs
- Implement rollback via deployment slots
- Use cold-standby DR strategy

## Consequences
- Some enterprise services are designed but not run continuously
- Infrastructure is deployed on-demand and destroyed after validation
- Architecture is fully reproducible via code