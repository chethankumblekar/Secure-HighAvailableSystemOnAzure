# Backstage golden paths

Phase 7 of [the roadmap](../../docs/roadmap.md). A real
[Backstage](https://backstage.io) instance (`@backstage/create-app`,
SQLite for local dev — no Postgres needed), with one software template:
self-service onboarding for a new tenant service.

## Run it locally

Requires Node 22 (`backstage.json` pins `engines.node: "22 || 24"`):

```bash
cd platform/backstage
yarn install
yarn start
```

Opens the frontend at `localhost:3000`, backend at `localhost:7007`.
Go to **Create** → **New tenant service**, fill in a name and description,
and run it — it scaffolds a health-checked Go HTTP server, Dockerfile, and
Helm chart (`templates/tenant-service/`), following the exact same pattern
already proven in `workloads/sample-service`: distroless image, non-root
security context, the same default-deny `NetworkPolicy` from Phase 5.

## What's registered in the catalog

- `examples/org.yaml` — the `guest` user/group Backstage's auth defaults to locally.
- `examples/entities.yaml` — a `tenantforge` System, and a `sample-service`
  Component so the reference workload shows up in the catalog too.
- `templates/tenant-service/template.yaml` — the golden-path template
  itself.

## Not yet wired up

- **Publishing and catalog registration are manual.** The template's only
  step is `fetch:template` (materializes the skeleton) — there's no
  `publish:github` step, since that needs a GitHub integration token this
  local demo doesn't configure, and would create a real repository as a
  side effect of testing. What you get today is the generated skeleton in
  the task's log output; wiring a real `publish:github` + `catalog:register`
  step is the natural next increment once a token is available.
- **No Terraform or ArgoCD invocation.** The template doesn't yet run
  `infra/terraform/azure` or create an ArgoCD `Application` for the new
  service — Backstage's built-in actions don't cover either, so that would
  mean a custom scaffolder action (e.g. one that opens a PR against
  `platform/argocd/overlays/*` with the new Application manifest). Today,
  wiring CI/CD and GitOps for a scaffolded service is a manual follow-up,
  same as the "Not yet wired up" list in the generated skeleton's own
  README.
- **No RBAC/permission policy** beyond Backstage's default guest auth —
  fine for a local demo, not for a real multi-tenant IDP.
