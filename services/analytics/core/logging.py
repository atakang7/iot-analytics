"""
Centralized Logging Setup

- Standardizes logging format for all services
- Ensures logs are structured for Loki (JSON per line)
- Usage: from core.logging import get_logger
"""

import logging
import os
import sys
import json
from datetime import datetime

class LokiJsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "funcName": record.funcName,
            "lineNo": record.lineno,
        }
        # Add extra fields if present (e.g., labels)
        if hasattr(record, "labels"):
            log_record["labels"] = record.labels
        return json.dumps(log_record)

def get_logger(name=None, level=None, labels=None):
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        formatter = LokiJsonFormatter()
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    logger.propagate = False
    logger.setLevel(level or os.getenv("LOG_LEVEL", "INFO"))
    # Attach labels for Loki if provided
    if labels:
        def filter(record):
            record.labels = labels
            return True
        logger.addFilter(filter)
    return logger
