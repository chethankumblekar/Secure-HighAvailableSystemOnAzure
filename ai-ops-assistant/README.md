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

## Webhook receiver

`webhook_receiver.py` is the automatic path: an HTTP server that
Alertmanager POSTs to when an alert fires, so triage runs without anyone
invoking `triage.py --alert` by hand.

```bash
python3 webhook_receiver.py --port 9095 --prometheus-url http://localhost:9090
```

It exposes `GET /healthz` and `POST /alerts` (the shape Alertmanager's
`webhook_config` sends). Alertmanager expects a fast 2xx ack, so the
server responds immediately and runs triage after — see the module
docstring for why that's deliberate, not a missed timeout. Alerts for
anything not in `triage.ALERT_INFO` (e.g. kube-prometheus-stack's own
`Watchdog`) are ignored rather than erroring, since this receiver only
has runbooks for TenantForge's own alerts.

Wired into Alertmanager via `observability/prometheus/values.yaml`'s
`alertmanager.config` — routes the three `SampleService*` alerts to
`http://host.docker.internal:9095/alerts`. `host.docker.internal` is
Docker Desktop-specific (macOS/Windows); on Linux either run `kind` with
an equivalent `extraMounts`/`--add-host` hostname, or deploy the receiver
in-cluster instead.

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

The full pipeline was verified end-to-end on a local `kind` cluster
(`tenantforge-aiops`): `sample-service` + OTel collector + kube-prometheus-stack
installed with the `alertmanager.config` receiver wired to a
`webhook_receiver.py` running on the host, scaled `sample-service` to 0
to induce a real `SampleServiceDown`, and confirmed Alertmanager itself —
not a manually-crafted curl payload — routed the firing alert to the
receiver. The receiver's log showed the real POST, `parse_alertmanager_payload`
extracting the alert, `gather_context` pulling the matching runbook and
recent commits, and the documented graceful fallback when the Claude API
call fails for lack of a key. `test_webhook_receiver.py` covers
`parse_alertmanager_payload` against a fixture matching Alertmanager's
real webhook JSON shape.

## Not yet wired up

- No posting the drafted note anywhere (Slack, a GitHub issue comment) —
  prints to stdout (or, via the webhook receiver, to stderr on whatever
  host is running it).
