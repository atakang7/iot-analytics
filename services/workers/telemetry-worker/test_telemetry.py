import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(__file__) + "/..")
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
        assert '"value": 5.5' in row["value"]  # JSON string

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
        assert t.vibration_rms() == 5.0  # 3-4-5 triangle

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