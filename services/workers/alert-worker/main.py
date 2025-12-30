#!/usr/bin/env python3
"""
Alert Worker
Kafka: iot.alerts → TimescaleDB: alerts + Prometheus pushgateway
"""
import sys
import time
import uuid
sys.path.insert(0, "/app")

from datetime import datetime 

from common.config import KAFKA_ALERTS_TOPIC
from common.kafka import KafkaConsumer
from common.db import upsert_one
from common.metrics import start_metrics_server, alerts_stored, alerts_active, push_metrics, processing_errors
from common.logger import get_logger


log = get_logger("alert-worker")


def parse_alert(msg: dict) -> dict:
    return {
        "created_at": datetime.fromisoformat(msg["createdAt"].replace("Z", "+00:00")),
        "alert_id": msg["alertId"],
        "device_id": msg["deviceId"],
        "device_type": msg["deviceType"],
        "alert_type": msg["alertType"],
        "severity": msg["severity"],
        "message": msg["message"],
        "threshold": msg.get("threshold"),
        "value": msg.get("value"),
    }


def main():
    log.info("Starting alert-worker")
    
    start_metrics_server(8000)
 
    log.info("Starting kafka-consumer")
    consumer = KafkaConsumer(
        topic=KAFKA_ALERTS_TOPIC,
        group_id="alert-worker"
    )
    log.info("Listening", extra={"extra": {"topic": KAFKA_ALERTS_TOPIC}})

    for msg in consumer:
        try:
            row = parse_alert(msg)
            upsert_one("alerts", row, conflict_cols=["alert_id", "created_at"])

            alerts_stored.labels(
                alert_type=msg["alertType"],
                severity=msg["severity"] 
            ).inc()

            alerts_active.labels(
                device_id=msg["deviceId"],
                alert_type=msg["alertType"]
            ).set(1)

            log.info("Alert stored", extra={"extra": {
                "alert_id": msg["alertId"],
                "device_id": msg["deviceId"],
                "alert_type": msg["alertType"],
                "severity": msg["severity"],
                "start_time": time.time(),
                "end_time": time.time(),
                "duration": time.time() - time.time(),
                "worker_id": str(uuid.uuid4()),
            }})

            try:
                push_metrics("alert-worker")
            except Exception:
                pass

        except Exception as e:
            log.exception("Error processing alert", extra={"extra": {
                "alert_id": msg.get("alertId"),
                "device_id": msg.get("deviceId"),
                "alert_type": msg.get("alertType"),
                "severity": msg.get("severity"),
                "start_time": time.time(),
                "end_time": time.time(),
                "duration": time.time() - time.time(),
                "worker_id": str(uuid.uuid4()),
            }})
            processing_errors.labels(worker="alert", error_type=type(e).__name__).inc()


if __name__ == "__main__":
    main()

