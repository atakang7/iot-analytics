"""
Anomaly Detection Worker

Standalone worker that detects anomalies in telemetry data.
Scales independently based on Kafka consumer lag.
"""

from workers.base import PipelineWorker, WorkerConfig, run_worker
from core.logging import get_logger

logger = get_logger("worker.anomaly", labels={"component": "anomaly-worker"})
from pipelines import AnomalyDetector
from pipelines.base import Severity
from core.metrics import metrics
from core.config import Config


class AnomalyWorker(PipelineWorker):
    """
    Anomaly detection worker.
    
    Processes telemetry data and detects statistical anomalies
    using Z-score method. Scales 0→N based on Kafka lag.
    """
    
    def __init__(self):
        super().__init__(WorkerConfig(
            name="anomaly-detector",
            topic=Config.KAFKA_TOPIC,
            group_id="analytics-anomaly",
            metrics_port=8082,
            min_replicas=0,
            max_replicas=5,
            lag_threshold=100,
        ))
        
        # The actual pipeline logic - knows nothing about Kafka
        self.detector = AnomalyDetector(
            threshold=3.0,
            min_samples=10,
            absolute_bounds={
                "temperature": (-50, 150),
                "humidity": (0, 100),
                "pressure": (800, 1200),
            }
        )
    
    async def process(self, data: dict) -> None:
        """Process a single telemetry message."""
        result = self.detector.process(data)
        
        # Update metrics
        if result.data.get("is_anomaly"):
            metrics.anomalies_detected.labels(
                device_id=result.data.get("device_id", "unknown"),
                metric_type=result.data.get("metric_type", "unknown")
            ).inc()
        
        # Log alerts
        for alert in result.alerts:
            metrics.alerts_triggered.labels(
                pipeline=self.name,
                severity=alert.severity.value,
                rule=alert.name
            ).inc()
            logger.warning(f"[ANOMALY] [{alert.severity.value.upper()}] {alert.message}", extra={"labels": {"worker": self.name, "severity": alert.severity.value, "rule": alert.name}})


# Entry point when running as standalone worker
if __name__ == "__main__":
    run_worker(AnomalyWorker())
