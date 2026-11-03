"""Kafka telemetry consumer: bounded batches -> TimescaleDB.

The database transaction finishes BEFORE the Kafka consumer offset is committed.
"""
from psycopg2.extras import execute_values

from common.config import KAFKA_TELEMETRY_TOPIC, METRICS_PORT
from common.db import get_connection
from common.kafka import KafkaConsumer, KafkaProducer, decode_record
from common.quarantine import quarantine_invalid
from common.logger import get_logger
from common.metrics import (
    processing_errors, quarantined_messages, start_metrics_server,
    telemetry_received, telemetry_stored,
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
            inserted_rows = execute_values(
                cursor,
                """INSERT INTO telemetry
                   (time, device_id, device_type, sensor_id, sensor_type, value, unit)
                   VALUES %s
                   ON CONFLICT (device_id, sensor_id, time) DO NOTHING
                   RETURNING device_type""",
                [
                    (
                        row["time"], row["device_id"], row["device_type"],
                        row["sensor_id"], row["sensor_type"], row["value"], row["unit"],
                    )
                    for row in batch
                ],
                fetch=True,
            )
        conn.commit()
        return len(inserted_rows)
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()



def process_batch(records, consumer, producer, *, persist=None) -> tuple[int, int, int]:
    """Finish SQL writes and broker quarantine before committing fetched offsets."""
    if persist is None:
        persist = flush_batch
    readings = []
    rejected = []
    for record in records:
        try:
            body = decode_record(record)
        except (ValueError, UnicodeError):
            rejected.append((record, "invalid_json"))
            continue
        try:
            readings.append(Telemetry.from_dict(body))
        except (ValueError, TypeError, KeyError, OverflowError):
            rejected.append((record, "invalid_telemetry"))

    stored = persist([reading.to_db_row() for reading in readings])
    for record, reason in rejected:
        quarantine_invalid(producer, record, "telemetry-worker", reason=reason)
    # If SQL or any quarantine publish fails, the source offsets remain uncommitted.
    consumer.commit()

    for reading in readings:
        telemetry_received.labels(
            device_type=reading.device_type, sensor_type=reading.sensor_type,
        ).inc()
    telemetry_stored.labels(device_type="all").inc(stored)
    for _, reason in rejected:
        quarantined_messages.labels(worker="telemetry-worker", reason=reason).inc()
    return len(readings), stored, len(rejected)


def main():
    start_metrics_server(METRICS_PORT)
    consumer = KafkaConsumer(KAFKA_TELEMETRY_TOPIC, group_id="telemetry-worker")
    quarantine_producer = None
    log.info("Consuming telemetry", extra={"extra": {"topic": KAFKA_TELEMETRY_TOPIC}})
    try:
        quarantine_producer = KafkaProducer()
        while True:
            records = consumer.poll_raw(timeout_ms=500, max_records=BATCH_SIZE)
            if not records:
                continue
            try:
                received, stored, quarantined = process_batch(
                    records, consumer, quarantine_producer,
                )
                log.info(
                    "Batch committed",
                    extra={"extra": {
                        "received": received, "inserted": stored,
                        "quarantined": quarantined,
                    }},
                )
            except Exception as exc:
                processing_errors.labels(
                    worker="telemetry", error_type=type(exc).__name__,
                ).inc()
                log.exception("Batch failed before source offset commit")
                raise
    finally:
        consumer.close()
        if quarantine_producer is not None:
            quarantine_producer.close()


if __name__ == "__main__":
    main()
