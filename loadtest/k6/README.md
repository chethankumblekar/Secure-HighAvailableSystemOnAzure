# Load test

Phase 9 of [the roadmap](../../docs/roadmap.md). A [k6](https://k6.io)
script (`notes-api.js`) exercising `sample-service`'s notes API with a
mixed multi-tenant workload — create, get-by-id, list, across a pool of
three tenants — so the request mix looks like real usage, not just one
endpoint hammered in isolation.

The pass/fail thresholds are deliberately the exact same numbers as
`observability/prometheus/slo-rules.yaml`'s alerts (p95 latency < 500ms,
error rate < 5%): a clean k6 run and a quiet Grafana dashboard during the
same run are the same SLO claim checked two independent ways.

## Run it locally

Requires a running `sample-service` (see
[`workloads/sample-service/README.md`](../../workloads/sample-service/README.md))
reachable at `localhost:8080` — port-forward it if it's on a `kind`
cluster:

```bash
kubectl port-forward svc/sample-service 8080:80 &

k6 run loadtest/k6/notes-api.js
# or, to point at a different target:
K6_BASE_URL=http://sample-service.example.com k6 run loadtest/k6/notes-api.js

# to keep a machine-readable copy of the results:
k6 run --summary-export=/tmp/summary.json loadtest/k6/notes-api.js
```

For the full picture — not just k6's own client-side numbers, but what
the platform's own observability stack saw during the same run — bring up
`observability/` alongside `sample-service` first (see
[`observability/prometheus/README.md`](../../observability/prometheus/README.md))
and watch the "sample-service SLOs" Grafana dashboard while `k6 run` is
going.

## Load profile

5 minutes total: 30s ramp to 20 VUs, 4m steady at 20 VUs, 30s ramp down.
Each virtual user does create → get-by-id → list, then a 1s think time,
against a randomly chosen tenant per iteration.

## Results

See [`docs/load-test-report.md`](../../docs/load-test-report.md) for the
last recorded run's numbers and what they mean.
