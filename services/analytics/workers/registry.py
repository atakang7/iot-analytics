# workers/registry.py
from workers.anomaly_worker import AnomalyWorker
from workers.aggregation_worker import AggregationWorker
from workers.alert_worker import AlertWorker

WORKER_REGISTRY = {
    "anomaly": AnomalyWorker,
    "aggregator": AggregationWorker,
    "alerter": AlertWorker,
}