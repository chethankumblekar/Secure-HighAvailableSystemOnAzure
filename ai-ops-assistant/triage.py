#!/usr/bin/env python3
"""Reads a firing alert from the Phase 4 observability stack
(observability/prometheus/slo-rules.yaml) and drafts a first-response
triage note: likely cause, the relevant runbook, the current metric value,
and recent commits that touched the affected code — a starting point for
whoever's responding, not a replacement for the runbook.

Two independent layers, deliberately: gather_context()/build_prompt() are
pure/near-pure and unit-tested against this real repo's files, git
history, and fixture Prometheus responses. draft_triage_note() is the one
function that calls the Anthropic API and is not unit-tested — same
boundary as finops/cost-dashboards/cost_report.py's fetch_cost_and_usage.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Mirrors observability/prometheus/slo-rules.yaml exactly: which runbook
# and which PromQL query answers "what's happening right now" per alert.
ALERT_INFO = {
    "SampleServiceHighErrorRate": {
        "runbook": "docs/runbooks/high-error-rate.md",
        "query": 'sample_service:error_ratio:rate5m',
        "paths": ["workloads/sample-service"],
    },
    "SampleServiceHighLatency": {
        "runbook": "docs/runbooks/high-latency.md",
        "query": 'histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="sample-service"}[5m])) by (le))',
        "paths": ["workloads/sample-service"],
    },
    "SampleServiceDown": {
        "runbook": "docs/runbooks/service-down.md",
        "query": 'up{job="sample-service"}',
        "paths": ["workloads/sample-service", "observability/otel-collector"],
    },
}


@dataclass
class Context:
    alertname: str
    labels: dict = field(default_factory=dict)
    annotations: dict = field(default_factory=dict)
    runbook_text: str | None = None
    metric_value: float | None = None
    recent_commits: list[str] = field(default_factory=list)


def read_runbook(alertname: str, repo_root: Path = REPO_ROOT) -> str | None:
    info = ALERT_INFO.get(alertname)
    if not info:
        return None
    path = repo_root / info["runbook"]
    if not path.exists():
        return None
    return path.read_text()


def recent_commits(alertname: str, repo_root: Path = REPO_ROOT, limit: int = 5) -> list[str]:
    info = ALERT_INFO.get(alertname)
    if not info:
        return []
    try:
        out = subprocess.run(
            ["git", "log", f"-{limit}", "--oneline", "--", *info["paths"]],
            cwd=repo_root,
            capture_output=True,
            text=True,
            timeout=10,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return []
    return [line for line in out.stdout.splitlines() if line.strip()]


def query_prometheus(query: str, prometheus_url: str) -> float | None:
    import requests

    try:
        resp = requests.get(f"{prometheus_url}/api/v1/query", params={"query": query}, timeout=5)
        resp.raise_for_status()
        result = resp.json()["data"]["result"]
        if not result:
            return None
        return float(result[0]["value"][1])
    except Exception:
        return None


def gather_context(
    alertname: str,
    labels: dict | None = None,
    annotations: dict | None = None,
    prometheus_url: str | None = None,
    repo_root: Path = REPO_ROOT,
) -> Context:
    info = ALERT_INFO.get(alertname)
    metric_value = None
    if prometheus_url and info:
        metric_value = query_prometheus(info["query"], prometheus_url)

    return Context(
        alertname=alertname,
        labels=labels or {},
        annotations=annotations or {},
        runbook_text=read_runbook(alertname, repo_root),
        metric_value=metric_value,
        recent_commits=recent_commits(alertname, repo_root),
    )


def build_prompt(ctx: Context) -> str:
    lines = [
        f"Alert: {ctx.alertname}",
        f"Labels: {json.dumps(ctx.labels)}" if ctx.labels else "Labels: (none provided)",
        f"Annotations: {json.dumps(ctx.annotations)}" if ctx.annotations else "Annotations: (none provided)",
        "",
        f"Current metric value: {ctx.metric_value}" if ctx.metric_value is not None else "Current metric value: unavailable",
        "",
        "Recent commits touching the affected code:",
    ]
    if ctx.recent_commits:
        lines.extend(f"  {c}" for c in ctx.recent_commits)
    else:
        lines.append("  (none found, or git history unavailable)")

    lines.append("")
    if ctx.runbook_text:
        lines.append("Runbook:")
        lines.append(ctx.runbook_text)
    else:
        lines.append("No runbook found for this alert.")

    return "\n".join(lines)


SYSTEM_PROMPT = (
    "You are drafting a first-response triage note for an on-call engineer "
    "who just saw this alert fire. You have the alert's labels/annotations, "
    "its current metric value, recent commits touching the affected code, "
    "and the team's runbook for this alert. Write a short note (under 150 "
    "words): likely cause given the evidence, whether a recent commit looks "
    "related, and the single most useful next step from the runbook. Do not "
    "restate the whole runbook — the responder can read it themselves; link "
    "to it. If the evidence is inconclusive, say so plainly rather than "
    "guessing."
)


def draft_triage_note(ctx: Context, model: str = "claude-opus-4-8") -> str:
    import anthropic

    client = anthropic.Anthropic()
    response = client.messages.create(
        model=model,
        max_tokens=1024,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": build_prompt(ctx)}],
    )
    return next(b.text for b in response.content if b.type == "text")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--alert", required=True, choices=sorted(ALERT_INFO.keys()))
    parser.add_argument("--label", action="append", default=[], metavar="KEY=VALUE")
    parser.add_argument("--annotation", action="append", default=[], metavar="KEY=VALUE")
    parser.add_argument("--prometheus-url", default=None, help="e.g. http://localhost:9090")
    parser.add_argument("--model", default="claude-opus-4-8")
    parser.add_argument("--dry-run", action="store_true", help="print the prompt instead of calling the API")
    args = parser.parse_args(argv)

    def parse_kv(pairs: list[str]) -> dict:
        return dict(p.split("=", 1) for p in pairs)

    ctx = gather_context(
        args.alert,
        labels=parse_kv(args.label),
        annotations=parse_kv(args.annotation),
        prometheus_url=args.prometheus_url,
    )

    if args.dry_run:
        print(build_prompt(ctx))
        return 0

    print(draft_triage_note(ctx, model=args.model))
    return 0


if __name__ == "__main__":
    sys.exit(main())
