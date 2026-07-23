"""parse_alertmanager_payload against a fixture matching Alertmanager's
real webhook JSON shape (https://prometheus.io/docs/alerting/latest/configuration/#webhook_config
— the version/groupKey/commonLabels envelope is what a real Alertmanager
sends, not a simplified stand-in).
"""
from webhook_receiver import parse_alertmanager_payload

REALISTIC_PAYLOAD = {
    "version": "4",
    "groupKey": '{}:{alertname="SampleServiceHighLatency"}',
    "status": "firing",
    "receiver": "ai-ops-assistant",
    "groupLabels": {"alertname": "SampleServiceHighLatency"},
    "commonLabels": {
        "alertname": "SampleServiceHighLatency",
        "severity": "warning",
        "route": "/tenants/{tenantID}/notes",
    },
    "commonAnnotations": {
        "summary": "sample-service p95 latency above 500ms on /tenants/{tenantID}/notes",
    },
    "externalURL": "http://localhost:9093",
    "alerts": [
        {
            "status": "firing",
            "labels": {
                "alertname": "SampleServiceHighLatency",
                "severity": "warning",
                "route": "/tenants/{tenantID}/notes",
            },
            "annotations": {
                "summary": "sample-service p95 latency above 500ms on /tenants/{tenantID}/notes",
                "runbook_url": "https://github.com/chethankumblekar/tenantforge/blob/main/docs/runbooks/high-latency.md",
            },
            "startsAt": "2026-07-23T10:00:00Z",
            "endsAt": "0001-01-01T00:00:00Z",
            "generatorURL": "http://localhost:9090/graph?g0.expr=...",
            "fingerprint": "abc123",
        }
    ],
}


def test_extracts_firing_alert_this_tool_knows():
    result = parse_alertmanager_payload(REALISTIC_PAYLOAD)

    assert len(result) == 1
    assert result[0]["alertname"] == "SampleServiceHighLatency"
    assert result[0]["labels"]["route"] == "/tenants/{tenantID}/notes"
    assert "runbook_url" in result[0]["annotations"]


def test_ignores_resolved_alerts():
    payload = {
        "alerts": [
            {"status": "resolved", "labels": {"alertname": "SampleServiceHighLatency"}, "annotations": {}}
        ]
    }

    assert parse_alertmanager_payload(payload) == []


def test_ignores_alerts_with_no_runbook():
    # e.g. kube-prometheus-stack's built-in Watchdog / NodeClockNotSynchronising —
    # real alerts, just not ones this tool has a runbook for.
    payload = {
        "alerts": [
            {"status": "firing", "labels": {"alertname": "Watchdog"}, "annotations": {}},
        ]
    }

    assert parse_alertmanager_payload(payload) == []


def test_handles_multiple_alerts_mixed_status():
    payload = {
        "alerts": [
            {"status": "firing", "labels": {"alertname": "SampleServiceDown"}, "annotations": {}},
            {"status": "resolved", "labels": {"alertname": "SampleServiceHighErrorRate"}, "annotations": {}},
            {"status": "firing", "labels": {"alertname": "Watchdog"}, "annotations": {}},
        ]
    }

    result = parse_alertmanager_payload(payload)

    assert len(result) == 1
    assert result[0]["alertname"] == "SampleServiceDown"


def test_empty_alerts_list():
    assert parse_alertmanager_payload({"alerts": []}) == []
