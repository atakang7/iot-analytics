import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(__file__) + "/..")
from common.models import Threshold
from datetime import datetime
from main import parse_alert

class TestParseAlert:
    def test_parse_alert_full(self): 
        msg = {
            "createdAt": "2024-01-15T10:30:00Z",
            "alertId": "alert-001",
            "deviceId": "device-001",
            "deviceType": "hvac",
            "alertType": "threshold_breach",
            "severity": "critical",
            "message": "Temperature exceeded limit",
            "threshold": 80.0,
            "value": 85.5
        }
        result = parse_alert(msg)
        
        assert result["alert_id"] == "alert-001"
        assert result["device_id"] == "device-001"
        assert result["device_type"] == "hvac"
        assert result["alert_type"] == "threshold_breach"
        assert result["severity"] == "critical"
        assert result["message"] == "Temperature exceeded limit"
        assert result["threshold"] == 80.0
        assert result["value"] == 85.5
        assert isinstance(result["created_at"], datetime)

    def test_parse_alert_optional_fields_missing(self):
        msg = {
            "createdAt": "2024-01-15T10:30:00Z",
            "alertId": "alert-002",
            "deviceId": "device-002",
            "deviceType": "motor",
            "alertType": "stuck_sensor",
            "severity": "warning",
            "message": "Sensor stuck"
        }
        result = parse_alert(msg)
        
        assert result["alert_id"] == "alert-002"
        assert result["threshold"] is None
        assert result["value"] is None

    def test_parse_alert_timestamp_conversion(self):
        msg = {
            "createdAt": "2024-06-20T14:45:30Z",
            "alertId": "a1",
            "deviceId": "d1",
            "deviceType": "pump",
            "alertType": "rapid_change",
            "severity": "warning",
            "message": "test"
        }
        result = parse_alert(msg)
        
        assert result["created_at"].year == 2024
        assert result["created_at"].month == 6
        assert result["created_at"].day == 20
        assert result["created_at"].hour == 14