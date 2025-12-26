from prometheus_client import Counter, Gauge, Histogram, start_http_server, push_to_gateway, REGISTRY
from common.config import METRICS_PORT, PUSHGATEWAY_URL


def start_metrics_server(port: int = None):
    start_http_server(port or METRICS_PORT)


def push_metrics(job_name: str):
    push_to_gateway(PUSHGATEWAY_URL, job=job_name, registry=REGISTRY)


# Telemetry worker metrics
telemetry_received = Counter(
    "iot_telemetry_received_total",
    "Total telemetry messages received",
    ["device_type", "sensor_type"]
)

telemetry_stored = Counter(
    "iot_telemetry_stored_total",
    "Total telemetry messages stored",
    ["device_type"]
)

# Stream worker metrics
alerts_generated = Counter(
    "iot_alerts_generated_total",
    "Total alerts generated",
    ["alert_type", "severity"]
)

threshold_checks = Counter(
    "iot_threshold_checks_total",
    "Total threshold checks performed",
    ["sensor_type"]
)

# Alert worker metrics
alerts_stored = Counter(
    "iot_alerts_stored_total",
    "Total alerts stored to DB",
    ["alert_type", "severity"]
)

alerts_active = Gauge(
    "iot_alerts_active",
    "Currently active unacknowledged alerts",
    ["device_id", "alert_type"]
)

# KPI job metrics
kpis_computed = Counter(
    "iot_kpis_computed_total",
    "Total KPIs computed",
    ["kpi_name"]
)

kpi_job_duration = Histogram(
    "iot_kpi_job_duration_seconds",
    "KPI job duration"
)

# General
processing_errors = Counter(
    "iot_processing_errors_total",
    "Processing errors",
    ["worker", "error_type"]
)
