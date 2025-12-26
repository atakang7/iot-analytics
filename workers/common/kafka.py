import json
from kafka import KafkaConsumer as _KafkaConsumer, KafkaProducer as _KafkaProducer
from common.config import KAFKA_BOOTSTRAP


class KafkaConsumer:
    def __init__(self, topic: str, group_id: str):
        self._consumer = _KafkaConsumer(
            topic,
            bootstrap_servers=KAFKA_BOOTSTRAP,
            group_id=group_id,
            value_deserializer=lambda m: json.loads(m.decode("utf-8")),
            auto_offset_reset="earliest",
            enable_auto_commit=True,
        )
        self.topic = topic

    def __iter__(self):
        return self

    def __next__(self):
        msg = next(self._consumer)
        return msg.value

    def close(self):
        self._consumer.close()


class KafkaProducer:
    def __init__(self):
        self._producer = _KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8") if k else None,
        )

    def send(self, topic: str, value: dict, key: str = None):
        self._producer.send(topic, value=value, key=key)
        self._producer.flush()

    def close(self):
        self._producer.close()
