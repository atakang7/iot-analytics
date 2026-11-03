"""Assembly rejects partial or mixed OCI releases."""
import json
import tempfile
import unittest
from pathlib import Path

from assemble import assemble
from release import ReleaseError, SERVICES


def seed(directory: Path):
    for i, service in enumerate(sorted(SERVICES), 1):
        item = {
            "commit": "a" * 40,
            "service": service,
            "image": f"ghcr.io/example/iot-analytics/{service}@sha256:{i:064x}",
        }
        (directory / f"{service}.identity.json").write_text(json.dumps(item))


class AssembleTests(unittest.TestCase):
    def test_six_images_form_one_release(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            seed(root)
            release = assemble(root)
            self.assertEqual(set(release["images"]), SERVICES)
            self.assertEqual(release["commit"], "a" * 40)

    def test_missing_image_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            seed(root)
            (root / "kpi-job.identity.json").unlink()
            with self.assertRaises(ReleaseError):
                assemble(root)

    def test_mixed_commits_are_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            seed(root)
            path = root / "ingestion.identity.json"
            item = json.loads(path.read_text())
            item["commit"] = "b" * 40
            path.write_text(json.dumps(item))
            with self.assertRaises(ReleaseError):
                assemble(root)

    def test_wrong_image_identity_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            seed(root)
            path = root / "ingestion.identity.json"
            item = json.loads(path.read_text())
            item["image"] = "ghcr.io/example/iot-analytics/ingestion:latest"
            path.write_text(json.dumps(item))
            with self.assertRaises(ReleaseError):
                assemble(root)

    def test_duplicate_service_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            seed(root)
            item = json.loads((root / "ingestion.identity.json").read_text())
            (root / "fake.identity.json").write_text(json.dumps(item))
            with self.assertRaises(ReleaseError):
                assemble(root)


if __name__ == "__main__":
    unittest.main()
