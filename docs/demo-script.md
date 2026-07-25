# Demo script: real AWS deployment recording

A step-by-step runbook for the live recording session: real `terraform
apply` against `eu-north-1`, ArgoCD deploying the same GitOps definitions
that already run on `kind` onto the real EKS cluster, WAF/load-test/FinOps
verification, then `terraform destroy`. Follow this in order while
screen-recording. Narration cues are marked **Say:**.

Matches the apply → demo → destroy cost-tier discipline from
[ADR-0001](adr/0001-architecture-foundations.md): everything costly comes
down the same day. See [`docs/roadmap.md`](roadmap.md) for which phases this
closes out.

## 0. Pre-flight (should already be true from today's prep)

```bash
scripts/test-all.sh
scripts/validate-manifests.sh
aws eks list-clusters --region eu-north-1   # expect: empty
git status                                   # expect: clean, all prep committed
```

**Say:** what's about to happen and why. This proves the same Helm/ArgoCD
definitions verified on `kind` and (partially) Azure also deploy to real
AWS, closes out Phase 1b/5/6 of the roadmap, and stays inside the project's
$0-by-default cost discipline (apply, verify, destroy, same day).

## 1. Apply

```bash
cd infra/terraform/aws
terraform apply
cd ../../..
```

TFC workspace `tenantforge-aws-dev`. Takes ~10-15 min (EKS control plane is
the slow part). **Say:** what's being created: VPC/NAT, EKS cluster + node
group, IAM roles (LB controller, FinOps cost-reporter, GitHub OIDC), the WAF
web ACL. Note that the ALB itself isn't created yet; it's created
dynamically later by the AWS Load Balancer Controller from a Kubernetes
Ingress.

## 2. Resolve the placeholder values

Four files have `PLACEHOLDER_*` tokens, deliberately, the same convention
already used by `platform/argocd/overlays/azure/sample-service-app.yaml` for
values that don't exist until a real apply has run:

```bash
cd infra/terraform/aws
VPC_ID=$(terraform output -raw vpc_id)
LB_ROLE_ARN=$(terraform output -raw lb_controller_role_arn)
FINOPS_ROLE_ARN=$(terraform output -raw finops_cost_reporter_role_arn)
WAF_ARN=$(terraform output -raw waf_web_acl_arn)
cd ../../..

sed -i '' "s#PLACEHOLDER_VPC_ID#$VPC_ID#" platform/argocd/overlays/aws/aws-load-balancer-controller-app.yaml
sed -i '' "s#PLACEHOLDER_LB_CONTROLLER_ROLE_ARN#$LB_ROLE_ARN#" platform/argocd/overlays/aws/aws-load-balancer-controller-app.yaml
sed -i '' "s#PLACEHOLDER_WAF_WEB_ACL_ARN#$WAF_ARN#" platform/argocd/overlays/aws/sample-service-app.yaml
sed -i '' "s#PLACEHOLDER_FINOPS_COST_REPORTER_ROLE_ARN#$FINOPS_ROLE_ARN#" observability/finops/serviceaccount.yaml
```

(`sed -i ''` is the BSD/macOS form.) These edits are local-only, not
committed as-is. The real step at the end reverts them, since the values
are apply-specific (a fresh `vpc-...` id next time) rather than static
config.

**First time only:** set the scheduled FinOps workflow's role. Since
`module.github_oidc` persists across apply/destroy cycles (see the comment
in `infra/terraform/aws/main.tf`), this is a one-time step, not per-demo:

```bash
gh variable set FINOPS_CI_ROLE_ARN --body "$(cd infra/terraform/aws && terraform output -raw finops_ci_role_arn)"
```

## 3. Point kubectl at the real cluster

```bash
aws eks update-kubeconfig --name tenantforge-dev-eks --region eu-north-1
kubectl get nodes   # expect: 1 Ready node
```

## 4. Grafana admin secret (before ArgoCD syncs kube-prometheus-stack)

`observability/prometheus/values.yaml` hardcodes `admin`/`admin`, commented
"local kind demo only, never do this against a real cluster."
`platform/argocd/overlays/aws/kube-prometheus-stack-app.yaml` overrides that
with `grafana.admin.existingSecret`, which must exist before Grafana's pod
starts (self-heals if not, but avoid the churn):

```bash
kubectl create namespace observability
kubectl -n observability create secret generic grafana-admin-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"
```

## 5. Bootstrap ArgoCD on the real cluster

Same steps as `platform/argocd/README.md`'s local section, run against EKS
instead of `kind`:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

