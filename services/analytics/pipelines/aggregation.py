"""
Aggregation Pipeline

Computes rolling statistics and aggregations over telemetry data.
No infrastructure dependencies - pure data processing.
"""

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional
from pipelines.base import Pipeline, PipelineResult, Severity


@dataclass
class TimeWindow:
    """A time-based window of values."""
    window_seconds: int
    values: list = field(default_factory=list)
    timestamps: list = field(default_factory=list)
    
    def add(self, value: float, timestamp: Optional[datetime] = None):
        ts = timestamp or datetime.utcnow()
        self.values.append(value)
        self.timestamps.append(ts)
        self._prune()
    
    def _prune(self):
        """Remove values outside the window."""
        cutoff = datetime.utcnow() - timedelta(seconds=self.window_seconds)
        while self.timestamps and self.timestamps[0] < cutoff:
            self.timestamps.pop(0)
            self.values.pop(0)
    
    @property
    def count(self) -> int:
        self._prune()
        return len(self.values)
    
    @property
    def sum(self) -> float:
        self._prune()
        return sum(self.values) if self.values else 0.0
    
    @property
    def mean(self) -> float:
        self._prune()
        return self.sum / self.count if self.count > 0 else 0.0
    
    @property
    def min(self) -> float:
        self._prune()
        return min(self.values) if self.values else 0.0
    
    @property
    def max(self) -> float:
        self._prune()
        return max(self.values) if self.values else 0.0


class Aggregator(Pipeline):
    """
    Aggregates telemetry data over time windows.
    
    Computes rolling statistics per device/metric:
    - Count of readings
    - Sum, mean, min, max
    - Rate (readings per second)
    
    Example:
        aggregator = Aggregator(window_seconds=300)  # 5 min window
        for data in telemetry_stream:
            result = aggregator.process(data)
            print(f"5-min avg: {result.data['mean']}")
    """
    
    def __init__(self, window_seconds: int = 300):
        """
        Args:
            window_seconds: Size of the rolling window in seconds
        """
        self.window_seconds = window_seconds
        
        # Track windows per device per metric
        self._windows: dict[str, dict[str, TimeWindow]] = defaultdict(
            lambda: defaultdict(lambda: TimeWindow(self.window_seconds))
        )
        
        # Track global stats across all devices
        self._global_counts: dict[str, int] = defaultdict(int)
        self._device_counts: dict[str, int] = defaultdict(int)
    
    @property
    def name(self) -> str:
        return "aggregator"
    
    def process(self, data: dict) -> PipelineResult:
        device_id = data.get("device_id", "unknown")
        metric_type = data.get("metric_type", "unknown")
        value = float(data.get("value", 0))
        
        # Parse timestamp if provided
        timestamp = None
        if "timestamp" in data:
            try:
                timestamp = datetime.fromisoformat(data["timestamp"].replace("Z", "+00:00"))
            except (ValueError, AttributeError):
                timestamp = datetime.utcnow()
        
        # Update window
        window = self._windows[device_id][metric_type]
        window.add(value, timestamp)
        
        # Update counts
        self._global_counts[metric_type] += 1
        self._device_counts[device_id] += 1
        
        # Compute aggregations
        result_data = {
            "device_id": device_id,
            "metric_type": metric_type,
            "window_seconds": self.window_seconds,
            "count": window.count,
            "sum": window.sum,
            "mean": window.mean,
            "min": window.min,
            "max": window.max,
            "rate_per_second": window.count / self.window_seconds if self.window_seconds > 0 else 0,
            "total_readings": self._global_counts[metric_type],
            "device_total_readings": self._device_counts[device_id],
        }
        
        return PipelineResult(
            pipeline=self.name,
            data=result_data
        )
    
    def get_summary(self) -> dict:
        """Get summary of all tracked devices/metrics."""
        summary = {
            "total_devices": len(self._device_counts),
            "total_readings": sum(self._global_counts.values()),
            "by_metric": dict(self._global_counts),
            "by_device": dict(self._device_counts),
        }
        return summary
    
    def reset(self):
        """Clear all accumulated data."""
        self._windows.clear()
        self._global_counts.clear()
        self._device_counts.clear()
