"""Stream consumer must isolate input errors without hiding broker errors."""
import json
from types import SimpleNamespace

import pytest

from main import process_record


def record(payload):
    return SimpleNamespace(
        topic="iot.telemetry", partition=2, offset=11,
        key=b"motor-1", value=payload,
    )


class Consumer:
    def __init__(self, events):
        self.events = events

    def commit(self):
        self.events.append("commit")


class Processor:
    def __init__(self, events, fail=False):
        self.events = events
        self.fail = fail
        self.producer = self

    def send(self, topic, value, key):
        self.events.append(("quarantine", topic, value["reason"]))
        if self.fail:
            raise OSError("broker unavailable")

    def process(self, telemetry):
        self.events.append(("process", telemetry.device_id))


def test_invalid_json_moves_to_quarantine_before_commit():
    events = []
    assert process_record(record(b"{broken"), Consumer(events), Processor(events)) is False
    assert events == [("quarantine", "iot.quarantine", "invalid_json"), "commit"]


def test_quarantine_publish_error_preserves_source_offset():
    events = []
    with pytest.raises(OSError):
        process_record(record(b"{broken"), Consumer(events), Processor(events, fail=True))
    assert events == [("quarantine", "iot.quarantine", "invalid_json")]


def test_valid_reading_commits_after_alert_processing():
    raw = json.dumps({
        "deviceId": "motor-1", "deviceType": "motor",
        "sensorId": "temp-1", "sensorType": "temperature",
        "timestamp": "2026-11-03T10:00:00Z",
        "unit": "celsius", "value": {"value": 10.0},
    }).encode()
    events = []
    assert process_record(record(raw), Consumer(events), Processor(events)) is True
    assert events == [("process", "motor-1"), "commit"]
