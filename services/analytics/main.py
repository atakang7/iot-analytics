"""
Analytics Service Entry Point

Consumes telemetry from Kafka and exposes metrics.
"""

import asyncio
from core.config import Config
from core.broker import Broker, StartFrom
from core.metrics import MetricsServer
from core.database import Database


async def handle_telemetry(data: dict):
    """Process incoming telemetry message."""
    print(f"Received: {data}")


async def main():
    # Start metrics server
    metrics = MetricsServer(Config.METRICS_PORT)
    metrics.start()
    
    # Connect to Kafka
    broker = Broker(Config.KAFKA_BOOTSTRAP_SERVERS)
    await broker.connect_consumer(
        topic=Config.KAFKA_TOPIC,
        group_id=Config.KAFKA_GROUP_ID,
        start_from=StartFrom.LATEST,
    )
    
    print(f"Analytics service started. Consuming from {Config.KAFKA_TOPIC}...")
    
    try:
        await broker.consume(handle_telemetry)
    except KeyboardInterrupt:
        pass
    finally:
        await broker.disconnect()
        metrics.stop()


if __name__ == "__main__":
    asyncio.run(main())
