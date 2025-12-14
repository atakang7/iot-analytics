"""
Anomaly Detection Pipeline

Detects anomalies in telemetry data using simple statistical methods.
No infrastructure dependencies - pure data processing.
"""

from collections import defaultdict
from dataclasses import dataclass, field
from typing import Optional
from pipelines.base import Pipeline, PipelineResult, Alert, Severity


@dataclass
class Stats:
    """Running statistics for a metric."""
    count: int = 0
    sum: float = 0.0
    sum_sq: float = 0.0
    min: float = float('inf')
    max: float = float('-inf')
    
    @property
    def mean(self) -> float:
        return self.sum / self.count if self.count > 0 else 0.0
    
    @property
    def variance(self) -> float:
        if self.count < 2:
            return 0.0
        return (self.sum_sq / self.count) - (self.mean ** 2)
    
    @property
    def std(self) -> float:
        return self.variance ** 0.5
    
    def update(self, value: float):
        self.count += 1
        self.sum += value
        self.sum_sq += value ** 2
        self.min = min(self.min, value)
        self.max = max(self.max, value)


class AnomalyDetector(Pipeline):
    """
    Detects anomalies using Z-score method.
    
    A value is anomalous if it's more than `threshold` standard deviations
    from the rolling mean for that device/metric combination.
    
    Example:
        detector = AnomalyDetector(threshold=3.0)
        result = detector.process({
            "device_id": "sensor-1",
            "metric_type": "temperature",
            "value": 150.0  # Way above normal
        })
        if result.has_alerts():
            print(result.alerts[0].message)
    """
    
    def __init__(
        self,
        threshold: float = 3.0,
        min_samples: int = 10,
        absolute_bounds: Optional[dict] = None
    ):
        """
        Args:
            threshold: Z-score threshold for anomaly detection
            min_samples: Minimum samples before detecting anomalies
            absolute_bounds: Dict of {metric_type: (min, max)} for hard limits
        """
        self.threshold = threshold
        self.min_samples = min_samples
        self.absolute_bounds = absolute_bounds or {}
        
        # Track stats per device per metric: {device_id: {metric_type: Stats}}
        self._stats: dict[str, dict[str, Stats]] = defaultdict(lambda: defaultdict(Stats))
    
    @property
    def name(self) -> str:
        return "anomaly_detector"
    
    def process(self, data: dict) -> PipelineResult:
        device_id = data.get("device_id", "unknown")
        metric_type = data.get("metric_type", "unknown")
        value = float(data.get("value", 0))
        
        alerts = []
        result_data = {
            "device_id": device_id,
            "metric_type": metric_type,
            "value": value,
            "is_anomaly": False,
        }
        
        # Check absolute bounds first
        if metric_type in self.absolute_bounds:
            min_val, max_val = self.absolute_bounds[metric_type]
            if value < min_val or value > max_val:
                alerts.append(Alert(
                    name="absolute_bound_violation",
                    message=f"{metric_type} value {value} outside bounds [{min_val}, {max_val}]",
                    severity=Severity.CRITICAL,
                    source=device_id,
                    value=value,
                    threshold=(min_val, max_val)
                ))
                result_data["is_anomaly"] = True
        
        # Get or create stats for this device/metric
        stats = self._stats[device_id][metric_type]
        
        # Check Z-score if we have enough samples
        if stats.count >= self.min_samples and stats.std > 0:
            z_score = abs(value - stats.mean) / stats.std
            result_data["z_score"] = z_score
            result_data["mean"] = stats.mean
            result_data["std"] = stats.std
            
            if z_score > self.threshold:
                alerts.append(Alert(
                    name="statistical_anomaly",
                    message=f"{metric_type} value {value:.2f} is {z_score:.1f} std devs from mean {stats.mean:.2f}",
                    severity=Severity.WARNING if z_score < self.threshold * 1.5 else Severity.CRITICAL,
                    source=device_id,
                    value=value,
                    threshold=self.threshold
                ))
                result_data["is_anomaly"] = True
        
        # Update running stats
        stats.update(value)
        result_data["sample_count"] = stats.count
        
        return PipelineResult(
            pipeline=self.name,
            data=result_data,
            alerts=alerts
        )
    
    def get_stats(self, device_id: str, metric_type: str) -> Optional[Stats]:
        """Get current stats for a device/metric (for testing/debugging)."""
        if device_id in self._stats and metric_type in self._stats[device_id]:
            return self._stats[device_id][metric_type]
        return None
    
    def reset(self):
        """Clear all accumulated stats."""
        self._stats.clear()
