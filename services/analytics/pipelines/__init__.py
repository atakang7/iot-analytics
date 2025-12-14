"""
Analysis Pipelines

Pure data processing logic. No knowledge of Kafka, metrics, or infrastructure.
Each pipeline takes data in, returns results out.
"""

from pipelines.base import Pipeline, PipelineResult
from pipelines.anomaly import AnomalyDetector
from pipelines.aggregation import Aggregator
from pipelines.alerting import AlertEvaluator

__all__ = [
    "Pipeline",
    "PipelineResult", 
    "AnomalyDetector",
    "Aggregator",
    "AlertEvaluator",
]
