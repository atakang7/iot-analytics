"""
Aggregation Worker

Standalone worker that computes rolling statistics over telemetry data.
Scales independently based on Kafka consumer lag.
"""

from workers.base import PipelineWorker, WorkerConfig, run_worker
from core.logging import get_logger

logger = get_logger("worker.aggregation", labels={"component": "aggregation-worker"})
from pipelines import Aggregator
from core.metrics import metrics
from core.config import Config


class AggregationWorker(PipelineWorker):
    """
    Aggregation worker.
    
    Computes rolling statistics (mean, min, max, count) over
    a time window. Useful for dashboards and trend analysis.
    """
    
    def __init__(self, window_seconds: int = 300):
        super().__init__(WorkerConfig(
            name="aggregator",
            topic=Config.KAFKA_TOPIC,
            group_id="analytics-aggregator",
            metrics_port=8083,
            min_replicas=0,
            max_replicas=3,
            lag_threshold=200,
        ))
        
        self.aggregator = Aggregator(window_seconds=window_seconds)
    
    async def process(self, data: dict) -> None:
        """Process a single telemetry message."""
        result = self.aggregator.process(data)
        
        # Update Prometheus gauges with rolling stats
        device_id = result.data.get("device_id", "unknown")
        metric_type = result.data.get("metric_type", "unknown")
        
        metrics.aggregation_mean.labels(
            device_id=device_id,
            metric_type=metric_type
        ).set(result.data.get("mean", 0))
        
        metrics.aggregation_count.labels(
            device_id=device_id,
            metric_type=metric_type
        ).set(result.data.get("count", 0))


if __name__ == "__main__":
    run_worker(AggregationWorker())
