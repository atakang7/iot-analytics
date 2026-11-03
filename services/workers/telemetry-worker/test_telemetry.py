import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from common.models import Telemetry


class TestTelemetryParsing:
    def test_from_dict(self):
        data = {
            "deviceId": "device-001",
            "deviceType": "hvac",
            "sensorId": "temp-01",
            "sensorType": "temperature",
            "timestamp": "2024-01-15T10:30:00Z",
            "unit": "celsius",
            "value": {"value": 25.5}
        }
        t = Telemetry.from_dict(data)
        
        assert t.device_id == "device-001"
        assert t.device_type == "hvac"
        assert t.sensor_id == "temp-01"
        assert t.sensor_type == "temperature"
        assert t.unit == "celsius"
        assert t.value == {"value": 25.5}

    def test_scalar_value(self):
        data = {
            "deviceId": "d1",
            "deviceType": "hvac",
            "sensorId": "s1",
            "sensorType": "temperature",
            "timestamp": "2024-01-15T10:30:00Z",
            "unit": "celsius",
            "value": {"value": 42.0}
        }
        t = Telemetry.from_dict(data)
        assert t.scalar_value() == 42.0

    def test_scalar_value_missing(self):
        data = {
            "deviceId": "d1",
            "deviceType": "motor",
            "sensorId": "vib-01",
            "sensorType": "vibration",
            "timestamp": "2024-01-15T10:30:00Z",
            "unit": "g",
            "value": {"x": 1, "y": 2, "z": 3}
        }
        t = Telemetry.from_dict(data)
        assert t.scalar_value() is None

    def test_to_db_row(self):
        data = {
            "deviceId": "device-001",
            "deviceType": "pump",
            "sensorId": "pressure-01",
            "sensorType": "pressure",
            "timestamp": "2024-06-20T14:45:30Z",
            "unit": "bar",
            "value": {"value": 5.5}
        }
        t = Telemetry.from_dict(data)
        row = t.to_db_row()
        
        assert row["device_id"] == "device-001"
        assert row["device_type"] == "pump"
        assert row["sensor_id"] == "pressure-01"
        assert row["sensor_type"] == "pressure"
        assert row["unit"] == "bar"
        assert '"value": 5.5' in row["value"]

    def test_vibration_rms(self):
        data = {
            "deviceId": "d1",
            "deviceType": "motor",
            "sensorId": "vib-01",
            "sensorType": "vibration",
            "timestamp": "2024-01-15T10:30:00Z",
            "unit": "g",
            "value": {"x": 3, "y": 4, "z": 0}
        }
        t = Telemetry.from_dict(data)
        assert t.vibration_rms() == 5.0

    def test_vibration_rms_wrong_type(self):
        data = {
            "deviceId": "d1",
            "deviceType": "hvac",
            "sensorId": "s1",
            "sensorType": "temperature",
            "timestamp": "2024-01-15T10:30:00Z",
            "unit": "celsius",
            "value": {"value": 25}
        }
        t = Telemetry.from_dict(data)
        assert t.vibration_rms() is None

def test_flush_batch_commits_after_insert(monkeypatch):
    import main

    class Cursor:
        def __enter__(self):
            return self

        def __exit__(self, *_):
            pass

    class Connection:
        commits = 0
        rollbacks = 0
        closed = False

        def cursor(self):
            return Cursor()

        def commit(self):
            self.commits += 1

        def rollback(self):
            self.rollbacks += 1

        def close(self):
            self.closed = True

    conn = Connection()
    monkeypatch.setattr(main, "get_connection", lambda: conn)
    calls = []

    def insert(cursor, statement, rows, fetch):
        calls.append((statement, rows, fetch))
        return [("motor",)]

    monkeypatch.setattr(main, "execute_values", insert)
    inserted = main.flush_batch([{
        "time": "2026-11-03T00:00:00Z",
        "device_id": "d1", "device_type": "motor", "sensor_id": "s1",
        "sensor_type": "temperature", "unit": "celsius", "value": '{"value": 9}',
    }])
    assert inserted == 1
    assert conn.commits == 1 and conn.rollbacks == 0 and conn.closed
    assert "ON CONFLICT (device_id, sensor_id, time) DO NOTHING" in calls[0][0]


def test_log_level_comes_from_environment(monkeypatch):
    import logging
    import common.logger as worker_logging

    monkeypatch.setattr(worker_logging, "LOG_LEVEL", "WARNING")
    assert worker_logging.get_logger("iot-test-log-level").level == logging.WARNING
