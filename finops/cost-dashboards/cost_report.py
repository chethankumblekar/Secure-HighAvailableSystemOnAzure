#!/usr/bin/env python3
"""Real AWS Cost Explorer spend report, grouped by service, over a given
date range (default: last 30 days). Complements orphan_cleanup.py: that
finds resources that shouldn't be running; this shows what they'd have
cost (or did cost) if they had been.

Cost Explorer's `GroupBy: TAG` requires the tag to be activated as a cost
allocation tag in the Billing console first (a manual, one-time step, and
even then there's up to a 24h delay before it appears) — so this groups
by SERVICE, which needs no activation and works immediately on any
account. Fetching (`fetch_cost_and_usage`) and formatting
(`format_report`) are split on purpose: the AWS call can't be
meaningfully unit-tested (moto doesn't simulate real billing data — see
test_cost_report.py), but the formatting logic that turns Cost
Explorer's response shape into a report can be, and is.
"""
from __future__ import annotations

import argparse
import datetime
import sys

import boto3


def fetch_cost_and_usage(session: boto3.Session, start: str, end: str) -> dict:
    # Cost Explorer is a global (us-east-1) endpoint regardless of which
    # region resources actually run in.
    ce = session.client("ce", region_name="us-east-1")
    return ce.get_cost_and_usage(
        TimePeriod={"Start": start, "End": end},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )


def format_report(response: dict, start: str, end: str) -> str:
    lines = [f"AWS spend, {start} to {end} (UnblendedCost, USD)", ""]
    grand_total = 0.0

    for period in response.get("ResultsByTime", []):
        period_start = period["TimePeriod"]["Start"]
        period_end = period["TimePeriod"]["End"]
        rows = [
            (g["Keys"][0], float(g["Metrics"]["UnblendedCost"]["Amount"]))
            for g in period.get("Groups", [])
        ]
        # Sub-cent noise (data transfer credits etc.) isn't worth a line.
        rows = [(name, amount) for name, amount in rows if abs(amount) >= 0.01]
        rows.sort(key=lambda r: r[1], reverse=True)
        period_total = sum(amount for _, amount in rows)
        grand_total += period_total

        lines.append(f"{period_start} .. {period_end}:")
        if not rows:
            lines.append("  (no billable services this period)")
        for name, amount in rows:
            lines.append(f"  {name:<40} ${amount:>10.2f}")
        lines.append(f"  {'TOTAL':<40} ${period_total:>10.2f}")
        lines.append("")

    lines.append(f"Grand total: ${grand_total:.2f}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=30, help="how many days back to report (default: 30)")
    parser.add_argument("--region", default=None, help="AWS region for the session (Cost Explorer itself is global)")
    args = parser.parse_args(argv)

    end = datetime.date.today()
    start = end - datetime.timedelta(days=args.days)

    session = boto3.Session(region_name=args.region)
    response = fetch_cost_and_usage(session, start.isoformat(), end.isoformat())
    print(format_report(response, start.isoformat(), end.isoformat()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
