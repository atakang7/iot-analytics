import json
import logging
import sys
from datetime import datetime, timezone
from typing import Any

from common.config import SERVICE_NAME


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_obj = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "service": SERVICE_NAME,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add extra fields
        if hasattr(record, "extra"):
            log_obj["extra"] = record.extra

        # Add exception info
        if record.exc_info:
            log_obj["exception"] = self.formatException(record.exc_info)

        return json.dumps(log_obj)


def get_logger(name: str = None) -> logging.Logger:
    logger = logging.getLogger(name or SERVICE_NAME)
    
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
        logger.propagate = False

    return logger


class LoggerAdapter(logging.LoggerAdapter):
    """Logger with extra context fields."""
    
    def process(self, msg, kwargs):
        extra = kwargs.get("extra", {})
        extra.update(self.extra)
        kwargs["extra"] = extra
        return msg, kwargs


def get_logger_with_context(name: str = None, **context) -> LoggerAdapter:
    """Get logger with persistent context fields."""
    logger = get_logger(name)
    return LoggerAdapter(logger, context)


# Convenience functions
_default_logger = None

def _get_default():
    global _default_logger
    if _default_logger is None:
        _default_logger = get_logger()
    return _default_logger

def info(msg: str, **extra):
    _get_default().info(msg, extra={"extra": extra} if extra else {})

def warning(msg: str, **extra):
    _get_default().warning(msg, extra={"extra": extra} if extra else {})

def error(msg: str, **extra):
    _get_default().error(msg, extra={"extra": extra} if extra else {})

def debug(msg: str, **extra):
    _get_default().debug(msg, extra={"extra": extra} if extra else {})
