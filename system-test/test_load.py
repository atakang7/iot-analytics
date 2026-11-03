"""Checks for the benchmark tool that require no network or cluster."""
import unittest
from datetime import datetime, timezone
from load import make_payload, percentile, validate_url


class LoadTest(unittest.TestCase):
    def test_payload_matches_java_and_python_contract(self):
        base = datetime(2026, 11, 3, 10, 20, tzinfo=timezone.utc)
        first = make_payload("bench-run", 0, base)
        second = make_payload("bench-run", 1, base)
        self.assertEqual(first["value"], {"value": 20.0})
        self.assertEqual(first["sensorType"], "temperature")
        self.assertEqual(first["unit"], "celsius")
        self.assertNotEqual(first["timestamp"], second["timestamp"])
        self.assertTrue(first["timestamp"].endswith("Z"))

    def test_remote_urls_are_opt_in_and_use_tls(self):
        self.assertEqual(validate_url("http://127.0.0.1:8081/telemetry"),
                         "http://127.0.0.1:8081/telemetry")
        with self.assertRaisesRegex(ValueError, "allow-remote"):
            validate_url("https://example.com/telemetry")
        with self.assertRaisesRegex(ValueError, "HTTPS"):
            validate_url("http://example.com/telemetry", allow_remote=True)
        with self.assertRaisesRegex(ValueError, "credentials"):
            validate_url("http://user:secret@127.0.0.1:8081/telemetry")

    def test_latency_nearest_rank_including_empty(self):
        self.assertIsNone(percentile([], 0.95))
        self.assertEqual(percentile([10, 30, 20, 40], 0.50), 20)
        self.assertEqual(percentile([10, 30, 20, 40], 0.95), 40)


if __name__ == "__main__":
    unittest.main()
