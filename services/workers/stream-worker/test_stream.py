import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(__file__) + "/..")
from common.models import Threshold
import sys
sys.path.insert(0, "..")

from common.models import Threshold


class TestThresholdCheck:
    def test_critical_high_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(45)
        assert result == ("threshold_breach", "critical")

    # stream-worker/test_main.py - change critical_low to non-zero
    def test_critical_low_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=5, critical_high=40  # changed from 0 to 5
        )
        result = t.check(-5)
        assert result == ("threshold_breach", "critical")

    def test_warning_high_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(35)
        assert result == ("threshold_breach", "warning")

    def test_warning_low_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(5)
        assert result == ("threshold_breach", "warning")

    def test_no_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(20)
        assert result is None

    def test_partial_thresholds(self):
        t = Threshold(
            sensor_type="humidity",
            device_type=None,
            warning_low=None, warning_high=80,
            critical_low=None, critical_high=95
        )
        assert t.check(50) is None
        assert t.check(85) == ("threshold_breach", "warning")
        assert t.check(98) == ("threshold_breach", "critical")

    def test_boundary_values(self):
        t = Threshold(
            sensor_type="pressure",
            device_type="pump",
            warning_low=20, warning_high=80,
            critical_low=10, critical_high=90
        )
        # Exactly at threshold - no breach (uses >)
        assert t.check(80) is None
        assert t.check(80.1) == ("threshold_breach", "warning")

def test_zero_is_a_valid_critical_boundary():
    threshold = Threshold(
        sensor_type="temperature", device_type=None,
        warning_low=5.0, warning_high=70.0,
        critical_low=0.0, critical_high=85.0,
    )
    assert threshold.check(-0.5) == ("threshold_breach", "critical")
    assert threshold.check(2.0) == ("threshold_breach", "warning")


def test_alert_id_is_stable_across_replays(monkeypatch):
    import main
    from common.models import Telemetry

    class Producer:
        messages = []

        def send(self, topic, value, key):
            self.messages.append(value)

        def close(self):
            pass

    producer = Producer()
    monkeypatch.setattr(main, "KafkaProducer", lambda: producer)
    processor = main.StreamProcessor()
    reading = Telemetry.from_dict({
        "deviceId": "d1", "deviceType": "motor", "sensorId": "temp-1",
        "sensorType": "temperature", "timestamp": "2026-11-03T10:30:00Z",
        "unit": "celsius", "value": {"value": 90.0},
    })
    processor.emit_alert(reading, "threshold_breach", "critical", "over", 90.0, 85.0)
    processor.emit_alert(reading, "threshold_breach", "critical", "over", 90.0, 85.0)
    assert producer.messages[0]["alertId"] == producer.messages[1]["alertId"]


def test_kafka_consumer_waits_on_idle_topic(monkeypatch):
    import common.kafka as transport

    captured = {}

    class StubConsumer:
        def __init__(self, *topics, **options):
            captured.update(options)

    monkeypatch.setattr(transport, "_KafkaConsumer", StubConsumer)
    transport.KafkaConsumer("iot.telemetry", group_id="stream-worker")

    assert captured["enable_auto_commit"] is False
    # A zero consumer timeout exits an idle stream and causes a restart storm.
    assert "consumer_timeout_ms" not in captured


def test_kafka_producer_bounds_broker_wait(monkeypatch):
    import common.kafka as transport

    options = {}

    class StubProducer:
        def __init__(self, **kwargs):
            options.update(kwargs)

    monkeypatch.setattr(transport, "_KafkaProducer", StubProducer)
    transport.KafkaProducer()

    assert options["acks"] == "all"
    assert options["max_block_ms"] == 15000
    assert options["request_timeout_ms"] == 10000