kubectl apply -f platform/argocd/app-of-apps/root-app-aws.yaml
```

**Say:** that one `kubectl apply` is the only manual step from here, same
app-of-apps pattern already proven on `kind`, now pointed at real
infrastructure.

## 6. Watch it sync

```bash
kubectl get applications -n argocd -w
```

Wait for `aws-load-balancer-controller`, `sample-service`,
`kube-prometheus-stack`, `observability`, and `finops` to all reach
`Synced`/`Healthy`. `kube-prometheus-stack` takes longest (CRDs). Optional:
port-forward the ArgoCD UI for a visual (`kubectl -n argocd port-forward
svc/argocd-server 8080:443`, password via `kubectl -n argocd get secret
argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`).
Good screen-recording moment, all apps green.

**Save:** screenshot this as `docs/tour/media/aws-argocd-healthy.png`. Fills
in [`docs/tour/README.md`](tour/README.md)'s Phase 1b/2/3 sections.

## 7. Hit the real ALB

```bash
ALB_HOST=$(kubectl get ingress sample-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "$ALB_HOST"
curl -i "http://$ALB_HOST/healthz"
curl -i "http://$ALB_HOST/tenants/tenant-a/notes"
```

May take a minute or two after the Ingress is created for the ALB to
provision and DNS to resolve. **Say:** this is a real public ALB the AWS
Load Balancer Controller created from a plain Kubernetes Ingress object,
same chart, same GHCR image, that ran on `kind`.

## 8. Trip the WAF

```bash
curl -i "http://$ALB_HOST/?q=<script>alert(1)</script>"
```

Expect `403 Forbidden`, blocked by the `AWSManagedRulesCommonRuleSet`
cross-site-scripting rule. Then in the AWS Console: **WAF & Shield → Web
ACLs → `tenantforge-dev-waf` → Sampled requests**. Show the blocked
request live. **Say:** this is Phase 5's WAF, the last item on the roadmap
that was explicitly blocked on a real `terraform apply` existing.

**Save:** the `curl` 403 output and a CloudWatch console screenshot as
`docs/tour/media/aws-waf-block.png`. Fills in `docs/tour/README.md`'s
Phase 5 section.

## 9. Load test against the real ALB, watch it in Grafana

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80 &
```

Open `localhost:3000` (user `admin`, password from the secret in step 4:
`kubectl -n observability get secret grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d`),
pull up the **sample-service SLOs** dashboard, then in another terminal:

```bash
K6_BASE_URL="http://$ALB_HOST" k6 run loadtest/k6/notes-api-stress.js
```

**Say:** same stress script and same result already proven on `kind` (see
[`docs/load-test-report.md`](load-test-report.md): p95 breaches the 500ms
SLO, `SampleServiceHighLatency` goes `pending`). Now watch it happen live
against real cloud infrastructure, on the same dashboard. The rate-based WAF
rule (2000 req/5min/IP) may also start blocking requests near the end of
this run from k6's own IP, worth pointing out if it shows up in the WAF
console's sampled requests.

**Save:** the Grafana SLO dashboard mid-stress-test (latency panel visibly
climbing) as `docs/tour/media/aws-load-test-grafana.gif` or `.png`. Fills
in `docs/tour/README.md`'s Phase 9 section.

## 10. FinOps cost panel

The CronJob runs every 30 min. Trigger one manually rather than waiting:

```bash
kubectl -n observability create job cost-reporter-manual --from=cronjob/cost-reporter
kubectl -n observability wait --for=condition=complete job/cost-reporter-manual --timeout=60s
```

Refresh Grafana, open the **TenantForge FinOps** dashboard. Show the real
`aws_cost_usd_daily` gauge (this will likely be near-$0 still, since Cost
Explorer data lags actual usage by several hours; **say so plainly on
camera** rather than implying otherwise). **Say:** this is Phase 6's
FinOps scheduling + Grafana work, real Cost Explorer data pushed to the
same dashboard as latency/error-rate, not a separate CLI-only tool anymore.

**Save:** screenshot as `docs/tour/media/aws-finops-dashboard.png`. Fills
in `docs/tour/README.md`'s Phase 6 section.

## 11. Teardown

```bash
cd infra/terraform/aws
terraform destroy \
  -target=module.eks \
  -target=module.vpc \
  -target=module.alb \
  -target=module.iam \
  -target=module.waf
cd ../../..
```

Deliberately **not** `-target=module.github_oidc`. See the comment in
`infra/terraform/aws/main.tf`: that role costs $0 and needs to persist so
`.github/workflows/finops-scheduled.yml` keeps running as a standing
guardrail after everything else is gone.

## 12. Prove it's actually clean

```bash
python3 finops/orphan-cleanup/orphan_cleanup.py --project tenantforge --region eu-north-1
python3 finops/cost-dashboards/cost_report.py --days 1
```

**Say:** same zero-orphans proof already run after Phase 1b's first
apply/destroy cycle. Repeating it here confirms this round left nothing
behind either.

## 13. Revert the placeholder substitutions

The real ARNs/VPC ID from step 2 are apply-specific, not static config, so
don't commit them:

```bash
git checkout -- \
  platform/argocd/overlays/aws/aws-load-balancer-controller-app.yaml \
  platform/argocd/overlays/aws/sample-service-app.yaml \
  observability/finops/serviceaccount.yaml
```

## 14. Update the project tour

Move today's `docs/tour/media/aws-*` captures in (git add them for real,
they're not placeholders), then edit
[`docs/tour/README.md`](tour/README.md)'s Phase 1b/2/3/5/6/9 sections to
reference them in place of today's "not yet captured" notes, and drop in
the recorded video link once uploaded.

## 15. Wrap-up talking points

Tie the whole 9-phase story together for the portfolio pitch: multi-cloud
portability (same GitOps definitions on `kind`/EKS, proven not just
claimed), security (NetworkPolicy + Gatekeeper + WAF), observability (OTel
→ Prometheus → Grafana, SLO alerting that actually fired during a real
stress test), cost discipline (apply-demo-destroy, a standing FinOps
guardrail that keeps working after teardown, verified $0 spend), and CI/CD
(signed, scanned, SBOM'd images via GitOps, not manual `kubectl apply`).
