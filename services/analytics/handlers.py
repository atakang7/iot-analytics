"""
Pipeline Handlers

Connects pure pipelines to infrastructure (Kafka, metrics, DB).
This is the ONLY place pipelines meet infrastructure.
"""

from typing import Optional
from pipelines import Pipeline, PipelineResult, AnomalyDetector, Aggregator, AlertEvaluator
from pipelines.base import Severity

from core.metrics import metrics
from core.logging import get_logger

logger = get_logger("handlers", labels={"component": "handlers"})


class PipelineRunner:
    """
    Runs multiple pipelines on incoming data and handles results.
    
    This class bridges the pure pipelines with infrastructure:
    - Updates Prometheus metrics based on results
    - Can persist results to database
    - Can forward alerts to external systems
    
    Example:
        runner = PipelineRunner()
        runner.add(AnomalyDetector(threshold=3.0))
        runner.add(Aggregator(window_seconds=300))
        
        # In your Kafka consumer:
        async def handle_message(data):
            results = runner.process(data)
            # Results are already tracked in metrics
    """
    
    def __init__(self):
        self.pipelines: list[Pipeline] = []
        self._alert_handlers: list[callable] = []
    
    def add(self, pipeline: Pipeline):
        """Add a pipeline to the runner."""
        self.pipelines.append(pipeline)
    
    def on_alert(self, handler: callable):
        """Register a callback for when alerts are generated."""
        self._alert_handlers.append(handler)
    
    def process(self, data: dict) -> list[PipelineResult]:
        """
        Run all pipelines on the data.
        
        Updates metrics and triggers alert handlers automatically.
        """
        results = []
        
        for pipeline in self.pipelines:
            try:
                result = pipeline.process(data)
                results.append(result)
                
                # Update metrics
                self._update_metrics(result)
                
                # Handle alerts
                if result.has_alerts():
                    self._handle_alerts(result)
                    
            except Exception as e:
                # Don't let one pipeline failure stop others
                logger.error(f"Pipeline {pipeline.name} error: {e}", extra={"labels": {"pipeline": pipeline.name}})
                metrics.pipeline_errors.labels(pipeline=pipeline.name).inc()
        
        return results
    
    def _update_metrics(self, result: PipelineResult):
        """Update Prometheus metrics based on pipeline result."""
        metrics.messages_processed.labels(pipeline=result.pipeline).inc()
        
        # Pipeline-specific metrics
        if result.pipeline == "anomaly_detector":
            if result.data.get("is_anomaly"):
                metrics.anomalies_detected.labels(
                    device_id=result.data.get("device_id", "unknown"),
                    metric_type=result.data.get("metric_type", "unknown")
                ).inc()
        
        elif result.pipeline == "aggregator":
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
    
    def _handle_alerts(self, result: PipelineResult):
        """Process alerts from a pipeline result."""
        for alert in result.alerts:
            # Update metrics
            metrics.alerts_triggered.labels(
                pipeline=result.pipeline,
                severity=alert.severity.value,
                rule=alert.name
            ).inc()
            
            # Log the alert
            print(f"[ALERT] [{alert.severity.value.upper()}] {alert.name}: {alert.message}")
            
            # Call registered handlers
            for handler in self._alert_handlers:
                try:
                    handler(alert)
                except Exception as e:
                    print(f"Alert handler error: {e}")


def create_default_runner() -> PipelineRunner:
    """
    Create a runner with default pipelines configured.
    
    Customize this for your use case.
    """
    runner = PipelineRunner()
    
    # Anomaly detection
    anomaly = AnomalyDetector(
        threshold=3.0,
        min_samples=10,
        absolute_bounds={
            "temperature": (-50, 150),  # Celsius
            "humidity": (0, 100),        # Percentage
            "pressure": (800, 1200),     # hPa
        }
    )
    runner.add(anomaly)
    
    # Aggregation (5 minute window)
    aggregator = Aggregator(window_seconds=300)
    runner.add(aggregator)
    
    # Alert rules
    alerter = AlertEvaluator()
    alerter.add_threshold_rule(
        name="high_temperature",
        metric_type="temperature",
        threshold=80,
        severity=Severity.WARNING,
        message="Temperature exceeds 80°C"
    )
    alerter.add_threshold_rule(
        name="critical_temperature", 
        metric_type="temperature",
        threshold=100,
        severity=Severity.CRITICAL,
        message="Temperature exceeds 100°C - CRITICAL"
    )
    alerter.add_range_rule(
        name="humidity_out_of_range",
        metric_type="humidity",
        min_value=20,
        max_value=80,
        severity=Severity.WARNING,
        message="Humidity outside optimal range"
    )
    runner.add(alerter)
    
    return runner
