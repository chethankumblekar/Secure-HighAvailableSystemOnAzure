#!/usr/bin/env python3
"""HTTP receiver for Alertmanager's webhook notifications — the piece that
turns triage.py from "run manually with --alert" into "runs automatically
when an alert actually fires." Configure as an Alertmanager receiver
(alertmanager.config.receivers in observability/prometheus/values.yaml)
pointing at wherever this is running.

Alertmanager expects a fast 2xx ack, not a long-running request, so this
never blocks the response on the Claude API call — see handle_payload's
docstring for why that's a documented limitation, not an oversight.

parse_alertmanager_payload is a pure function tested against a fixture
matching Alertmanager's real webhook JSON shape (see Alertmanager's own
docs for the schema). The HTTP server itself isn't unit-tested — same
"boundary" pattern as the rest of this repo's Python tools.
"""
from __future__ import annotations

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

from triage import ALERT_INFO, build_prompt, draft_triage_note, gather_context


def parse_alertmanager_payload(payload: dict) -> list[dict]:
    """Extracts the firing alerts this tool knows how to triage from a raw
    Alertmanager webhook body. Ignores resolved alerts and alerts for
    anything not in triage.ALERT_INFO (e.g. kube-prometheus-stack's own
    built-in Watchdog/NodeClockNotSynchronising alerts) rather than
    erroring on them — this receiver only has runbooks for TenantForge's
    own alerts.
    """
    known = []
    for alert in payload.get("alerts", []):
        if alert.get("status") != "firing":
            continue
        labels = alert.get("labels", {})
        alertname = labels.get("alertname")
        if alertname not in ALERT_INFO:
            continue
        known.append(
            {
                "alertname": alertname,
                "labels": labels,
                "annotations": alert.get("annotations", {}),
            }
        )
    return known


def make_handler(prometheus_url: str | None, model: str):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            sys.stderr.write(f"{self.address_string()} - {format % args}\n")

        def do_GET(self):
            if self.path == "/healthz":
                self._respond(200, b"ok")
            else:
                self._respond(404, b"not found")

        def do_POST(self):
            if self.path != "/alerts":
                self._respond(404, b"not found")
                return

            length = int(self.headers.get("Content-Length", 0))
            try:
                payload = json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError:
                self._respond(400, b"invalid JSON")
                return

            # Ack immediately — Alertmanager retries on anything but 2xx,
            # and triage note generation (an LLM call) shouldn't block that.
            self._respond(200, b"accepted")

            for alert in parse_alertmanager_payload(payload):
                self._triage(alert)

        def _triage(self, alert: dict) -> None:
            ctx = gather_context(
                alert["alertname"],
                labels=alert["labels"],
                annotations=alert["annotations"],
                prometheus_url=prometheus_url,
            )
            print(f"\n=== Triaging {alert['alertname']} ===", file=sys.stderr)
            try:
                note = draft_triage_note(ctx, model=model)
            except Exception as exc:  # report, don't crash the server on an API failure
                print(
                    f"could not reach the Claude API ({exc}); falling back to the raw context:\n{build_prompt(ctx)}",
                    file=sys.stderr,
                )
                return
            print(note, file=sys.stderr)

        def _respond(self, status: int, body: bytes) -> None:
            self.send_response(status)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=9095)
    parser.add_argument("--prometheus-url", default=None)
    parser.add_argument("--model", default="claude-opus-4-8")
    args = parser.parse_args(argv)

    server = HTTPServer(("0.0.0.0", args.port), make_handler(args.prometheus_url, args.model))
    print(f"listening on :{args.port} (POST /alerts, GET /healthz)", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
