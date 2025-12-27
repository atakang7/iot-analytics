import pytest
import sys
import os
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.dirname(__file__) + "/..")
from common.models import Threshold
from main import extract_value, compute_kpis


class TestExtractValue:
    def test_extract_scalar(self):
        assert extract_value('{"value": 42.5}', "temperature") == 42.5

    def test_extract_dict_input(self):
        assert extract_value({"value": 100}, "power") == 100

    def test_extract_vibration_rms(self):
        result = extract_value({"x": 3, "y": 4, "z": 0}, "vibration")
        assert result == 5.0  # 3-4-5 triangle

    def test_extract_vibration_all_axes(self):
        result = extract_value({"x": 1, "y": 2, "z": 2}, "vibration")
        assert result == 3.0  # sqrt(1+4+4)

    def test_extract_missing_value_key(self):
        result = extract_value({"x": 1}, "temperature")
        assert result is None


class TestComputeKpis:
    def test_basic_stats(self):
        values = [10, 20, 30, 40, 50]
        kpis = compute_kpis(values, "temperature")
        
        assert kpis["avg"] == 30.0
        assert kpis["min"] == 10
        assert kpis["max"] == 50
        assert kpis["count"] == 5
        assert kpis["range"] == 40

    def test_empty_values(self):
        assert compute_kpis([], "temperature") == {}

    def test_single_value(self):
        kpis = compute_kpis([42], "temperature")
        
        assert kpis["avg"] == 42
        assert kpis["min"] == 42
        assert kpis["max"] == 42
        assert kpis["count"] == 1
        assert "std_dev" not in kpis  # needs 2+ values

    def test_std_dev(self):
        values = [2, 4, 4, 4, 5, 5, 7, 9]
        kpis = compute_kpis(values, "temperature")
        
        assert "std_dev" in kpis
        assert kpis["std_dev"] == pytest.approx(2.0, rel=0.1)

    def test_vibration_specific(self):
        values = [1, 2, 3, 4, 5]
        kpis = compute_kpis(values, "vibration")
        
        assert "rms" in kpis
        assert "crest_factor" in kpis
        assert kpis["rms"] == pytest.approx(3.317, rel=0.01)

    def test_temperature_rate_of_change(self):
        values = [20, 22, 25, 28, 35]
        kpis = compute_kpis(values, "temperature")
        
        assert kpis["rate_of_change"] == 15  # 35 - 20

    def test_power_energy(self):
        values = [100, 150, 200]
        kpis = compute_kpis(values, "power")
        
        assert kpis["energy"] == 450