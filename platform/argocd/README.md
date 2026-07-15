# ArgoCD app-of-apps

Placeholder — Phase 3 of [the roadmap](../../docs/roadmap.md).

Will hold the app-of-apps root application plus environment overlays
(`overlays/azure/`, `overlays/aws/`) that sync the Helm chart in
`workloads/sample-service/helm` to AKS and (later) EKS from the same
GitOps repo — the actual proof of cross-cloud portability.
