from dataclasses import dataclass
from datetime import datetime
from typing import Optional
import json


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
        return cls(
            device_id=data["deviceId"],
            device_type=data["deviceType"],
            sensor_id=data["sensorId"],
            sensor_type=data["sensorType"],
            timestamp=datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00")),
            unit=data["unit"],
            value=data["value"],
        )

    def scalar_value(self) -> Optional[float]:
        """Extract scalar value from value dict."""
        if "value" in self.value:
            return float(self.value["value"])
        return None

    def vibration_rms(self) -> Optional[float]:
        """Calculate RMS for vibration sensor."""
        if self.sensor_type != "vibration":
            return None
        x = self.value.get("x", 0)
        y = self.value.get("y", 0)
        z = self.value.get("z", 0)
        return (x**2 + y**2 + z**2) ** 0.5

    def to_db_row(self) -> dict:
        return {
            "time": self.timestamp,
            "device_id": self.device_id,
            "device_type": self.device_type,
            "sensor_id": self.sensor_id,
            "sensor_type": self.sensor_type,
            "unit": self.unit,
            "value": json.dumps(self.value),
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
    created_at: datetime = None

    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.utcnow()

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
        """Returns (alert_type, severity) or None."""
        if self.critical_high and value > self.critical_high:
            return ("threshold_breach", "critical")
        if self.critical_low and value < self.critical_low:
            return ("threshold_breach", "critical")
        if self.warning_high and value > self.warning_high:
            return ("threshold_breach", "warning")
        if self.warning_low and value < self.warning_low:
            return ("threshold_breach", "warning")
        return None
