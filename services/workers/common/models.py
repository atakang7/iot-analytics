"""Wire-level contracts shared by telemetry and alert workers."""
import json
import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional


def _finite_number(value):
    number = float(value)
    if not math.isfinite(number):
        raise ValueError("Sensor readings must be finite numbers")
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
        timestamp = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
        if timestamp.tzinfo is None:
            raise ValueError("timestamp must specify a UTC offset")
        if not isinstance(data["value"], dict):
            raise ValueError("value must be a JSON object")
        identifiers = (data["deviceId"], data["deviceType"], data["sensorId"], data["sensorType"])
        if any(not isinstance(v, str) or not v.strip() for v in identifiers):
            raise ValueError("device and sensor identifiers must be non-empty strings")
        return cls(
            device_id=data["deviceId"],
            device_type=data["deviceType"],
            sensor_id=data["sensorId"],
            sensor_type=data["sensorType"],
            timestamp=timestamp,
            unit=data["unit"],
            value=data["value"],
        )

    def scalar_value(self) -> Optional[float]:
        return _finite_number(self.value["value"]) if "value" in self.value else None

    def vibration_rms(self) -> Optional[float]:
        if self.sensor_type != "vibration":
            return None
        x, y, z = (_finite_number(self.value.get(axis, 0)) for axis in ("x", "y", "z"))
        return math.sqrt(x * x + y * y + z * z)

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
