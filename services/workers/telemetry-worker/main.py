#!/usr/bin/env python3
"""
Telemetry Worker
Kafka: iot.telemetry → TimescaleDB: telemetry
"""
import sys
sys.path.insert(0, "/app")

from common.config import KAFKA_TELEMETRY_TOPIC
from common.kafka import KafkaConsumer
from common.db import insert_one
from common.models import Telemetry
from common.metrics import start_metrics_server, telemetry_received, telemetry_stored, processing_errors
from common.logger import get_logger


log = get_logger("telemetry-worker")


def main():
    log.info("Starting telemetry-worker")
    start_metrics_server(8000)

    consumer = KafkaConsumer(
        topic=KAFKA_TELEMETRY_TOPIC,
        group_id="telemetry-worker"
    )
    log.info("Listening", extra={"extra": {"topic": KAFKA_TELEMETRY_TOPIC}})

    for msg in consumer:
        try:
            telemetry = Telemetry.from_dict(msg)
            
            telemetry_received.labels(
                device_type=telemetry.device_type,
                sensor_type=telemetry.sensor_type
            ).inc()

            insert_one("telemetry", telemetry.to_db_row())
            
            telemetry_stored.labels(device_type=telemetry.device_type).inc()

            log.info("Stored", extra={"extra": {
                "device_id": telemetry.device_id,
                "sensor_type": telemetry.sensor_type
            }})

        except Exception as e:
            log.exception("Error processing message")
            processing_errors.labels(worker="telemetry", error_type=type(e).__name__).inc()


if __name__ == "__main__":
    main()
