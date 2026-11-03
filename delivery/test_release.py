"""Fail-closed tests for the release boundary."""
import json
import tempfile
import unittest
from pathlib import Path

from release import SERVICES, ReleaseError, helm_values, load_release, validate_release


def example():
    return {
        "schema": 1,
        "commit": "a" * 40,
        "images": {
            name: f"ghcr.io/example/iot-analytics/{name}@sha256:{i:064x}"
            for i, name in enumerate(sorted(SERVICES), 1)
        },
    }


class ReleaseTests(unittest.TestCase):
    def test_complete_release(self):
        release = example()
        self.assertEqual(validate_release(release), release)
        self.assertEqual(helm_values(release)["apps"]["images"], release["images"])

    def test_reject_incomplete(self):
        release = example()
        release["images"].pop("kpi-job")
        with self.assertRaises(ReleaseError):
            validate_release(release)

    def test_reject_mutable_tag(self):
        release = example()
        release["images"]["ingestion"] = "ghcr.io/example/iot-analytics/ingestion:latest"
        with self.assertRaises(ReleaseError):
            validate_release(release)

    def test_reject_wrong_service(self):
        release = example()
        release["images"]["ingestion"] = release["images"]["device-registry"]
        with self.assertRaises(ReleaseError):
            validate_release(release)

    def test_reject_unknown_fields(self):
        release = example()
        release["credentials"] = "not-a-place-for-secrets"
        with self.assertRaises(ReleaseError):
            validate_release(release)

    def test_reject_invalid_sha(self):
        release = example()
        release["commit"] = "main"
        with self.assertRaises(ReleaseError):
            validate_release(release)

    def test_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "release.json"
            path.write_text(json.dumps(example()), encoding="utf-8")
            self.assertEqual(load_release(path), example())

    def test_reject_malformed_json(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "release.json"
            path.write_text("{broken", encoding="utf-8")
            with self.assertRaises(ReleaseError):
                load_release(path)


if __name__ == "__main__":
    unittest.main()
