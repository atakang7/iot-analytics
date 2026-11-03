"""Environment promotion must preserve the identical release, never rebuild."""
import json
import tempfile
import unittest
from pathlib import Path

from release import ReleaseError, SERVICES
from state import load_state, promote, record_dev, save_state, validate_state, verify


def release():
    return {
        "schema": 1,
        "commit": "a" * 40,
        "images": {
            service: f"ghcr.io/example/iot-analytics/{service}@sha256:{i:064x}"
            for i, service in enumerate(sorted(SERVICES), 1)
        },
    }


def blank(name):
    return {"schema": 1, "environment": name, "release": None}


class StateTests(unittest.TestCase):
    def test_record_only_dev(self):
        dev = record_dev(blank("dev"), release())
        self.assertEqual(dev["release"], release())
        with self.assertRaises(ReleaseError):
            record_dev(blank("stage"), release())

    def test_promote_preserves_bytes(self):
        dev = record_dev(blank("dev"), release())
        stage = promote(dev, blank("stage"))
        prod = promote(stage, blank("prod"))
        self.assertEqual(prod["release"], release())

    def test_no_skipping(self):
        dev = record_dev(blank("dev"), release())
        with self.assertRaises(ReleaseError):
            promote(dev, blank("prod"))

    def test_no_empty_promotion(self):
        with self.assertRaises(ReleaseError):
            promote(blank("dev"), blank("stage"))

    def test_bad_environment_rejected(self):
        with self.assertRaises(ReleaseError):
            validate_state({"schema": 1, "environment": "prod", "release": None}, "dev")

    def test_unknown_fields_rejected(self):
        state = blank("dev")
        state["secret"] = "not-allowed"
        with self.assertRaises(ReleaseError):
            validate_state(state, "dev")

    def test_state_files_roundtrip(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "dev.json"
            path.write_text(json.dumps(blank("dev")))
            save_state(path, record_dev(load_state(path, "dev"), release()))
            self.assertEqual(load_state(path, "dev")["release"], release())

    def test_blank_repository_is_valid(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for environment in ("dev", "stage", "prod"):
                (root / f"{environment}.json").write_text(json.dumps(blank(environment)))
            self.assertEqual(set(verify(root, history_ref=None)), {"dev", "stage", "prod"})

    def test_incomplete_state_rejected(self):
        with self.assertRaises(ReleaseError):
            validate_state({"schema": 1, "environment": "dev"}, "dev")


if __name__ == "__main__":
    unittest.main()
