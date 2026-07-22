# Architecture

TenantForge is two layers shipped together:

1. **The Platform** — a self-service, golden-path system for standing up
   secure, observable, cost-governed multi-tenant services on Azure. This is
   the primary deliverable: the operational surface a platform team owns,
   not any one service running on top of it.
2. **The Reference Workload** — one deliberately simple multi-tenant API
   service that exists only to prove the platform works end-to-end. Kept
   simple on purpose — the platform is what's under evaluation, not the
   workload's business logic.

## Diagram

```mermaid
flowchart TB
    subgraph Dev["TIER 1 -- Local Dev (free, unlimited)"]
        KindK3d["kind cluster"]
        LocalWork["Reference workload + Helm charts"]
        LocalArgo["ArgoCD local"]
        LocalObs["Prometheus / Grafana / OTel local"]
        KindK3d --> LocalWork --> LocalArgo --> LocalObs
    end

    subgraph GH["TIER 2 -- GitHub, free on public repos"]
        GHA["GitHub Actions CI"]
        SAST["CodeQL SAST"]
        Scan["Trivy image scan"]
        SBOM["Syft SBOM + cosign sign"]
        GHCR["GHCR image registry"]
        GitOpsRepo["GitOps manifests repo"]
        GHA --> SAST --> Scan --> SBOM --> GHCR --> GitOpsRepo
    end

    subgraph Azure["TIER 3a -- Azure: PRIMARY target, short paid bursts"]
        direction TB
        TFAzure["Terraform: infra/terraform/azure"]
        VNet["VNet / Subnets / NSGs"]
        AKS["AKS cluster -- free control plane"]
        KV["Key Vault"]
        SQL["Azure SQL serverless"]
        FD["Front Door + WAF"]
        Entra["Entra ID / Workload Identity"]
        Backstage["Backstage golden paths"]
        TFAzure --> VNet --> AKS
        AKS --> KV
        AKS --> SQL
        FD --> AKS
        Entra --> AKS
        Backstage --> TFAzure
    end

    subgraph AWS["TIER 3b -- AWS: reference impl, short credit burst"]
        direction TB
        TFAws["Terraform: infra/terraform/aws"]
        VPC["VPC / Subnets / Security Groups"]
        EKS["EKS cluster"]
        IAM["IAM / IRSA workload identity"]
        ALB["ALB Ingress"]
        TFAws --> VPC --> EKS
        IAM --> EKS
        ALB --> EKS
    end

    GitOpsRepo -->|ArgoCD sync| AKS
    GitOpsRepo -->|ArgoCD sync| EKS

    subgraph Obs["Cross-cloud Observability"]
        Prom["Prometheus"]
        Graf["Grafana"]
        OTel["OpenTelemetry collector"]
        SLO["SLO alerting + runbooks"]
        OTel --> Prom --> Graf --> SLO
    end
    AKS --> OTel
    EKS --> OTel

    subgraph FinOps["FinOps / Cost Governance"]
        OrphanBot["Orphan-resource cleanup bot"]
        CostDash["Cost dashboards"]
        BudgetAlert["Budget alerts: Azure + AWS"]
        BudgetAlert --> OrphanBot --> CostDash
    end
    AKS -.watched by.-> OrphanBot
    EKS -.watched by.-> OrphanBot

    subgraph AI["AI Ops (stretch)"]
        AIOps["AI ops assistant -- alert triage"]
    end
    SLO --> AIOps
```

## Current state (see [docs/roadmap.md](roadmap.md) for phase status)

`infra/terraform/azure` wires `resource_group -> network -> aks -> keyvault
-> monitoring -> policy` — AKS replaced App Service as the compute target
(see [ADR-0002](adr/0002-appservice-to-aks-pivot.md)) — but is not yet
applied against real Azure. `infra/terraform/aws` is applied and verified:
a live VPC/EKS cluster on AWS with IRSA wired for workload identity. The
reference workload, CI/CD supply-chain pipeline, ArgoCD GitOps, and the
observability stack (OTel collector → Prometheus → Grafana → SLO alerting
→ runbooks) are built and verified end-to-end on both a local `kind`
cluster and the live AWS/GHCR pipeline. `security/`, `finops/`, and
`ai-ops-assistant/` are scaffolded with READMEs pointing at the phase that
fills them in.

## Tech stack by layer

| Layer | Tools | Purpose |
|---|---|---|
| IaC | Terraform (modules + Terraform Cloud remote state), Azure Policy-as-code | Repeatable, reviewable infrastructure provisioning |
| Compute | AKS, EKS, node autoscaling (later), Azure Container Apps for lighter services (stretch) | Portable, production-shaped container orchestration |
| Packaging & delivery | Helm, ArgoCD (app-of-apps GitOps) | Declarative packaging and drift-free deployment |
| CI/CD & supply chain | GitHub Actions, CodeQL (SAST), Trivy (image scan), Syft (SBOM), cosign (signing) | Nothing reaches the cluster unscanned or unsigned |
| Identity | Microsoft Entra Workload Identity Federation / AWS IRSA (OIDC, no static cloud secrets), Key Vault | Zero-trust identity end to end |
| Networking/Edge | Azure Front Door + WAF, AWS ALB, Kubernetes NetworkPolicies | Defense at the edge and inside the cluster |
| Observability | OpenTelemetry, Prometheus, Grafana, SLO/error-budget alerting | Production-shaped visibility into what's running |
| Platform/IDP | Backstage software templates for tenant/service onboarding | Self-service golden paths for new tenants |
| FinOps | Orphan-resource bot, Cost Management API dashboards | Cost as a first-class, visible signal |
| AI ops assistant | Alert-triage assistant (stretch) | Agentic response to SLO burn-rate alerts |
