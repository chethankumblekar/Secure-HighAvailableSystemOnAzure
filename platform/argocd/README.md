# ArgoCD app-of-apps

## Local (Tier 1, kind) — try it

```bash
kind create cluster --name tenantforge-argocd
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

kubectl apply -f app-of-apps/root-app.yaml
```

That one `kubectl apply` is the only manual step — ArgoCD then reads
`overlays/local/sample-service-app.yaml` from git itself and syncs
`workloads/sample-service/helm`, pulling the real image CI publishes to
GHCR (not a locally-built one), self-healing if anything drifts.

Port-forward the UI to watch it sync: `kubectl -n argocd port-forward
svc/argocd-server 8080:443`. Get the initial admin password:
`kubectl -n argocd get secret argocd-initial-admin-secret -o
jsonpath='{.data.password}' | base64 -d`.

## Azure (Tier 3, AKS) — not usable yet

`overlays/azure/sample-service-app.yaml` has a placeholder
`destination.server` — it needs the real AKS cluster registered
(`argocd cluster add`) once Phase 1's `terraform apply` actually runs.

## AWS (Tier 3b) — not built

No `overlays/aws/` yet — waits on the Phase 1b EKS reference implementation.

## A note on repo URLs

Every manifest here points at the **current** GitHub repo name
(`Secure-HighAvailableSystemOnAzure`), not `tenantforge` — the rename is
still pending (see `docs/roadmap.md`). Update `repoURL` in every
`overlays/*/*.yaml` and `app-of-apps/root-app.yaml` once that happens.
