#!/usr/bin/env python3
"""
Stream Worker
Kafka: iot.telemetry → threshold checks → Kafka: iot.alerts

Alerts:
1. Threshold breach - value exceeds configured limits
2. Rate of change - value changing too fast
3. Stuck sensor - same value repeated N times
"""
import sys
sys.path.insert(0, "/app")
 
import uuid
from collections import defaultdict, deque

from common.config import KAFKA_TELEMETRY_TOPIC, KAFKA_ALERTS_TOPIC
from common.kafka import KafkaConsumer, KafkaProducer
from common.db import query
from common.models import Telemetry, Alert, Threshold
from common.metrics import start_metrics_server, alerts_generated, threshold_checks, processing_errors
from common.logger import get_logger


log = get_logger("stream-worker")

# Config
STUCK_COUNT = 5
RATE_THRESHOLD = 10.0


class StreamProcessor:
    def __init__(self):
        self.thresholds: dict[str, Threshold] = {}
        self.last_value: dict[str, float] = {}
        self.value_history: dict[str, deque] = defaultdict(lambda: deque(maxlen=STUCK_COUNT))
        self.producer = KafkaProducer()

    def load_thresholds(self):
        log.info("Loading thresholds")
        rows = query("SELECT * FROM thresholds")
        for row in rows:
            key = row["sensor_type"]
            if row["device_type"]:
                key = f"{row['device_type']}:{row['sensor_type']}"
            self.thresholds[key] = Threshold(
                sensor_type=row["sensor_type"],
                device_type=row["device_type"],
                warning_low=row["warning_low"],
                warning_high=row["warning_high"],
                critical_low=row["critical_low"],
                critical_high=row["critical_high"],
            )
        log.info("Loaded thresholds", extra={"extra": {"count": len(self.thresholds)}})

    def get_threshold(self, device_type: str, sensor_type: str) -> Threshold | None:
        return self.thresholds.get(f"{device_type}:{sensor_type}") or self.thresholds.get(sensor_type)

    def emit_alert(self, telemetry: Telemetry, alert_type: str, severity: str, message: str, value: float, threshold: float = None):
        log.info("Generating alert", extra={"extra": {
            "device_id": telemetry.device_id,
            "alert_type": alert_type,
            "severity": severity,
            "value": value,
            "threshold": threshold
        }})
        alert = Alert(
            alert_id=str(uuid.uuid4()),
            device_id=telemetry.device_id,
            device_type=telemetry.device_type,
            alert_type=alert_type,
            severity=severity,
            message=message,
            value=value,
            threshold=threshold,
        )
        self.producer.send(KAFKA_ALERTS_TOPIC, alert.to_dict(), key=telemetry.device_id)
        alerts_generated.labels(alert_type=alert_type, severity=severity).inc()
        
        log.info("Alert generated", extra={"extra": {
            "alert_id": alert.alert_id,
            "device_id": telemetry.device_id,
            "alert_type": alert_type,
            "severity": severity,
            "value": value,
            "threshold": threshold
        }})

    def process(self, telemetry: Telemetry):
        log.info("Processing telemetry", extra={"extra": {
            "device_id": telemetry.device_id,
            "device_type": telemetry.device_type,
            "sensor_id": telemetry.sensor_id,
            "sensor_type": telemetry.sensor_type,
            "value": telemetry.scalar_value()
        }})
        key = f"{telemetry.device_id}:{telemetry.sensor_id}"
        
        if telemetry.sensor_type == "vibration":
            value = telemetry.vibration_rms()
        else:
            value = telemetry.scalar_value()

        if value is None:
            return

        threshold = self.get_threshold(telemetry.device_type, telemetry.sensor_type)
        threshold_checks.labels(sensor_type=telemetry.sensor_type).inc()

        # 1. Threshold breach
        if threshold:
            result = threshold.check(value)
            if result:
                alert_type, severity = result
                limit = threshold.critical_high or threshold.warning_high or threshold.critical_low or threshold.warning_low
                self.emit_alert(
                    telemetry, alert_type, severity,
                    f"{telemetry.sensor_type} value {value:.2f} exceeds limit {limit}",
                    value, limit
                )

        # 2. Rate of change
        if key in self.last_value:
            delta = abs(value - self.last_value[key])
            if delta > RATE_THRESHOLD:
                self.emit_alert(
                    telemetry, "rapid_change", "warning",
                    f"{telemetry.sensor_type} changed by {delta:.2f} in one reading",
                    value, RATE_THRESHOLD
                )

        # 3. Stuck sensor
        history = self.value_history[key]
        history.append(value)
        if len(history) == STUCK_COUNT and len(set(history)) == 1:
            self.emit_alert(
                telemetry, "stuck_sensor", "warning",
                f"{telemetry.sensor_id} stuck at {value:.2f} for {STUCK_COUNT} readings",
                value
            )

        self.last_value[key] = value


def main():
    log.info("Starting stream-workera")
    start_metrics_server(8000)

    processor = StreamProcessor()
    processor.load_thresholds()

    consumer = KafkaConsumer(
        topic=KAFKA_TELEMETRY_TOPIC,
        group_id="stream-worker"
    )
    log.info("Listening", extra={"extra": {"topic": KAFKA_TELEMETRY_TOPIC}})

    for msg in consumer:
        try:
            telemetry = Telemetry.from_dict(msg)
            processor.process(telemetry)
        except Exception as e:
            log.exception("Error processing message")
            processing_errors.labels(worker="stream", error_type=type(e).__name__).inc()


if __name__ == "__main__":
    main()

