"""Kafka transports with explicit offset commits.

A message is acknowledged only after its side effect (database write or
downstream publish) succeeds. Processing is at-least-once, not exactly-once.
"""
import json

from kafka import KafkaConsumer as _KafkaConsumer
from kafka import KafkaProducer as _KafkaProducer

from common.config import KAFKA_BOOTSTRAP


class KafkaConsumer:
    def __init__(self, topic: str, group_id: str):
        self._consumer = _KafkaConsumer(
            topic,
            bootstrap_servers=KAFKA_BOOTSTRAP,
            group_id=group_id,
            value_deserializer=lambda payload: json.loads(payload.decode("utf-8")),
            auto_offset_reset="earliest",
            enable_auto_commit=False,
            # Default consumer timeout is infinite: idle streams must not exit.
        )

    def __iter__(self):
        return self

    def __next__(self):
        return next(self._consumer).value

    def poll(self, timeout_ms: int = 500, max_records: int = 500) -> list[dict]:
        records = self._consumer.poll(timeout_ms=timeout_ms, max_records=max_records)
        return [record.value for batch in records.values() for record in batch]

    def commit(self):
        self._consumer.commit()

    def close(self):
        self._consumer.close()


class KafkaProducer:
    def __init__(self):
        self._producer = _KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            acks="all",
            retries=5,
            max_block_ms=15000,
            request_timeout_ms=10000,
            value_serializer=lambda value: json.dumps(value, allow_nan=False).encode("utf-8"),
            key_serializer=lambda key: key.encode("utf-8") if key else None,
        )

    def send(self, topic: str, value: dict, key: str = None):
        # Asynchronous send without .get() can silently lose alerts before
        # the consumer commits its source offset.
        return self._producer.send(topic, value=value, key=key).get(timeout=15)

    def close(self):
        self._producer.flush(timeout=15)
        self._producer.close()
