"""Kafka telemetry consumer: bounded batches -> TimescaleDB.

The database transaction finishes BEFORE the Kafka consumer offset is committed.
"""
from psycopg2.extras import execute_values

from common.config import KAFKA_TELEMETRY_TOPIC, METRICS_PORT
from common.db import get_connection
from common.kafka import KafkaConsumer
from common.logger import get_logger
from common.metrics import (
    processing_errors,
    start_metrics_server,
    telemetry_received,
    telemetry_stored,
)
from common.models import Telemetry

log = get_logger("telemetry-worker")
BATCH_SIZE = 500


def flush_batch(batch: list[dict]) -> int:
    if not batch:
        return 0
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            execute_values(
                cursor,
                """INSERT INTO telemetry
                   (time, device_id, device_type, sensor_id, sensor_type, value, unit)
                   VALUES %s
                   ON CONFLICT (device_id, sensor_id, time) DO NOTHING
                   RETURNING device_type""",
                [
                    (
                        row["time"],
                        row["device_id"],
                        row["device_type"],
                        row["sensor_id"],
                        row["sensor_type"],
                        row["value"],
                        row["unit"],
                    )
                    for row in batch
                ],
                fetch=True,
            )
            inserted = cursor.fetchall() if False else cursor.rowcount
        conn.commit()
        return inserted
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def main():
    start_metrics_server(METRICS_PORT)
    consumer = KafkaConsumer(KAFKA_TELEMETRY_TOPIC, group_id="telemetry-worker")
    log.info("Consuming telemetry", extra={"extra": {"topic": KAFKA_TELEMETRY_TOPIC}})
    try:
        while True:
            messages = consumer.poll(timeout_ms=500, max_records=BATCH_SIZE)
            if not messages:
                continue
            try:
                readings = [Telemetry.from_dict(message) for message in messages]
                batch = [reading.to_db_row() for reading in readings]
                stored = flush_batch(batch)
                consumer.commit()
                for reading in readings:
                    telemetry_received.labels(
                        device_type=reading.device_type, sensor_type=reading.sensor_type
                    ).inc()
                # Counter reflects successful DB INSERTs, not duplicate Kafka replays.
                telemetry_stored.labels(device_type="all").inc(stored)
                log.info(
                    "Batch committed", extra={"extra": {"received": len(batch), "inserted": stored}}
                )
            except Exception as exc:
                processing_errors.labels(
                    worker="telemetry", error_type=type(exc).__name__
                ).inc()
                log.exception("Batch failed before offset commit")
                raise
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
