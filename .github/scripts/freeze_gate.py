"""Decides whether a production change may run now, from the harvest calendar.

No production change runs from blocked_from until blocked_until, local time, on a day inside a
harvest week of any department. An approved incident lets the change run and is recorded.

usage: freeze_gate.py CALENDAR [--now ISO8601] [--incident REASON]
Exit status 0 allows the change and 1 blocks it.
"""

import argparse
import json
import sys
from datetime import date, datetime, time
from zoneinfo import ZoneInfo


def load(path):
    with open(path, encoding="utf-8") as handle:
        calendar = json.load(handle)
    weeks = []
    for week in calendar["harvest_weeks"]:
        start, end = date.fromisoformat(week["start"]), date.fromisoformat(week["end"])
        if end < start:
            raise ValueError(f"harvest week of {week['department']} ends before it starts")
        weeks.append({"department": week["department"], "start": start, "end": end})
    return {
        "zone": ZoneInfo(calendar["timezone"]),
        "blocked_from": time.fromisoformat(calendar["blocked_from"]),
        "blocked_until": time.fromisoformat(calendar["blocked_until"]),
        "weeks": weeks,
    }


def decide(calendar, now, incident=""):
    """Returns (allowed, message) for an aware datetime."""
    local = now.astimezone(calendar["zone"])
    departments = [w["department"] for w in calendar["weeks"] if w["start"] <= local.date() <= w["end"]]
    in_hours = calendar["blocked_from"] <= local.time().replace(tzinfo=None) < calendar["blocked_until"]
    stamp = local.strftime("%Y-%m-%d %H:%M %Z")
    if not departments or not in_hours:
        return True, f"{stamp} is outside the harvest freeze."
    window = f"{calendar['blocked_from']:%H:%M} to {calendar['blocked_until']:%H:%M}"
    who = ", ".join(sorted(set(departments)))
    if incident.strip():
        return True, f"{stamp} is inside the harvest freeze of {who}, {window}. Allowed as an approved incident: {incident.strip()}"
    return False, f"{stamp} is inside the harvest freeze of {who}, {window}. Run again after the window or as an approved incident."


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("calendar")
    parser.add_argument("--now", help="moment to check, ISO 8601 with offset, defaults to the current time")
    parser.add_argument("--incident", default="", help="reason of an approved incident")
    args = parser.parse_args()
    now = datetime.fromisoformat(args.now) if args.now else datetime.now().astimezone()
    if now.tzinfo is None:
        parser.error("--now needs an offset, such as 2026-11-11T05:00:00-05:00")
    allowed, message = decide(load(args.calendar), now, args.incident)
    print(message)
    return 0 if allowed else 1


if __name__ == "__main__":
    sys.exit(main())
