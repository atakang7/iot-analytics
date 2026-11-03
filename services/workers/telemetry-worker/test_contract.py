"""Contract cases shared by the public API and each telemetry consumer."""
import pytest

from common.models import Telemetry


def make_reading(**changes):
    data = {
        "deviceId": "motor-1",
        "deviceType": "motor",
        "sensorId": "temperature-1",
        "sensorType": "temperature",
        "timestamp": "2026-11-03T10:00:00Z",
        "unit": "celsius",
        "value": {"value": 2.0},
    }
    data.update(changes)
    return data


@pytest.mark.parametrize("value", [
    {"value": "9"}, {"value": True}, {"value": None},
    {"value": float("nan")}, {"value": float("inf")},
    {"other": 9},
])
def test_rejects_non_numeric_scalar_value(value):
    with pytest.raises(ValueError):
        Telemetry.from_dict(make_reading(value=value))


@pytest.mark.parametrize("value", [
    {"x": "1.0"}, {"x": False}, {"x": float("nan")},
    {"x": float("inf")}, {"comment": "missing axes"},
])
def test_rejects_invalid_vibration(value):
    with pytest.raises(ValueError):
        Telemetry.from_dict(make_reading(sensorType="vibration", value=value))


def test_partial_vibration_preserves_missing_axis_zero():
    reading = Telemetry.from_dict(make_reading(
        sensorType="vibration", value={"x": 3.0, "y": 4.0},
    ))
    assert reading.vibration_rms() == 5.0


def test_scalar_zero_and_offset_timestamp_are_valid():
    reading = Telemetry.from_dict(make_reading(
        timestamp="2026-11-03T13:00:00+03:00",
        value={"value": 0},
    ))
    assert reading.scalar_value() == 0.0
    assert reading.timestamp.utcoffset().total_seconds() == 3 * 3600


@pytest.mark.parametrize("change", [
    {"deviceId": ""}, {"deviceId": "x" * 129},
    {"sensorId": 100}, {"sensorType": None},
    {"deviceType": " "}, {"unit": ""}, {"unit": "x" * 65},
    {"timestamp": "2026-11-03T10:00:00"},
    {"value": []}, {"value": {}},
])
def test_rejects_malformed_envelope(change):
    with pytest.raises(ValueError):
        Telemetry.from_dict(make_reading(**change))


def test_boolean_is_not_numeric():
    with pytest.raises(ValueError):
        Telemetry.from_dict(make_reading(value={"value": False}))
