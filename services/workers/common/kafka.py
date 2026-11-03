"""Kafka transport with raw-record access and explicit source offset commits."""
import json

from kafka import KafkaConsumer as _KafkaConsumer
from kafka import KafkaProducer as _KafkaProducer

from common.config import KAFKA_BOOTSTRAP


def decode_record(record) -> dict:
    """Decode one Kafka record, keeping its topic/partition/offset available."""
    message = json.loads(record.value.decode("utf-8"))
    if not isinstance(message, dict):
        raise ValueError("Kafka event must be a JSON object")
    return message


class KafkaConsumer:
    def __init__(self, topic: str, group_id: str):
        self._consumer = _KafkaConsumer(
            topic,
            bootstrap_servers=KAFKA_BOOTSTRAP,
            group_id=group_id,
            # Keep raw bytes to quarantine bad JSON with original coordinates.
            value_deserializer=None,
            auto_offset_reset="earliest",
            enable_auto_commit=False,
        )

    def __iter__(self):
        return self

    def __next__(self):
        return decode_record(next(self._consumer))

    def poll_raw(self, timeout_ms: int = 500, max_records: int = 500):
        records = self._consumer.poll(timeout_ms=timeout_ms, max_records=max_records)
        return [record for batch in records.values() for record in batch]

    def poll(self, timeout_ms: int = 500, max_records: int = 500) -> list[dict]:
        return [decode_record(r) for r in self.poll_raw(timeout_ms, max_records)]

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
            value_serializer=lambda value: json.dumps(value, allow_nan=False).encode("utf-8"),
            key_serializer=lambda key: key.encode("utf-8") if key else None,
        )

    def send(self, topic: str, value: dict, key: str = None):
        # Await downstream broker acknowledgment before committing the source offset.
        return self._producer.send(topic, value=value, key=key).get(timeout=15)

    def close(self):
        self._producer.flush(timeout=15)
        self._producer.close()
