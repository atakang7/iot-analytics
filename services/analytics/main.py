"""
Analytics Service Entry Point

Can run in two modes:
1. Combined mode (default): All pipelines in one process
2. Worker mode: Run a specific worker (for K8s scaling)

Usage:
    # Combined mode (development)
    python main.py
    
    # Worker mode (production)
    python main.py --worker anomaly
    python main.py --worker aggregator
    python main.py --worker alerter
"""

import asyncio
import argparse
from core.config import Config
from core.broker import Broker, StartFrom

from core.metrics import MetricsServer, metrics
from core.logging import get_logger

logger = get_logger("main", labels={"component": "main"})


def run_combined():
    """Run all pipelines in a single process (development mode)."""
    from handlers import create_default_runner
    
    async def main():
        # Start metrics server
        metrics_server = MetricsServer(Config.METRICS_PORT)
        metrics_server.start()
        logger.info(f"Metrics server started on port {Config.METRICS_PORT}")
        
        # Create pipeline runner with default pipelines
        runner = create_default_runner()
        logger.info(f"Loaded {len(runner.pipelines)} pipelines: {[p.name for p in runner.pipelines]}")
        
        # Define message handler
        async def handle_telemetry(data: dict):
            metrics.kafka_messages_consumed.inc()
            runner.process(data)
        
        # Connect to Kafka
        broker = Broker(Config.KAFKA_BOOTSTRAP_SERVERS)
        await broker.connect_consumer(
            topic=Config.KAFKA_TOPIC,
            group_id=Config.KAFKA_GROUP_ID,
            start_from=StartFrom.LATEST,
        )
        
        logger.info(f"Analytics service started (combined mode). Consuming from {Config.KAFKA_TOPIC}...")
        
        try:
            await broker.consume(handle_telemetry)
        except KeyboardInterrupt:
            pass
        finally:
            await broker.disconnect()
            metrics_server.stop()
    
    asyncio.run(main())


def run_worker(worker_name: str):
    """Run a specific worker (production mode with K8s scaling)."""
    from workers.base import run_worker as start_worker
    
    workers = {
        "anomaly": lambda: __import__("workers.anomaly_worker", fromlist=["AnomalyWorker"]).AnomalyWorker(),
        "aggregator": lambda: __import__("workers.aggregation_worker", fromlist=["AggregationWorker"]).AggregationWorker(),
        "alerter": lambda: __import__("workers.alert_worker", fromlist=["AlertWorker"]).AlertWorker(),
    }
    
    if worker_name not in workers:
        logger.error(f"Unknown worker: {worker_name}", extra={"labels": {"worker": worker_name}})
        logger.info(f"Available workers: {list(workers.keys())}")
        exit(1)
    worker = workers[worker_name]()
    logger.info(f"Starting worker: {worker_name}")
    start_worker(worker)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analytics Service")
    parser.add_argument(
        "--worker", "-w",
        type=str,
        choices=["anomaly", "aggregator", "alerter"],
        help="Run a specific worker (for K8s scaling). If not specified, runs combined mode."
    )
    
    args = parser.parse_args()
    
    if args.worker:
        run_worker(args.worker)
    else:
        run_combined()
