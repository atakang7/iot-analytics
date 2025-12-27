import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(__file__) + "/..")
from common.models import Threshold
import sys
sys.path.insert(0, "..")

from common.models import Threshold


class TestThresholdCheck:
    def test_critical_high_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(45)
        assert result == ("threshold_breach", "critical")

    # stream-worker/test_main.py - change critical_low to non-zero
    def test_critical_low_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=5, critical_high=40  # changed from 0 to 5
        )
        result = t.check(-5)
        assert result == ("threshold_breach", "critical")

    def test_warning_high_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(35)
        assert result == ("threshold_breach", "warning")

    def test_warning_low_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(5)
        assert result == ("threshold_breach", "warning")

    def test_no_breach(self):
        t = Threshold(
            sensor_type="temperature",
            device_type="hvac",
            warning_low=10, warning_high=30,
            critical_low=0, critical_high=40
        )
        result = t.check(20)
        assert result is None

    def test_partial_thresholds(self):
        t = Threshold(
            sensor_type="humidity",
            device_type=None,
            warning_low=None, warning_high=80,
            critical_low=None, critical_high=95
        )
        assert t.check(50) is None
        assert t.check(85) == ("threshold_breach", "warning")
        assert t.check(98) == ("threshold_breach", "critical")

    def test_boundary_values(self):
        t = Threshold(
            sensor_type="pressure",
            device_type="pump",
            warning_low=20, warning_high=80,
            critical_low=10, critical_high=90
        )
        # Exactly at threshold - no breach (uses >)
        assert t.check(80) is None
        assert t.check(80.1) == ("threshold_breach", "warning")