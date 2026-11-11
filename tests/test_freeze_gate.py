"""Boundary tests of the harvest freeze gate. Run with python3 -m unittest discover tests."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".github", "scripts"))
import freeze_gate  # noqa: E402

CALENDAR = {
    "timezone": "America/Bogota",
    "blocked_from": "05:00",
    "blocked_until": "18:00",
    "harvest_weeks": [
        {"department": "cauca", "start": "2026-11-09", "end": "2026-11-15"},
        {"department": "huila", "start": "2026-11-15", "end": "2026-11-21"},
    ],
}


def at(text):
    return datetime.fromisoformat(text)


class FreezeGateTest(unittest.TestCase):
    def setUp(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
        json.dump(CALENDAR, handle)
        handle.close()
        self.path = handle.name
        self.calendar = freeze_gate.load(self.path)

    def tearDown(self):
        os.unlink(self.path)

    def allowed(self, moment, incident=""):
        return freeze_gate.decide(self.calendar, at(moment), incident)[0]

    def test_hour_boundaries_inside_a_harvest_week(self):
        self.assertTrue(self.allowed("2026-11-11T04:59:59-05:00"))
        self.assertFalse(self.allowed("2026-11-11T05:00:00-05:00"))
        self.assertFalse(self.allowed("2026-11-11T17:59:59-05:00"))
        self.assertTrue(self.allowed("2026-11-11T18:00:00-05:00"))

    def test_week_boundaries(self):
        self.assertTrue(self.allowed("2026-11-08T12:00:00-05:00"))
        self.assertFalse(self.allowed("2026-11-09T12:00:00-05:00"))
        self.assertFalse(self.allowed("2026-11-21T12:00:00-05:00"))
        self.assertTrue(self.allowed("2026-11-22T12:00:00-05:00"))

    def test_overlapping_weeks_name_both_departments(self):
        allowed, message = freeze_gate.decide(self.calendar, at("2026-11-15T09:00:00-05:00"))
        self.assertFalse(allowed)
        self.assertIn("cauca, huila", message)

    def test_utc_time_is_read_in_bogota(self):
        # 10:00 UTC is 05:00 in Bogota, and 23:00 UTC is 18:00.
        self.assertFalse(self.allowed("2026-11-11T10:00:00+00:00"))
        self.assertTrue(self.allowed("2026-11-11T09:59:00+00:00"))
        self.assertTrue(self.allowed("2026-11-11T23:00:00+00:00"))
        # 02:00 UTC on the 9th is still the 8th in Bogota, before the week starts.
        self.assertTrue(self.allowed("2026-11-09T02:00:00+00:00"))

    def test_incident_allows_and_records_the_reason(self):
        allowed, message = freeze_gate.decide(self.calendar, at("2026-11-11T09:00:00-05:00"), "ingestion down")
        self.assertTrue(allowed)
        self.assertIn("approved incident: ingestion down", message)
        self.assertFalse(self.allowed("2026-11-11T09:00:00-05:00", "   "))

    def test_empty_calendar_blocks_nothing(self):
        empty = dict(CALENDAR, harvest_weeks=[])
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(empty, handle)
        try:
            calendar = freeze_gate.load(handle.name)
            self.assertTrue(freeze_gate.decide(calendar, at("2026-11-11T09:00:00-05:00"))[0])
        finally:
            os.unlink(handle.name)

    def test_rejects_a_week_that_ends_before_it_starts(self):
        broken = dict(CALENDAR, harvest_weeks=[{"department": "tolima", "start": "2026-11-10", "end": "2026-11-09"}])
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as handle:
            json.dump(broken, handle)
        try:
            with self.assertRaises(ValueError):
                freeze_gate.load(handle.name)
        finally:
            os.unlink(handle.name)

    def test_command_exit_status(self):
        script = os.path.join(os.path.dirname(__file__), "..", ".github", "scripts", "freeze_gate.py")
        blocked = subprocess.run([sys.executable, script, self.path, "--now", "2026-11-11T09:00:00-05:00"], capture_output=True, text=True)
        free = subprocess.run([sys.executable, script, self.path, "--now", "2026-11-11T19:00:00-05:00"], capture_output=True, text=True)
        self.assertEqual(blocked.returncode, 1)
        self.assertEqual(free.returncode, 0)

    def test_committed_calendar_loads(self):
        path = os.path.join(os.path.dirname(__file__), "..", "config", "harvest-calendar.json")
        calendar = freeze_gate.load(path)
        self.assertEqual(str(calendar["zone"]), "America/Bogota")
        self.assertEqual((calendar["blocked_from"].hour, calendar["blocked_until"].hour), (5, 18))


if __name__ == "__main__":
    unittest.main()
