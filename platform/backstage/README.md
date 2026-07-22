# Backstage golden paths

Placeholder — Phase 7 of [the roadmap](../../docs/roadmap.md).

Will hold Backstage software templates for self-service tenant/service
onboarding: a developer fills in a form, the template invokes the
Terraform modules in `infra/terraform/azure` and registers the new service
in ArgoCD — the golden path from "I need a new service" to a deployed,
observed, GitOps-managed workload, without a platform engineer in the
loop for each request.
