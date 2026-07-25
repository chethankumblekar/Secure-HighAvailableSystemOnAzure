# Project tour

A single-page walkthrough of TenantForge with real evidence per phase, not
marketing copy. [`docs/roadmap.md`](../roadmap.md) is the authoritative
phase-by-phase status and stays the source of truth; this page adds visual
proof and fresh, dated command output where it exists, and links back to
roadmap.md for the full verification narrative rather than repeating it.
See also [`docs/architecture.md`](../architecture.md) for the system diagram,
[`docs/well-architected-review.md`](../well-architected-review.md) for the
pillar-by-pillar review, and [`docs/adr/`](../adr/) for the 4 real decisions
made along the way.

**Honesty note on proof format**: this repo's existing convention is precise
text (tables, CLI output, metrics) over screenshots; no images existed
anywhere in the repo before this page. Where a phase has a real UI
(ArgoCD, Grafana, the AWS/CloudWatch console, Backstage), this page uses a
real screenshot/gif once one has actually been captured, never a
description of what one would show. Where a phase is CLI-only, the proof is
real command output, run fresh for this page (dated below), not copied from
an old log.

## Phase 0: Plan

ADRs, architecture doc, full repo scaffold. See
[ADR-0001](../adr/0001-architecture-foundations.md) for the cost-tier
discipline (local $0, then CI free tier, then short real-cloud bursts) that
shapes every other phase on this page, and
[`docs/architecture.md`](../architecture.md) for the target-state diagram.

## Phase 1: Azure landing zone

