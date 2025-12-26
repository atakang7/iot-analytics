#!/usr/bin/env python3
"""
Telemetry Worker (Batched - Simple)
Kafka: iot.telemetry → TimescaleDB: telemetry
"""
import sys
import time
sys.path.insert(0, "/app")

from common.config import KAFKA_TELEMETRY_TOPIC
from common.kafka import KafkaConsumer
from common.db import get_connection
from common.models import Telemetry
from common.metrics import start_metrics_server, telemetry_received, telemetry_stored, processing_errors
from common.logger import get_logger

log = get_logger("telemetry-worker")

BATCH_SIZE = 100
FLUSH_INTERVAL_SEC = 1.0


def flush_batch(batch):
    """Insert batch in single transaction"""
    if not batch:
        return 0
    
    conn = get_connection()
    cur = conn.cursor()
    
    try:
        cur.executemany(
            """INSERT INTO telemetry (time, device_id, device_type, sensor_id, sensor_type, value, unit)
               VALUES (%(time)s, %(device_id)s, %(device_type)s, %(sensor_id)s, %(sensor_type)s, %(value)s, %(unit)s)""",
            batch
        )
        conn.commit()
        return len(batch)
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()


def main():
    log.info("Starting telemetry-worker", extra={"extra": {"batch_size": BATCH_SIZE}})
    start_metrics_server(8000)

    consumer = KafkaConsumer(topic=KAFKA_TELEMETRY_TOPIC, group_id="telemetry-worker")
    log.info("Listening", extra={"extra": {"topic": KAFKA_TELEMETRY_TOPIC}})

    batch = []
    last_flush = time.time()

    for msg in consumer:
        try:
            t = Telemetry.from_dict(msg)
            telemetry_received.labels(device_type=t.device_type, sensor_type=t.sensor_type).inc()
            batch.append(t.to_db_row())

            # Flush conditions
            if len(batch) >= BATCH_SIZE or (time.time() - last_flush) >= FLUSH_INTERVAL_SEC:
                n = flush_batch(batch)
                for row in batch:
                    telemetry_stored.labels(device_type=row["device_type"]).inc()
                log.info("Stored batch", extra={"extra": {"count": n}})
                batch = []
                last_flush = time.time()

        except Exception as e:
            log.exception("Error")
            processing_errors.labels(worker="telemetry", error_type=type(e).__name__).inc()
  

if __name__ == "__main__":
    main()