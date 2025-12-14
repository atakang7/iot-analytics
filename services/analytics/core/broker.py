"""
Kafka Connection

Simple async Kafka consumer/producer for Kappa architecture.
Supports consuming from offset (replay) and consumer groups.
"""

import json
import asyncio
from enum import Enum
from typing import Callable, Awaitable, Any, Optional
from aiokafka import AIOKafkaConsumer, AIOKafkaProducer


class StartFrom(Enum):
    """Where to start consuming."""
    EARLIEST = "earliest"  # replay from beginning (Kappa reprocessing)
    LATEST = "latest"      # only new messages
    COMMITTED = "committed" # from last committed offset (resume)


class Broker:
    def __init__(self, bootstrap_servers: str):
        self.servers = bootstrap_servers
        self.consumer: Optional[AIOKafkaConsumer] = None
        self.producer: Optional[AIOKafkaProducer] = None
        self._running = False
    
    async def connect_producer(self):
        """Connect producer for publishing messages."""
        self.producer = AIOKafkaProducer(
            bootstrap_servers=self.servers,
            value_serializer=lambda v: json.dumps(v).encode(),
        )
        await self.producer.start()
    
    async def connect_consumer(
        self,
        topic: str,
        group_id: str,
        start_from: StartFrom = StartFrom.COMMITTED,
    ):
        """
        Connect consumer to a topic.
        
        Args:
            topic: Topic to consume from
            group_id: Consumer group (for offset tracking)
            start_from: EARLIEST (replay all), LATEST (new only), COMMITTED (resume)
        """
        auto_offset = start_from.value if start_from != StartFrom.COMMITTED else "earliest"
        
        self.consumer = AIOKafkaConsumer(
            topic,
            bootstrap_servers=self.servers,
            group_id=group_id,
            auto_offset_reset=auto_offset,
            enable_auto_commit=True,
            value_deserializer=lambda v: json.loads(v.decode()),
        )
        await self.consumer.start()
    
    async def disconnect(self):
        """Close all connections."""
        if self.consumer:
            await self.consumer.stop()
        if self.producer:
            await self.producer.stop()
    
    async def consume(self, handler: Callable[[dict], Awaitable[Any]]):
        """
        Blocking consume - process messages forever.
        Call connect_consumer() first.
        """
        self._running = True
        try:
            async for msg in self.consumer:
                if not self._running:
                    break
                await handler(msg.value)
        finally:
            self._running = False
    
    async def listen(self, handler: Callable[[dict], Awaitable[Any]]):
        """
        Non-blocking consume - starts background task and returns.
        Call connect_consumer() first.
        """
        self._running = True
        
        async def _loop():
            async for msg in self.consumer:
                if not self._running:
                    break
                await handler(msg.value)
        
        asyncio.create_task(_loop())
    
    def stop(self):
        """Stop the consumer loop."""
        self._running = False
    
    async def publish(self, topic: str, value: dict, key: Optional[str] = None):
        """
        Publish message to topic.
        
        Args:
            topic: Topic name
            value: Message body (dict, will be JSON serialized)
            key: Optional partition key (same key = same partition = ordering)
        """
        key_bytes = key.encode() if key else None
        await self.producer.send_and_wait(topic, value=value, key=key_bytes)

