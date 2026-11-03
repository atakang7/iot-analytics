"""Environment-backed runtime configuration.

Importing a worker must not require production secrets. Database connections
validate credentials when actually opened, so isolated unit tests remain safe.
"""
import os

SERVICE_NAME = os.getenv("SERVICE_NAME", "unknown")
KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "localhost:9092")
KAFKA_TELEMETRY_TOPIC = os.getenv("KAFKA_TELEMETRY_TOPIC", "iot.telemetry")
KAFKA_ALERTS_TOPIC = os.getenv("KAFKA_ALERTS_TOPIC", "iot.alerts")

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "iot")
DB_USER = os.getenv("DB_USER", "iot")
DB_PASSWORD = os.getenv("DB_PASSWORD")

METRICS_PORT = int(os.getenv("METRICS_PORT", "8000"))
PUSHGATEWAY_URL = os.getenv("PUSHGATEWAY_URL", "http://localhost:9091")
CONSUMER_GROUP = os.getenv("CONSUMER_GROUP", "default-group")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
