import json
import logging
import sys
from datetime import datetime, timezone

from common.config import LOG_LEVEL, SERVICE_NAME


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_obj = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": SERVICE_NAME,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if hasattr(record, "extra"):
            log_obj["extra"] = record.extra
        if record.exc_info:
            log_obj["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_obj)


def get_logger(name: str = None) -> logging.Logger:
    logger = logging.getLogger(name or SERVICE_NAME)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        logger.setLevel(LOG_LEVEL.upper())
        logger.propagate = False
    return logger
