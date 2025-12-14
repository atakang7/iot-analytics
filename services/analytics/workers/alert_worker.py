"""
Alert Evaluation Worker

Standalone worker that evaluates alert rules against telemetry data.
Scales independently based on Kafka consumer lag.
"""

from workers.base import PipelineWorker, WorkerConfig, run_worker
from pipelines import AlertEvaluator
from pipelines.base import Severity
from core.metrics import metrics
from core.config import Config


class AlertWorker(PipelineWorker):
    """
    Alert evaluation worker.
    
    Evaluates configurable rules against incoming telemetry
    and generates alerts when conditions are met.
    """
    
    def __init__(self):
        super().__init__(WorkerConfig(
            name="alerter",
            topic=Config.KAFKA_TOPIC,
            group_id="analytics-alerter",
            metrics_port=8084,
            min_replicas=1,  # Always keep at least 1 for alerts
            max_replicas=3,
            lag_threshold=50,  # Alert processing should be fast
        ))

        self.evaluator = AlertEvaluator()
        self._setup_rules()
        from core.logging import get_logger
        self.logger = get_logger("worker.alert", labels={"component": "alert-worker"})
    
    def _setup_rules(self):
        """Configure alert rules. In production, load from config/DB."""
        
        # Temperature alerts
        self.evaluator.add_threshold_rule(
            name="high_temperature",
            metric_type="temperature",
            threshold=80,
            severity=Severity.WARNING,
            message="Temperature exceeds 80°C"
        )
        self.evaluator.add_threshold_rule(
            name="critical_temperature",
            metric_type="temperature",
            threshold=100,
            severity=Severity.CRITICAL,
            message="CRITICAL: Temperature exceeds 100°C"
        )
        
        # Humidity alerts
        self.evaluator.add_range_rule(
            name="humidity_out_of_range",
            metric_type="humidity",
            min_value=20,
            max_value=80,
            severity=Severity.WARNING,
            message="Humidity outside optimal range (20-80%)"
        )
        
        # Pressure alerts
        self.evaluator.add_threshold_rule(
            name="low_pressure",
            metric_type="pressure",
            threshold=900,
            operator="<",
            severity=Severity.WARNING,
            message="Pressure below 900 hPa"
        )
    
    async def process(self, data: dict) -> None:
        """Evaluate rules against incoming data."""
        result = self.evaluator.process(data)

        for alert in result.alerts:
            # Update metrics
            metrics.alerts_triggered.labels(
                pipeline=self.name,
                severity=alert.severity.value,
                rule=alert.name
            ).inc()

            # Log alert (in production: send to PagerDuty, Slack, etc.)
            self.logger.warning(f"[ALERT] [{alert.severity.value.upper()}] {alert.name}: {alert.message} (device: {alert.source})", extra={"labels": {"worker": self.name, "severity": alert.severity.value, "rule": alert.name}})

            # TODO: In production, you'd publish to an alerts topic
            # await self.publish_alert(alert)


if __name__ == "__main__":
    run_worker(AlertWorker())