🚧 Terraform modules (`infra/terraform/azure`) are wired but not yet applied
against real Azure, see [roadmap.md](../roadmap.md#cost-tiers-from-adr-0001).
No proof to show here yet; nothing to verify until a real `terraform apply`
runs.

## Phase 1b: AWS reference implementation

✅ VPC/EKS/IAM/ALB-policy applied and verified for real once already (see
roadmap.md's Phase 1b row for the `kubectl get nodes` proof). **Visual proof
of the full stack running on real EKS (ArgoCD Applications Healthy, the
real ALB, ArgoCD/Grafana screenshots) comes from the live AWS session
recorded per [`docs/demo-script.md`](../demo-script.md); not yet captured as
of this page's last update.**

## Phase 2: Reference workload

`workloads/sample-service`, a Go notes API, distroless image (~13MB), Helm
chart. Verified end-to-end on local `kind` (see roadmap.md). No fresh local
screenshot today: capturing one needs a local `kind`/Docker cluster, which
this machine's disk space couldn't support at the time of writing (see
Phase 4 below). Tomorrow's AWS session re-proves this exact chart running
for real, on real infrastructure, which doubles as updated visual proof.

## Phase 3: CI/CD + GitOps

GitHub Actions (build/test, Trivy, Syft, GHCR push, cosign sign + SBOM
attest) then ArgoCD auto-deploy, both verified for real (image publicly
pullable, cosign signature independently verified against Rekor, see root
[`README.md`](../../README.md) and roadmap.md's Phase 3 row). Same note as
Phase 2: a fresh local ArgoCD-UI screenshot is blocked by today's local disk
space issue; tomorrow's AWS session captures this live against a real EKS
cluster instead.

## Phase 4: Observability

OTel, Prometheus, Grafana, SLO alerting. Already verified for real on
local `kind` including a full GitOps path (see roadmap.md's detailed Phase 4
row, the most thoroughly verified phase in the project). **Attempted
to capture a fresh Grafana/Prometheus screenshot for this page today; the
local `kind` cluster spun up for it hit a full local disk
(`/System/Volumes/Data` at 100% capacity) that also broke Docker's own
image store mid-task. Captured nothing new as a result, by design rather
than silently faking it.** Tomorrow's AWS session captures this live
instead, on the real EKS cluster (no local Docker/kind involved there).

## Phase 5: Security hardening

NetworkPolicy tenant isolation + OPA/Gatekeeper admission policy, verified
on a Calico-enabled `kind` cluster: cross-namespace traffic blocked, a
non-compliant pod (wrong registry, root, no resource limits) rejected by all
three Gatekeeper constraints (roadmap.md has the full story, including a
real Rego bug found and fixed along the way). Re-running this live for a
fresh capture needs the same local `kind`/Docker setup blocked today; not
yet re-captured. **WAF is the one sub-item with genuinely new proof coming
tomorrow**: AWS WAF (`infra/terraform/aws/modules/waf`) is greenfield work
from today, verified live (a blocked request plus the CloudWatch
sampled-requests console) during tomorrow's AWS session.

## Phase 6: FinOps

`finops/orphan-cleanup/orphan_cleanup.py` and
`finops/cost-dashboards/cost_report.py`: real AWS Cost Explorer / resource
scans, no local cluster needed. Re-run fresh for this page:

```
$ python3 finops/orphan-cleanup/orphan_cleanup.py --project tenantforge --region eu-north-1
No orphaned 'tenantforge' resources found in eu-north-1.
```

```
$ python3 finops/cost-dashboards/cost_report.py --days 30
AWS spend, 2026-06-25 to 2026-07-25 (UnblendedCost, USD)
...
Grand total: $0.00
```

Both captured 2026-07-25, with no AWS infra currently applied: the
apply-demo-destroy discipline holding exactly as designed. New today: a
scheduled GitHub Actions check (`.github/workflows/finops-scheduled.yml`)
that keeps running this as a standing guardrail even after infra is torn
down, plus a Grafana "TenantForge FinOps" cost panel
(`observability/finops/`), both proven live during tomorrow's AWS session.

## Phase 7: Platform/IDP

Backstage golden-path template (`platform/backstage`), a real instance
scaffolding a Go service + Dockerfile + Helm chart, verified by driving the
actual UI and confirming all 15 templated files (roadmap.md's Phase 7 row).
A fresh golden-path gif for this page needs `yarn install`/`yarn start`
(Node 25 on this machine dropped bundled Corepack, so also a one-time
`npm install -g corepack` first); not attempted today given the local disk
issue. A reasonable next local session to pick up once disk space is freed.

## Phase 8: AI ops assistant

`ai-ops-assistant/triage.py` gathers real context (runbook, recent commits,
live Prometheus metric) and drafts a triage note via the Claude API;
`webhook_receiver.py` makes that automatic from a real Alertmanager POST.
Both re-run fresh for this page, no cluster needed, using real repo git log
and runbook content, not fixtures:

```
$ python3 triage.py --alert SampleServiceHighLatency \
    --label route="/tenants/{tenantID}/notes" \
    --annotation summary="p95 above 500ms for 10m" --dry-run
Alert: SampleServiceHighLatency
...
Recent commits touching the affected code:
  3f65e81 Add automated tests for every component, wire into CI, document the flow
  b74cc3f Phase 5: NetworkPolicy tenant isolation + OPA/Gatekeeper admission policy
  7dcbfe0 docs: tighten tone, fix stale status, verify ArgoCD sync for real
  ...
Runbook:
# Runbook: `SampleServiceHighLatency`
...
```

And the real webhook path: a genuine HTTP POST against a locally running
`webhook_receiver.py`, no `ANTHROPIC_API_KEY` set, showing the actual
graceful-fallback code path (`webhook_receiver.py`'s `_triage()`), not a
description of it:

```
$ curl -s -X POST http://localhost:9095/alerts -H 'Content-Type: application/json' -d '{...}'
accepted

(server stderr)
=== Triaging SampleServiceHighLatency ===
could not reach the Claude API ("Could not resolve authentication method...");
falling back to the raw context:
Alert: SampleServiceHighLatency
...
```

Both captured 2026-07-25. The live Claude API call itself remains
structurally-verified-only: no `ANTHROPIC_API_KEY` in this environment
(same caveat roadmap.md already states for Phase 8).

## Phase 9: Load test, DR drill, write-up

k6 load test done for real against `sample-service` on local `kind` with
the full observability stack alongside, see
[`docs/load-test-report.md`](../load-test-report.md) for the full numbers
(20 VUs: p95=10ms, comfortably inside SLO; 100 VUs stress: p95=2.4s,
`SampleServiceHighLatency` confirmed `pending` in Prometheus mid-run). Not
re-run today (same local disk constraint as Phase 4/5/7). Tomorrow's AWS
session re-runs the stress variant against the real ALB, with the Grafana
dashboard reacting live: genuinely new proof, not a repeat. DR drill, blog
post, and demo video remain not started, per roadmap.md.

## What's next for this page

- Tomorrow's AWS live session (`docs/demo-script.md`) fills in: Phase 1b/2/3
  running on real EKS, Phase 5's WAF block + CloudWatch console, Phase 6's
  Grafana FinOps panel, Phase 9's live stress test reacting in Grafana, and
  the recorded video link once uploaded.
- A follow-up local session (once disk space is resolved) can add: Phase 4's
  local Grafana/Prometheus/ArgoCD screenshots, Phase 5's Gatekeeper rejection
  proof, Phase 7's Backstage golden-path gif.
