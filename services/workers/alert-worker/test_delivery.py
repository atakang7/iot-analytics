"""An invalid alert must be copied durably before its offset is committed."""
import json
from types import SimpleNamespace

import pytest

from main import process_record


def record(value):
    return SimpleNamespace(
        topic="iot.alerts", partition=0, offset=5,
        key=b"motor-1", value=value,
    )


class Consumer:
    def __init__(self, calls):
        self.calls = calls

    def commit(self):
        self.calls.append("commit")


class Producer:
    def __init__(self, calls, fail=False):
        self.calls = calls
        self.fail = fail

    def send(self, topic, value, key):
        self.calls.append(("quarantine", topic, value["reason"]))
        if self.fail:
            raise OSError("broker not available")


VALID = json.dumps({
    "alertId": "test-alert-1",
    "createdAt": "2026-11-03T10:00:00Z",
    "deviceId": "motor-1",
    "deviceType": "motor",
    "alertType": "threshold_breach",
    "severity": "critical",
    "message": "over limit",
    "value": 90.0,
}).encode()


def test_valid_alert_is_persisted_before_offset_commit():
    events = []

    def persist(table, row, conflict_cols):
        assert table == "alerts"
        assert conflict_cols == ["alert_id"]
        assert row["alert_id"] == "test-alert-1"
        events.append("database")

    assert process_record(record(VALID), Consumer(events), Producer(events),
                          persist=persist) is True
    assert events == ["database", "commit"]


def test_invalid_json_is_quarantined_before_commit():
    events = []
    assert process_record(record(b"{invalid"), Consumer(events), Producer(events),
                          persist=lambda *_args, **_kwargs: None) is False
    assert events == [("quarantine", "iot.quarantine", "invalid_json"), "commit"]


def test_invalid_alert_is_quarantined_before_commit():
    events = []
    assert process_record(record(b'{"createdAt":"2026-11-03T10:00:00Z"}'),
                          Consumer(events), Producer(events),
                          persist=lambda *_args, **_kwargs: None) is False
    assert events == [("quarantine", "iot.quarantine", "invalid_alert"), "commit"]


def test_failed_quarantine_never_commits():
    events = []
    with pytest.raises(OSError):
        process_record(record(b"{bad"), Consumer(events), Producer(events, fail=True),
                       persist=lambda *_args, **_kwargs: None)
    assert events == [("quarantine", "iot.quarantine", "invalid_json")]
