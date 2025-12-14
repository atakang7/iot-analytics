"""
Configuration

Load settings from environment variables.
"""

import os


class Config:
    # Postgres
    POSTGRES_URL = os.getenv(
        "POSTGRES_URL",
        f"postgresql://{os.getenv('POSTGRES_USER', 'iot')}:{os.getenv('POSTGRES_PASSWORD', 'iot123')}@{os.getenv('POSTGRES_HOST', 'localhost')}:{os.getenv('POSTGRES_PORT', '5432')}/{os.getenv('POSTGRES_DB', 'devices')}"
    )
    
    # Kafka
    KAFKA_BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092")
    KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "telemetry")
    KAFKA_GROUP_ID = os.getenv("KAFKA_GROUP_ID", "analytics-group")
    
    # Metrics
    METRICS_PORT = int(os.getenv("METRICS_PORT", "9090"))
