# ${{ values.name }}

${{ values.description }}

Generated from TenantForge's `tenant-service` golden-path template — a
health-checked Go HTTP server, Dockerfile, and Helm chart, following the
same pattern as `workloads/sample-service`.

## Run locally

```bash
go run ./cmd/server
curl localhost:8080/healthz
```

## Build the container

```bash
docker build -t ${{ values.name }}:dev .
```

## Deploy to a local kind cluster

```bash
kind load docker-image ${{ values.name }}:dev --name <your-cluster>
helm install ${{ values.name }} ./helm --wait
```

## Not yet wired up

This skeleton doesn't yet include CI (see `.github/workflows/ci.yml` in the
main TenantForge repo for the pattern this would follow), an ArgoCD
Application, or cloud workload identity — those are manual follow-up steps
today. Automating them is the next iteration of the golden path.
