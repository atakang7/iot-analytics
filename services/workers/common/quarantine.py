"""Durable quarantine for malformed Kafka messages.

The broker must accept this copy before callers commit the bad source offset.
No exception messages or user-provided values become Kafka keys or metric labels.
"""
import base64

from common.config import KAFKA_QUARANTINE_TOPIC

REASONS = frozenset({"invalid_json", "invalid_telemetry", "invalid_alert"})


def quarantine_invalid(producer, record, worker: str, *, reason: str) -> None:
    if reason not in REASONS:
        raise ValueError("Unknown quarantine reason")
    if worker not in {"telemetry-worker", "stream-worker", "alert-worker"}:
        raise ValueError("Unknown quarantine worker")
    if not isinstance(record.value, bytes):
        raise ValueError("Quarantine requires original Kafka record bytes")
    identity = f"{worker}:{record.topic}:{record.partition}:{record.offset}"
    body = {
        "worker": worker,
        "sourceTopic": record.topic,
        "sourcePartition": record.partition,
        "sourceOffset": record.offset,
        "sourceKeyBase64": base64.b64encode(record.key or b"").decode("ascii"),
        "payloadBase64": base64.b64encode(record.value).decode("ascii"),
        "reason": reason,
    }
    # KafkaProducer.send waits for acks=all; a failed send raises.
    producer.send(KAFKA_QUARANTINE_TOPIC, body, key=identity)
