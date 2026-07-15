# Reference workload

Phase 2 of [the roadmap](../../docs/roadmap.md). A deliberately boring
multi-tenant notes API — in-memory store, no framework, standard library
only — that exists only to prove the platform works end-to-end. The
platform is the star, not this service.

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/healthz` | Liveness probe |
| GET | `/readyz` | Readiness probe |
| GET | `/metrics` | Minimal Prometheus-format metrics |
| GET | `/tenants/{tenantID}/notes` | List a tenant's notes |
| POST | `/tenants/{tenantID}/notes` | Create a note (`{"text": "..."}`) |
| GET | `/tenants/{tenantID}/notes/{id}` | Get one note |

Notes are strictly tenant-scoped: `Store.Get` refuses to return a note
whose `tenantID` doesn't match the one in the URL, even if the ID is
guessed correctly.

## Run locally (no container)

```bash
go run ./cmd/server
curl localhost:8080/healthz
```

## Build the container

```bash
docker build -t tenantforge/sample-service:dev .
```

Multi-stage build onto `gcr.io/distroless/static-debian12:nonroot` — no
shell, no package manager, non-root by default. Final image is ~13MB.

## Deploy to a local kind cluster

```bash
kind create cluster --name tenantforge
kind load docker-image tenantforge/sample-service:dev --name tenantforge
helm install sample-service ./helm --kube-context kind-tenantforge --wait
kubectl --context kind-tenantforge port-forward svc/sample-service 8080:80
curl localhost:8080/healthz
```

**Note on `runAsNonRoot`**: distroless's `nonroot` user is name-based in
the image metadata, so kubelet can't verify `runAsNonRoot: true` without an
explicit numeric UID. `helm/values.yaml` pins `runAsUser: 65532`
(distroless's standard nonroot UID) — without it, the pod fails with
`CreateContainerConfigError`. Found and fixed during local `kind`
verification of this chart.

Tear down: `kind delete cluster --name tenantforge`.

## Not yet wired up

- No real database — Azure SQL lands in a later infra phase.
- `serviceAccount.workloadIdentityClientId` in `helm/values.yaml` is empty
  until Backstage-driven tenant onboarding (Phase 7) sets a real one.
- Ingress and HPA templates exist but are disabled by default
  (`ingress.enabled` / `autoscaling.enabled`) — no Front Door/WAF or KEDA
  yet to make them meaningful.
- Not in `ci.yml` or `platform/argocd` yet — those are Phase 3.
