#!/usr/bin/env python3
"""Validate security and completeness of the real Kubernetes observation path."""
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
OBS = ROOT / "platform/observability"
REQUIRED = {"ingestion", "device-registry", "telemetry-worker", "stream-worker", "alert-worker"}


def indexed(path):
    docs = [item for item in yaml.safe_load_all(path.read_text()) if item]
    objects = {(item["kind"], item["metadata"]["name"]): item for item in docs}
    assert len(objects) == len(docs), "duplicate Kubernetes resource"
    return objects


def main():
    objects = indexed(OBS / "kind/stack.yaml")
    for name in ("prometheus", "alertmanager", "loki", "grafana"):
        service = objects[("Service", name)]
        assert service["spec"].get("type", "ClusterIP") == "ClusterIP", name
        deployment = objects[("Deployment", name)]
        containers = deployment["spec"]["template"]["spec"]["containers"]
        assert len(containers) == 1, name
        app = containers[0]
        image = app["image"]
        assert ":latest" not in image and ":" in image, name
        assert app["securityContext"]["runAsNonRoot"] is True, name
        assert app["securityContext"]["readOnlyRootFilesystem"] is True, name
        assert app["securityContext"]["allowPrivilegeEscalation"] is False, name
        assert "ALL" in app["securityContext"]["capabilities"]["drop"], name
        for section in ("limits", "requests"):
            assert {"cpu", "memory"} <= set(app["resources"][section]), name

    collector = indexed(OBS / "collector/kind.yaml")
    assert all(kind not in ("ClusterRole", "ClusterRoleBinding") for kind, _ in collector)
    role = collector[("Role", "iot-log-reader")]
    permitted = {resource for rule in role["rules"] for resource in rule["resources"]}
    assert permitted == {"pods", "pods/log"}, permitted
    verbs = {verb for rule in role["rules"] for verb in rule["verbs"]}
    assert verbs <= {"get", "list"}, verbs
    assert "secrets" not in permitted
    deployment = collector[("Deployment", "iot-log-collector")]
    assert deployment["spec"]["template"]["spec"]["serviceAccountName"] == "iot-log-collector"

    config = yaml.safe_load((OBS / "config/prometheus.yml").read_text())
    jobs = {job["job_name"]: job for job in config["scrape_configs"]}
    assert set(jobs) == REQUIRED | {"prometheus"}
    for name in REQUIRED:
        addresses = jobs[name]["static_configs"][0]["targets"]
        port = 9090 if name in {"ingestion", "device-registry"} else 8000
        assert addresses == [f"{name}.iot-validation.svc.cluster.local:{port}"], name
    rules = yaml.safe_load((OBS / "config/rules.yml").read_text())
    assert len(rules["groups"][0]["rules"]) >= 2
    print("PASS: private observation Services, hardened Pods, scoped RBAC, live target contracts")


if __name__ == "__main__":
    main()
