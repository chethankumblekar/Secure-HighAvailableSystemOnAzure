## What changed and why

<!-- Link the roadmap phase (docs/roadmap.md) or issue this relates to. -->

## Checks run

<!-- Delete lines that don't apply. -->

- [ ] `go vet ./...` and `go test ./...` (workloads/sample-service)
- [ ] `terraform fmt -check` / `terraform validate` (infra/terraform/<cloud>)
- [ ] `helm lint` on the affected chart
- [ ] Verified against a local `kind` cluster (describe how below)

## Verification

<!-- What you actually ran/observed to confirm this works — not just that it compiles. -->

## ADR

<!-- If this is a non-trivial decision or tradeoff, link the ADR added in this PR (docs/adr/), or explain why one isn't needed. -->
