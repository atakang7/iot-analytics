"""Persist alerts idempotently before committing their Kafka offsets."""
from datetime import datetime

from common.config import KAFKA_ALERTS_TOPIC, METRICS_PORT
from common.db import upsert_one
from common.kafka import KafkaConsumer
from common.logger import get_logger
from common.metrics import alerts_stored, processing_errors, push_metrics, start_metrics_server

log = get_logger("alert-worker")


def parse_alert(message: dict) -> dict:
    return {
        "created_at": datetime.fromisoformat(message["createdAt"].replace("Z", "+00:00")),
        "alert_id": message["alertId"],
        "device_id": message["deviceId"],
        "device_type": message["deviceType"],
        "alert_type": message["alertType"],
        "severity": message["severity"],
        "message": message["message"],
        "threshold": message.get("threshold"),
        "value": message.get("value"),
    }


def main():
    start_metrics_server(METRICS_PORT)
    consumer = KafkaConsumer(KAFKA_ALERTS_TOPIC, group_id="alert-worker")
    try:
        for message in consumer:
            try:
                row = parse_alert(message)
                upsert_one("alerts", row, conflict_cols=["alert_id"])
                consumer.commit()
                alerts_stored.labels(
                    alert_type=row["alert_type"], severity=row["severity"]
                ).inc()
                log.info("Alert committed", extra={"extra": {"alert_id": row["alert_id"]}})
            except Exception as exc:
                processing_errors.labels(worker="alert", error_type=type(exc).__name__).inc()
                log.exception("Alert failed before offset commit")
                raise
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
