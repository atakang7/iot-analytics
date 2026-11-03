"""Release controls must fail closed before touching cluster or registry."""
import unittest
from pathlib import Path
from unittest.mock import patch

from release import ReleaseError, SERVICES
from rollout import (
    validate_target, helm_commands, image_signature_commands,
    verify_rendered, desired_release,
)


def fixture():
    return {
        "schema": 1, "commit": "a" * 40,
        "images": {
            name: f"ghcr.io/example/iot-analytics/{name}@sha256:{i:064x}"
            for i, name in enumerate(sorted(SERVICES), 1)
        },
    }


def template_release(release):
    lines = []
    for name in sorted(SERVICES):
        if name == "kpi-job":
            lines.append(
                f"kind: CronJob\nmetadata:\n  name: {name}\nspec:\n"
                f"  jobTemplate:\n    spec:\n      template:\n"
                f"        spec:\n          containers:\n"
                f"            - name: {name}\n              image: {release['images'][name]}"
            )
        else:
            lines.append(
                f"kind: Deployment\nmetadata:\n  name: {name}\nspec:\n"
                f"  template:\n    spec:\n      containers:\n"
                f"        - name: {name}\n          image: {release['images'][name]}"
            )
    return "\n---\n".join(lines)


class RolloutTests(unittest.TestCase):
    def test_explicit_context_consent(self):
        validate_target("dev", "iot-apps", "kind-iot", "example/iot-analytics",
                        confirm="dev:iot-apps@kind-iot", apply=True)
        with self.assertRaises(ReleaseError):
            validate_target("prod", "iot-apps", "kind-iot", "example/iot-analytics",
                            confirm="dev:iot-apps@kind-iot", apply=True)

    def test_system_namespace_rejected(self):
        for name in ("default", "kube-system", "kube-public", "kube-node-lease"):
            with self.subTest(name=name), self.assertRaises(ReleaseError):
                validate_target("dev", name, "kind-iot", "example/iot-analytics")

    def test_shell_metacharacters_rejected(self):
        with self.assertRaises(ReleaseError):
            validate_target("dev", "iot-apps;echo", "kind-iot",
                            "example/iot-analytics")
        with self.assertRaises(ReleaseError):
            validate_target("dev", "iot-apps", "kind-iot;echo",
                            "example/iot-analytics")

    def test_application_only_helm_release(self):
        name, template, dryrun, upgrade = helm_commands(
            "dev", "iot-apps", "kind-iot",
            Path("/tmp/values.json"), Path("/tmp/manifests.yaml")
        )
        self.assertEqual(name, "iot-apps-dev")
        self.assertIn("iot-helm/charts/apps", " ".join(template))
        self.assertIn("--dry-run=server", dryrun)
        self.assertIn("--atomic", upgrade)
        self.assertIn("--wait", upgrade)
        self.assertNotIn("--set", upgrade)

    def test_only_exact_images_are_renderable(self):
        release = fixture()
        docs = verify_rendered(template_release(release), release)
        self.assertEqual(len(docs), 6)

    def test_mutable_image_is_rejected(self):
        release = fixture()
        rendered = template_release(release)
        rendered = rendered.replace(release["images"]["ingestion"],
                                    "ghcr.io/example/iot-analytics/ingestion:latest")
        with self.assertRaisesRegex(ReleaseError, "exactly match"):
            verify_rendered(rendered, release)

    def test_buildconfig_is_rejected(self):
        release = fixture()
        rendered = template_release(release) + "\n---\nkind: BuildConfig\nmetadata:\n  name: admin\n"
        with self.assertRaisesRegex(ReleaseError, "privileged"):
            verify_rendered(rendered, release)

    def test_unexpected_deployment_is_rejected(self):
        release = fixture()
        rendered = template_release(release) + (
            "\n---\nkind: Deployment\nmetadata:\n  name: unknown\n"
            "spec:\n  template:\n    spec:\n      containers:\n"
            "        - name: unknown\n          image: dummy\n"
        )
        with self.assertRaises(ReleaseError):
            verify_rendered(rendered, release)

    def test_signatures_are_tied_to_exact_workflow_and_digest(self):
        release = fixture()
        commands = image_signature_commands(release, "example/iot-analytics")
        self.assertEqual(len(commands), 6)
        for command in commands:
            self.assertIn("--certificate-identity", command)
            self.assertIn("https://token.actions.githubusercontent.com", command)
            self.assertIn("publish.yaml@refs/heads/main", " ".join(command))
            self.assertTrue(command[-1].startswith("ghcr.io/"))

    def test_no_unrecorded_release(self):
        with patch("rollout.verify", return_value={
            "dev": {"schema": 1, "environment": "dev", "release": None}
        }):
            with self.assertRaisesRegex(ReleaseError, "no published release"):
                desired_release("dev", "example/iot-analytics")

    def test_foreign_registry_rejected(self):
        release = fixture()
        with patch("rollout.verify", return_value={
            "dev": {"schema": 1, "environment": "dev", "release": release}
        }):
            with self.assertRaisesRegex(ReleaseError, "expected repository"):
                desired_release("dev", "attacker/other-repo")


if __name__ == "__main__":
    unittest.main()
