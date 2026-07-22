# ArgoCD app-of-apps

## Local (Tier 1, kind) — try it

```bash
kind create cluster --name tenantforge-argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

kubectl apply -f app-of-apps/root-app.yaml
```

That one `kubectl apply` is the only manual step — ArgoCD then reads every
`overlays/local/*-app.yaml` from git itself: `sample-service-app.yaml`
syncs `workloads/sample-service/helm`, pulling the real image CI publishes
to GHCR (not a locally-built one); `kube-prometheus-stack-app.yaml` and
`observability-app.yaml` bring up the Phase 4 observability stack (see
[`observability/`](../../observability)). All of them self-heal if
anything drifts.

Port-forward the UI to watch it sync: `kubectl -n argocd port-forward
svc/argocd-server 8080:443`. Get the initial admin password:
`kubectl -n argocd get secret argocd-initial-admin-secret -o
jsonpath='{.data.password}' | base64 -d`.

## Azure (Tier 3, AKS) — not usable yet

`overlays/azure/sample-service-app.yaml` has a placeholder
`destination.server` — it needs the real AKS cluster registered
(`argocd cluster add`) once Phase 1's `terraform apply` actually runs.

## AWS (Tier 3b) — cluster live, ArgoCD not yet targeted at it

The Phase 1b EKS cluster (`infra/terraform/aws`) is applied and verified,
but there's no `overlays/aws/` yet — that's the remaining step to prove
the same GitOps definitions deploy to it, not just AKS/`kind`.
