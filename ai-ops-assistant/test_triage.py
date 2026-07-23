"""Tests split along the same real-vs-mocked line as the rest of this
repo's Python tooling (see finops/cost-dashboards/test_cost_report.py):
read_runbook and recent_commits run against this actual repo's real
files and real git history — there's no reason to mock a filesystem and
a git log this test suite already has access to. query_prometheus is
mocked (a real Prometheus HTTP response, not a live server). build_prompt
is a pure function tested against fixtures.
"""
from unittest.mock import MagicMock, patch

import pytest

from triage import ALERT_INFO, Context, build_prompt, query_prometheus, read_runbook, recent_commits


def test_every_alert_has_a_runbook_that_exists_on_disk():
    # Catches drift if a runbook gets renamed/moved without updating
    # ALERT_INFO — the exact bug class this tool exists to avoid.
    from pathlib import Path

    repo_root = Path(__file__).resolve().parent.parent
    for alertname, info in ALERT_INFO.items():
        assert (repo_root / info["runbook"]).exists(), f"{alertname}'s runbook {info['runbook']} is missing"


def test_read_runbook_returns_real_content():
    text = read_runbook("SampleServiceHighLatency")

    assert text is not None
    assert "SampleServiceHighLatency" in text
    assert "resources.limits.cpu" in text  # a specific detail from the real runbook


def test_read_runbook_unknown_alert_returns_none():
    assert read_runbook("SomeAlertThatDoesNotExist") is None


def test_recent_commits_returns_real_git_history():
    commits = recent_commits("SampleServiceHighLatency", limit=3)

    assert len(commits) <= 3
    assert len(commits) > 0
    # Each line is "shortsha subject" from a real `git log --oneline`
    assert all(len(line.split(" ", 1)) == 2 for line in commits)


def test_build_prompt_includes_alert_and_labels():
    ctx = Context(
        alertname="SampleServiceHighLatency",
        labels={"route": "/tenants/{tenantID}/notes"},
        annotations={"summary": "p95 above threshold"},
        runbook_text="## Runbook body",
        metric_value=0.812,
        recent_commits=["abc1234 fix something"],
    )

    prompt = build_prompt(ctx)

    assert "SampleServiceHighLatency" in prompt
    assert "/tenants/{tenantID}/notes" in prompt
    assert "0.812" in prompt
    assert "abc1234 fix something" in prompt
    assert "## Runbook body" in prompt


def test_build_prompt_handles_missing_data_gracefully():
    ctx = Context(alertname="SampleServiceDown")

    prompt = build_prompt(ctx)

    assert "unavailable" in prompt
    assert "No runbook found" in prompt
    assert "none found" in prompt.lower()


def test_query_prometheus_parses_a_real_response_shape():
    # Fixture shape verified by hand against a live Prometheus instance
    # this session (see docs/roadmap.md's Phase 4 entry).
    fake_response = MagicMock()
    fake_response.json.return_value = {
        "status": "success",
        "data": {"resultType": "vector", "result": [{"metric": {}, "value": [1784661115.963, "0.178"]}]},
    }
    fake_response.raise_for_status = MagicMock()

    with patch("requests.get", return_value=fake_response) as mock_get:
        value = query_prometheus('up{job="sample-service"}', "http://localhost:9090")

    assert value == pytest.approx(0.178)
    mock_get.assert_called_once()
    assert mock_get.call_args.kwargs["params"]["query"] == 'up{job="sample-service"}'


def test_query_prometheus_returns_none_on_empty_result():
    fake_response = MagicMock()
    fake_response.json.return_value = {"status": "success", "data": {"resultType": "vector", "result": []}}
    fake_response.raise_for_status = MagicMock()

    with patch("requests.get", return_value=fake_response):
        assert query_prometheus("some_query", "http://localhost:9090") is None


def test_query_prometheus_returns_none_on_connection_error():
    with patch("requests.get", side_effect=ConnectionError("no route to host")):
        assert query_prometheus("some_query", "http://unreachable:9090") is None
