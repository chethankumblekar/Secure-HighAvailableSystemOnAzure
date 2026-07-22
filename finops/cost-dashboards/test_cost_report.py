"""Tests format_report against fixed Cost Explorer response shapes — the
exact shape returned by the real API (verified by hand against a live
account; see docs/load-test-report.md's sibling note in
docs/roadmap.md's Phase 6 entry). fetch_cost_and_usage itself isn't
tested here: moto doesn't simulate real AWS billing data, so a mocked
Cost Explorer call would only prove the mock returns what the mock was
told to return, not that the parsing handles the real API's shape.
"""
from cost_report import format_report


def test_formats_single_period_with_services():
    response = {
        "ResultsByTime": [
            {
                "TimePeriod": {"Start": "2026-06-23", "End": "2026-07-23"},
                "Groups": [
                    {"Keys": ["Amazon Elastic Compute Cloud"], "Metrics": {"UnblendedCost": {"Amount": "12.34", "Unit": "USD"}}},
                    {"Keys": ["Amazon EKS"], "Metrics": {"UnblendedCost": {"Amount": "3.21", "Unit": "USD"}}},
                ],
                "Estimated": False,
            }
        ]
    }

    report = format_report(response, "2026-06-23", "2026-07-23")

    assert "Amazon Elastic Compute Cloud" in report
    assert "$     12.34" in report
    assert "Grand total: $15.55" in report


def test_sorts_services_by_cost_descending():
    response = {
        "ResultsByTime": [
            {
                "TimePeriod": {"Start": "2026-06-23", "End": "2026-07-23"},
                "Groups": [
                    {"Keys": ["Cheap Service"], "Metrics": {"UnblendedCost": {"Amount": "1.00", "Unit": "USD"}}},
                    {"Keys": ["Expensive Service"], "Metrics": {"UnblendedCost": {"Amount": "99.00", "Unit": "USD"}}},
                ],
            }
        ]
    }

    report = format_report(response, "2026-06-23", "2026-07-23")

    assert report.index("Expensive Service") < report.index("Cheap Service")


def test_filters_out_subcent_noise():
    # Real accounts report things like -0.000000005 for rounding/credits
    # on services that were never actually used — see the live query this
    # was modeled on. These shouldn't clutter a report meant to answer
    # "is anything actually costing money."
    response = {
        "ResultsByTime": [
            {
                "TimePeriod": {"Start": "2026-06-23", "End": "2026-07-23"},
                "Groups": [
                    {"Keys": ["AWS Data Transfer"], "Metrics": {"UnblendedCost": {"Amount": "-0.000000005", "Unit": "USD"}}},
                    {"Keys": ["Real Cost"], "Metrics": {"UnblendedCost": {"Amount": "5.00", "Unit": "USD"}}},
                ],
            }
        ]
    }

    report = format_report(response, "2026-06-23", "2026-07-23")

    assert "AWS Data Transfer" not in report
    assert "Real Cost" in report


def test_no_billable_services_reports_zero_total():
    response = {
        "ResultsByTime": [
            {"TimePeriod": {"Start": "2026-06-23", "End": "2026-07-23"}, "Groups": []}
        ]
    }

    report = format_report(response, "2026-06-23", "2026-07-23")

    assert "no billable services this period" in report
    assert "Grand total: $0.00" in report


def test_multiple_periods_sum_into_grand_total():
    response = {
        "ResultsByTime": [
            {
                "TimePeriod": {"Start": "2026-05-23", "End": "2026-06-23"},
                "Groups": [{"Keys": ["S"], "Metrics": {"UnblendedCost": {"Amount": "10.00", "Unit": "USD"}}}],
            },
            {
                "TimePeriod": {"Start": "2026-06-23", "End": "2026-07-23"},
                "Groups": [{"Keys": ["S"], "Metrics": {"UnblendedCost": {"Amount": "20.00", "Unit": "USD"}}}],
            },
        ]
    }

    report = format_report(response, "2026-05-23", "2026-07-23")

    assert "Grand total: $30.00" in report
