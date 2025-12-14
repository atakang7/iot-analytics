"""
Prometheus Metrics Server

Simple HTTP server that exposes /metrics endpoint.
"""


from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
from core.logging import get_logger

logger = get_logger("core.metrics", labels={"component": "metrics"})


class _Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, *args):
        pass


class Metrics:
    """Container for all application metrics."""
    
    # Pipeline metrics
    messages_processed = Counter(
        "analytics_messages_processed_total",
        "Total messages processed by pipeline",
        ["pipeline"]
    )
    
    pipeline_errors = Counter(
        "analytics_pipeline_errors_total", 
        "Total pipeline processing errors",
        ["pipeline"]
    )
    
    # Anomaly detection metrics
    anomalies_detected = Counter(
        "analytics_anomalies_detected_total",
        "Total anomalies detected",
        ["device_id", "metric_type"]
    )
    
    # Aggregation metrics
    aggregation_mean = Gauge(
        "analytics_aggregation_mean",
        "Rolling mean value",
        ["device_id", "metric_type"]
    )
    
    aggregation_count = Gauge(
        "analytics_aggregation_count",
        "Rolling count of readings",
        ["device_id", "metric_type"]
    )
    
    # Alert metrics
    alerts_triggered = Counter(
        "analytics_alerts_triggered_total",
        "Total alerts triggered",
        ["pipeline", "severity", "rule"]
    )
    
    # Kafka metrics
    kafka_messages_consumed = Counter(
        "analytics_kafka_messages_consumed_total",
        "Total Kafka messages consumed"
    )
    
    kafka_consumer_lag = Gauge(
        "analytics_kafka_consumer_lag",
        "Kafka consumer lag"
    )


# Global metrics instance
metrics = Metrics()


class MetricsServer:
    def __init__(self, port: int = 9090):
        self.port = port
        self._server = None
        self._thread = None
    
    def start(self):
        self._server = HTTPServer(("0.0.0.0", self.port), _Handler)
        self._thread = Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()
    
    def stop(self):
        if self._server:
            self._server.shutdown()
