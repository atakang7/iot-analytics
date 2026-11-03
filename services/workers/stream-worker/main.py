"""Threshold, rate-change and stuck-sensor event processor.

The source offset is committed only after alert publishing succeeds.
"""
import uuid
from collections import defaultdict, deque

from common.config import KAFKA_ALERTS_TOPIC, KAFKA_TELEMETRY_TOPIC, METRICS_PORT
from common.db import query
from common.kafka import KafkaConsumer, KafkaProducer
from common.logger import get_logger
from common.metrics import alerts_generated, processing_errors, start_metrics_server, threshold_checks
from common.models import Alert, Telemetry, Threshold

log = get_logger("stream-worker")
STUCK_COUNT = 5
RATE_THRESHOLD = 10.0


class StreamProcessor:
    def __init__(self):
        self.thresholds: dict[str, Threshold] = {}
        self.last_value: dict[str, float] = {}
        self.value_history: dict[str, deque] = defaultdict(lambda: deque(maxlen=STUCK_COUNT))
        self.stuck_reported: set[str] = set()
        self.producer = KafkaProducer()

    def load_thresholds(self):
        rows = query("SELECT * FROM thresholds")
        for row in rows:
            key = (
                f"{row['device_type']}:{row['sensor_type']}"
                if row["device_type"] else row["sensor_type"]
            )
            self.thresholds[key] = Threshold(
                sensor_type=row["sensor_type"],
                device_type=row["device_type"],
                warning_low=row["warning_low"],
                warning_high=row["warning_high"],
                critical_low=row["critical_low"],
                critical_high=row["critical_high"],
            )
        log.info("Thresholds loaded", extra={"extra": {"count": len(self.thresholds)}})

    def get_threshold(self, device_type: str, sensor_type: str) -> Threshold | None:
        return self.thresholds.get(f"{device_type}:{sensor_type}") or self.thresholds.get(sensor_type)

    def emit_alert(
        self, telemetry: Telemetry, alert_type: str, severity: str,
        message: str, value: float, threshold: float = None
    ):
        # Stable identity across Kafka retries, unlike a random UUID4.
        identity = ":".join((
            telemetry.device_id, telemetry.sensor_id, telemetry.timestamp.isoformat(),
            alert_type, severity,
        ))
        alert = Alert(
            alert_id=str(uuid.uuid5(uuid.NAMESPACE_URL, identity)),
            device_id=telemetry.device_id,
            device_type=telemetry.device_type,
            alert_type=alert_type,
            severity=severity,
            message=message,
            value=value,
            threshold=threshold,
            created_at=telemetry.timestamp,
        )
        self.producer.send(KAFKA_ALERTS_TOPIC, alert.to_dict(), key=telemetry.device_id)
        alerts_generated.labels(alert_type=alert_type, severity=severity).inc()

    def process(self, telemetry: Telemetry):
        key = f"{telemetry.device_id}:{telemetry.sensor_id}"
        value = (
            telemetry.vibration_rms()
            if telemetry.sensor_type == "vibration"
            else telemetry.scalar_value()
        )
        if value is None:
            return

        threshold = self.get_threshold(telemetry.device_type, telemetry.sensor_type)
        threshold_checks.labels(sensor_type=telemetry.sensor_type).inc()
        if threshold:
            result = threshold.check(value)
            if result:
                _, severity = result
                # Report the actual boundary breached, including zero.
                bounds = (
                    (threshold.critical_high, value > threshold.critical_high)
                    if threshold.critical_high is not None else (None, False),
                    (threshold.critical_low, value < threshold.critical_low)
                    if threshold.critical_low is not None else (None, False),
                    (threshold.warning_high, value > threshold.warning_high)
                    if threshold.warning_high is not None else (None, False),
                    (threshold.warning_low, value < threshold.warning_low)
                    if threshold.warning_low is not None else (None, False),
                )
                limit = next(bound for bound, breached in bounds if breached)
                self.emit_alert(
                    telemetry, "threshold_breach", severity,
                    f"{telemetry.sensor_type} value {value:.2f} breached limit {limit}",
                    value, limit,
                )

        previous = self.last_value.get(key)
        if previous is not None:
            delta = abs(value - previous)
            if delta > RATE_THRESHOLD:
                self.emit_alert(
                    telemetry, "rapid_change", "warning",
                    f"{telemetry.sensor_type} changed by {delta:.2f} in one reading",
                    value, RATE_THRESHOLD,
                )

        history = self.value_history[key]
        history.append(value)
        stuck = len(history) == STUCK_COUNT and len(set(history)) == 1
        if stuck and key not in self.stuck_reported:
            self.emit_alert(
                telemetry, "stuck_sensor", "warning",
                f"{telemetry.sensor_id} unchanged for {STUCK_COUNT} readings", value,
            )
            self.stuck_reported.add(key)
        elif not stuck:
            self.stuck_reported.discard(key)
        self.last_value[key] = value

    def close(self):
        self.producer.close()


def main():
    start_metrics_server(METRICS_PORT)
    processor = StreamProcessor()
    processor.load_thresholds()
    consumer = KafkaConsumer(KAFKA_TELEMETRY_TOPIC, group_id="stream-worker")
    try:
        for message in consumer:
            try:
                processor.process(Telemetry.from_dict(message))
                consumer.commit()
            except Exception as exc:
                processing_errors.labels(worker="stream", error_type=type(exc).__name__).inc()
                log.exception("Message failed before offset commit")
                raise
    finally:
        consumer.close()
        processor.close()


if __name__ == "__main__":
    main()
