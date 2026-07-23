# AI ops assistant

Phase 8 of [the roadmap](../docs/roadmap.md), stretch goal. `triage.py`
takes an alert from the Phase 4 observability stack
(`observability/prometheus/slo-rules.yaml`) and drafts a first-response
note using the Claude API: likely cause, whether a recent commit looks
related, and the single most useful next step from the runbook — a
starting point for the responder, not a replacement for the runbook it
always links to.

## Use it

```bash
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...

python3 triage.py --alert SampleServiceHighLatency \
  --label route="/tenants/{tenantID}/notes" \
  --annotation summary="p95 above 500ms for 10m" \
  --prometheus-url http://localhost:9090
```

`--alert` is one of the three alerts `slo-rules.yaml` actually defines:
`SampleServiceHighErrorRate`, `SampleServiceHighLatency`,
`SampleServiceDown`. `--prometheus-url` is optional — point it at a live
Prometheus (e.g. `kubectl -n observability port-forward
svc/kube-prometheus-stack-prometheus 9090:9090`, see
[`observability/prometheus/README.md`](../observability/prometheus/README.md))
to include the current metric value; omit it to skip that context. Real
Alertmanager integration would call this from a webhook receiver with the
alert's actual labels/annotations instead of passing them by hand.

Add `--dry-run` to print the constructed prompt without calling the API —
useful for checking what context was actually gathered before spending a
request on it.

## Verified for real

Context-gathering runs against this repo's real files and real git
history — verified with `--dry-run`: the correct runbook loads, recent
commits touching `workloads/sample-service` show up, and the prompt is
well-formed. `test_triage.py` covers this plus a mocked-Prometheus-response
test for `query_prometheus`.

`draft_triage_note` (the actual Anthropic API call) is verified
structurally — it matches the documented Messages API request shape — but
not invoked live in this environment, which has no `ANTHROPIC_API_KEY`
configured for standalone scripts to use. Same boundary as
[`finops/cost-dashboards`](../finops/cost-dashboards/README.md)'s AWS
calls: the parts that can be tested without live credentials are tested;
the credentialed call itself is correct by construction.

## Not yet wired up

- No Alertmanager webhook receiver — invoked manually with `--alert`
  today, not triggered automatically when an alert actually fires.
- No posting the drafted note anywhere (Slack, a GitHub issue comment) —
  prints to stdout.
