"""Broker metadata must survive decoding so bad events can be quarantined."""
import base64
import json
from types import SimpleNamespace

import pytest

import common.kafka as transport
from common.quarantine import quarantine_invalid


def record(raw=b'{"deviceId":"motor-1"}'):
    return SimpleNamespace(
        topic="iot.telemetry", partition=1, offset=9,
        key=b"motor-1", value=raw,
    )


def test_consumer_preserves_raw_message_and_offset(monkeypatch):
    message = record(b'{"deviceId":"motor-1"}')

    class Stub:
        def __init__(self, *_topics, **options):
            assert options["enable_auto_commit"] is False
            assert options["value_deserializer"] is None

        def poll(self, **_options):
            return {"partition": [message]}

    monkeypatch.setattr(transport, "_KafkaConsumer", Stub)
    consumer = transport.KafkaConsumer("iot.telemetry", group_id="telemetry-worker")
    assert consumer.poll_raw()[0] is message
    assert transport.decode_record(message) == {"deviceId": "motor-1"}


def test_malformed_json_is_detected_before_any_side_effect():
    with pytest.raises(ValueError):
        transport.decode_record(record(b"{unparseable"))


def test_quarantine_publish_contains_raw_bytes_and_stable_coordinates():
    sent = []

    class Producer:
        def send(self, topic, value, key):
            sent.append((topic, value, key))

    quarantine_invalid(Producer(), record(b"{malformed"), "telemetry-worker",
                       reason="invalid_json")
    topic, value, key = sent[0]
    assert topic == "iot.quarantine"
    assert key == "telemetry-worker:iot.telemetry:1:9"
    assert value["sourceTopic"] == "iot.telemetry"
    assert value["sourcePartition"] == 1
    assert value["sourceOffset"] == 9
    assert base64.b64decode(value["payloadBase64"]) == b"{malformed"
    assert value["reason"] == "invalid_json"
    assert "error" not in value
    assert len(sent) == 1


def test_failed_quarantine_publish_must_not_be_acknowledged():
    class Producer:
        def send(self, *_args, **_kwargs):
            raise OSError("quarantine broker unavailable")

    with pytest.raises(OSError):
        quarantine_invalid(Producer(), record(b"bad"), "telemetry-worker",
                           reason="invalid_json")
