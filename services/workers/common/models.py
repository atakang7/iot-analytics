"""Wire-level contracts shared by telemetry and alert workers."""
import json
import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


def _finite_number(value):
    # Python's bool is an int, but true/false are not sensor measurements.
    if isinstance(value, bool) or not isinstance(value, (float, int)):
        raise ValueError("Sensor readings must be JSON numbers")
    try:
        number = float(value)
    except (OverflowError, ValueError) as exc:
        raise ValueError("Sensor reading is outside numeric range") from exc
    if not math.isfinite(number):
        raise ValueError("Sensor readings must be finite")
    return number


@dataclass
class Telemetry:
    device_id: str
    device_type: str
    sensor_id: str
    sensor_type: str
    timestamp: datetime
    unit: str
    value: dict

    @classmethod
    def from_dict(cls, data: dict) -> "Telemetry":
        if not isinstance(data, dict):
            raise ValueError("Telemetry must be an object")
        fields = ("deviceId", "deviceType", "sensorId", "sensorType")
        if any(
            not isinstance(data.get(field), str)
            or not 0 < len(data[field].strip()) <= 128
            for field in fields
        ):
            raise ValueError("Device and sensor fields must have 1 to 128 characters")
        unit = data.get("unit")
        if not isinstance(unit, str) or not 0 < len(unit.strip()) <= 64:
            raise ValueError("Unit must have 1 to 64 characters")
        raw_time = data.get("timestamp")
        if not isinstance(raw_time, str):
            raise ValueError("Timestamp must be an ISO 8601 string")
        try:
            timestamp = datetime.fromisoformat(raw_time.replace("Z", "+00:00"))
        except ValueError as exc:
            raise ValueError("Timestamp is not ISO 8601") from exc
        if timestamp.tzinfo is None:
            raise ValueError("Timestamp must specify a UTC offset")
        payload = data.get("value")
        if not isinstance(payload, dict) or not payload:
            raise ValueError("Measurement must be a nonempty JSON object")
        if data["sensorType"] == "vibration":
            axes = [payload[axis] for axis in ("x", "y", "z") if axis in payload]
            if not axes:
                raise ValueError("Vibration requires at least one axis")
            for axis in axes:
                _finite_number(axis)
        else:
            _finite_number(payload.get("value"))
        return cls(
            device_id=data["deviceId"],
            device_type=data["deviceType"],
            sensor_id=data["sensorId"],
            sensor_type=data["sensorType"],
            timestamp=timestamp,
            unit=unit,
            value=payload,
        )

    def scalar_value(self) -> Optional[float]:
        return _finite_number(self.value["value"]) if "value" in self.value else None

    def vibration_rms(self) -> Optional[float]:
        if self.sensor_type != "vibration":
            return None
        result = math.hypot(
            *(_finite_number(self.value.get(axis, 0)) for axis in ("x", "y", "z"))
        )
        if not math.isfinite(result):
            raise ValueError("Vibration magnitude must be finite")
        return result

    def to_db_row(self) -> dict:
        return {
            "time": self.timestamp,
            "device_id": self.device_id,
            "device_type": self.device_type,
            "sensor_id": self.sensor_id,
            "sensor_type": self.sensor_type,
            "unit": self.unit,
            "value": json.dumps(self.value, allow_nan=False),
        }


@dataclass
class Alert:
    alert_id: str
    device_id: str
    device_type: str
    alert_type: str
    severity: str
    message: str
    threshold: Optional[float] = None
    value: Optional[float] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "alertId": self.alert_id,
            "deviceId": self.device_id,
            "deviceType": self.device_type,
            "alertType": self.alert_type,
            "severity": self.severity,
            "message": self.message,
            "threshold": self.threshold,
            "value": self.value,
            "createdAt": self.created_at.isoformat(),
        }

    def to_db_row(self) -> dict:
        return {
            "created_at": self.created_at,
            "alert_id": self.alert_id,
            "device_id": self.device_id,
            "device_type": self.device_type,
            "alert_type": self.alert_type,
            "severity": self.severity,
            "message": self.message,
            "threshold": self.threshold,
            "value": self.value,
        }


@dataclass
class Threshold:
    sensor_type: str
    device_type: Optional[str]
    warning_low: Optional[float]
    warning_high: Optional[float]
    critical_low: Optional[float]
    critical_high: Optional[float]

    def check(self, value: float) -> Optional[tuple[str, str]]:
        if ((self.critical_high is not None and value > self.critical_high)
                or (self.critical_low is not None and value < self.critical_low)):
            return ("threshold_breach", "critical")
        if ((self.warning_high is not None and value > self.warning_high)
                or (self.warning_low is not None and value < self.warning_low)):
            return ("threshold_breach", "warning")
        return None
