"""
Pipeline Worker Base

Each pipeline runs as an independent worker that:
- Consumes from a specific Kafka topic/partition pattern
- Scales independently via KEDA based on consumer lag
- Has its own consumer group
- Can be deployed/scaled/restarted independently

This is the enterprise pattern used by Netflix, Uber, LinkedIn etc.
"""

import asyncio
import signal
from abc import ABC, abstractmethod
from typing import Optional
from dataclasses import dataclass
from enum import Enum

from core.config import Config
from core.broker import Broker, StartFrom

from core.metrics import MetricsServer, metrics
from core.logging import get_logger

logger = get_logger("worker.base", labels={"component": "worker-base"})


class WorkerState(Enum):
    STARTING = "starting"
    RUNNING = "running"
    STOPPING = "stopping"
    STOPPED = "stopped"


@dataclass
class WorkerConfig:
    """Configuration for a pipeline worker."""
    name: str
    topic: str
    group_id: str
    metrics_port: int = 8082
    
    # Optional: filter messages by field value
    filter_field: Optional[str] = None
    filter_values: Optional[list[str]] = None
    
    # Scaling hints (used by KEDA)
    min_replicas: int = 0
    max_replicas: int = 10
    lag_threshold: int = 100  # Scale up when lag > this


class PipelineWorker(ABC):
    """
    Base class for pipeline workers.
    
    Each pipeline extends this and implements:
    - process(): Handle a single message
    - Optional: setup(), teardown() for init/cleanup
    
    Example:
        class AnomalyWorker(PipelineWorker):
            def __init__(self):
                super().__init__(WorkerConfig(
                    name="anomaly-detector",
                    topic="telemetry",
                    group_id="analytics-anomaly",
                    filter_field="metric_type",
                    filter_values=["temperature", "pressure"]
                ))
                self.detector = AnomalyDetector(threshold=3.0)
            
            async def process(self, data: dict):
                result = self.detector.process(data)
                if result.has_alerts():
                    await self.publish_alert(result.alerts)
    """
    
    def __init__(self, config: WorkerConfig):
        self.config = config
        self.state = WorkerState.STOPPED
        self._broker: Optional[Broker] = None
        self._metrics_server: Optional[MetricsServer] = None
        self._shutdown_event = asyncio.Event()
    
    @property
    def name(self) -> str:
        return self.config.name
    
    @abstractmethod
    async def process(self, data: dict) -> None:
        """
        Process a single message. Override this.
        
        This method should be idempotent - the same message
        processed twice should produce the same result.
        """
        pass
    
    async def setup(self) -> None:
        """Optional: Called once before processing starts."""
        pass
    
    async def teardown(self) -> None:
        """Optional: Called once after processing stops."""
        pass
    
    def should_process(self, data: dict) -> bool:
        """Check if this message should be processed by this worker."""
        if not self.config.filter_field or not self.config.filter_values:
            return True
        
        value = data.get(self.config.filter_field)
        return value in self.config.filter_values
    
    async def _handle_message(self, data: dict) -> None:
        """Internal message handler with filtering and metrics."""
        if not self.should_process(data):
            return
        
        try:
            metrics.messages_processed.labels(pipeline=self.name).inc()
            await self.process(data)
        except Exception as e:
            metrics.pipeline_errors.labels(pipeline=self.name).inc()
            logger.error(f"Error processing message: {e}", extra={"labels": {"worker": self.name}})
    
    async def run(self) -> None:
        """Main entry point - runs the worker."""
        self.state = WorkerState.STARTING
        logger.info(f"Starting worker: {self.name}", extra={"labels": {"worker": self.name}})

        # Setup signal handlers
        loop = asyncio.get_event_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, self._signal_handler)

        # Start metrics server
        self._metrics_server = MetricsServer(self.config.metrics_port)
        self._metrics_server.start()
        logger.info(f"Metrics server on port {self.config.metrics_port}", extra={"labels": {"worker": self.name}})

        # Run setup
        await self.setup()

        # Connect to Kafka
        self._broker = Broker(Config.KAFKA_BOOTSTRAP_SERVERS)
        await self._broker.connect_consumer(
            topic=self.config.topic,
            group_id=self.config.group_id,
            start_from=StartFrom.LATEST,
        )

        self.state = WorkerState.RUNNING
        logger.info(f"Consuming from {self.config.topic} (group: {self.config.group_id})", extra={"labels": {"worker": self.name, "topic": self.config.topic, "group": self.config.group_id}})

        # Main consume loop
        try:
            await self._broker.consume(self._handle_message)
        except asyncio.CancelledError:
            pass
        finally:
            await self._shutdown()
    
    def _signal_handler(self):
        """Handle shutdown signals."""
        logger.warning(f"Shutdown signal received", extra={"labels": {"worker": self.name}})
        self._shutdown_event.set()
    
    async def _shutdown(self) -> None:
        """Clean shutdown."""
        if self.state == WorkerState.STOPPED:
            return

        self.state = WorkerState.STOPPING
        logger.info(f"Shutting down...", extra={"labels": {"worker": self.name}})

        if self._broker:
            await self._broker.disconnect()

        await self.teardown()

        if self._metrics_server:
            self._metrics_server.stop()

        self.state = WorkerState.STOPPED
        logger.info(f"Stopped", extra={"labels": {"worker": self.name}})


def run_worker(worker: PipelineWorker):
    asyncio.run(worker.run())
