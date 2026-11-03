"""Quarantine acknowledgment must precede the source offset commit."""
import json
from types import SimpleNamespace

import pytest

from main import process_batch


def record(value, offset):
    return SimpleNamespace(
        topic="iot.telemetry", partition=0, offset=offset, key=b"motor-1", value=value,
    )


GOOD = json.dumps({
    "deviceId": "motor-1", "deviceType": "motor",
    "sensorId": "temp-1", "sensorType": "temperature",
    "timestamp": "2026-11-03T10:00:00Z",
    "unit": "celsius", "value": {"value": 80.0},
}).encode()


class Consumer:
    def __init__(self, trace):
        self.trace = trace

    def commit(self):
        self.trace.append("commit")


class Producer:
    def __init__(self, trace, fail=False):
        self.trace = trace
        self.fail = fail

    def send(self, topic, value, key):
        self.trace.append(("quarantine", topic, value["sourceOffset"]))
        if self.fail:
            raise OSError("quarantine broker is down")


def test_batch_persists_valid_rows_and_quarantines_invalid_before_commit():
    trace = []

    def persist(rows):
        assert len(rows) == 1
        assert rows[0]["device_id"] == "motor-1"
        trace.append("database")
        return 1

    result = process_batch(
        [record(GOOD, 4), record(b"{invalid", 5)],
        Consumer(trace), Producer(trace), persist=persist,
    )
    assert result == (1, 1, 1)
    assert trace == ["database", ("quarantine", "iot.quarantine", 5), "commit"]


def test_quarantine_failure_does_not_commit_source_offset():
    trace = []
    with pytest.raises(OSError):
        process_batch(
            [record(b"{invalid", 7)], Consumer(trace),
            Producer(trace, fail=True), persist=lambda rows: 0,
        )
    assert trace == [("quarantine", "iot.quarantine", 7)]


def test_database_failure_does_not_commit_or_quarantine():
    trace = []

    def down(_rows):
        trace.append("database")
        raise OSError("database unavailable")

    with pytest.raises(OSError):
        process_batch(
            [record(GOOD, 9)], Consumer(trace), Producer(trace), persist=down,
        )
    assert trace == ["database"]
