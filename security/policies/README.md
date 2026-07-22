# Security policies

Phase 5 of [the roadmap](../../docs/roadmap.md). Two independent layers of
in-cluster policy, on top of the Azure Policy assignment already in
`infra/terraform/azure/modules/policy`:

- **NetworkPolicy** — tenant network isolation, defined alongside the
  workload it protects: `workloads/sample-service/helm/templates/networkpolicy.yaml`.
  Default-deny with two explicit allows (same-namespace, and the OTel
  collector's metrics scrape); egress is DNS-only, since this service makes
  no outbound calls of its own.
- **OPA/Gatekeeper** (`gatekeeper/`) — cluster-wide admission policy:
  every pod in the tenant workload namespace must declare resource
  requests/limits, run as non-root, and come from an allowlisted image
  registry. Scoped to the `default` namespace deliberately — the
  observability stack is a third-party Helm chart whose pod specs this
  project doesn't own; these constraints police what a tenant deploys, not
  platform-managed infrastructure.

## Try it locally

Requires a `kind` cluster with a NetworkPolicy-enforcing CNI — the default
`kindnet` CNI does **not** enforce `NetworkPolicy` at all (it's accepted by
the API server and silently never blocks anything), so verifying isolation
actually works means installing Calico instead:

```bash
cat <<'EOF' > /tmp/kind-calico.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
EOF
kind create cluster --name tenantforge-security --config /tmp/kind-calico.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
kubectl -n kube-system rollout status deploy/calico-kube-controllers --timeout=180s
```

Deploy the workload and its NetworkPolicy (part of the Helm chart,
`networkPolicy.enabled: true` by default):

```bash
cd workloads/sample-service
docker build -t tenantforge/sample-service:dev .
kind load docker-image tenantforge/sample-service:dev --name tenantforge-security
helm install sample-service ./helm --kube-context kind-tenantforge-security --wait
```

Confirm isolation is real, not just declared — an unrelated pod in the
same namespace should reach it (allowed), a pod trying from outside the
namespace without the collector's label should not (denied):

```bash
kubectl run allowed --image=curlimages/curl --restart=Never --rm -i \
  -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 3 http://sample-service/healthz
# expect: 200

kubectl create namespace attacker
kubectl -n attacker run denied --image=curlimages/curl --restart=Never --rm -i \
  -- curl -s -o /dev/null -w "%{http_code}\n" --max-time 3 http://sample-service.default.svc.cluster.local/healthz
# expect: curl times out — no response, connection blocked
```

Install Gatekeeper and the constraint templates/constraints:

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.17.1/deploy/gatekeeper.yaml
kubectl -n gatekeeper-system rollout status deploy/gatekeeper-controller-manager --timeout=180s

kubectl apply -f security/policies/gatekeeper/constrainttemplates/
kubectl apply -f security/policies/gatekeeper/constraints/
```

Confirm enforcement, not just presence — `sample-service`'s own pod (already
compliant) should have been admitted; a deliberately non-compliant pod
should be rejected outright:

```bash
kubectl run bad-pod --image=docker.io/library/nginx --restart=Never
# expect: Error from server (Forbidden) — denied by both
# sample-service-allowed-registries (docker.io isn't allowlisted) and
# require-non-root-default-namespace (no securityContext set)
```

Teardown: `kind delete cluster --name tenantforge-security`.

## Not yet wired up

- **WAF** — Azure Front Door + WAF (or AWS WAFv2 on the ALB) is
  cloud-specific infrastructure, not a cluster-local policy; it lands with
  the Terraform landing zone once Phase 1 is actually applied against real
  Azure, not before.
- Gatekeeper constraints aren't yet applied via ArgoCD — installed
  imperatively per the steps above, same as Gatekeeper itself. GitOps-ing
  the constraint templates/constraints is straightforward (they're plain
  YAML, same pattern as `observability/`); Gatekeeper's own installation
  (CRDs + webhook) is the part that needs the same care
  `kube-prometheus-stack-app.yaml` needed for `ServerSideApply`.
