#!/usr/bin/env python3
"""Fail-closed validation of the Kubernetes-only, ephemeral kind app workload."""
import sys
from pathlib import Path
import yaml

SERVICES = ("ingestion", "device-registry", "telemetry-worker",
            "stream-worker", "alert-worker", "kpi-job")


def validate(docs):
    objects = {(d["kind"], d["metadata"]["name"]): d for d in docs if d}
    assert len(objects) == len([d for d in docs if d]), "duplicate objects"
    forbidden = {"BuildConfig", "ImageStream", "Route", "ClusterRole", "ClusterRoleBinding"}
    assert not any(kind in forbidden for kind, _ in objects), "nonportable/privileged manifests"
    for name in SERVICES:
        kind = "CronJob" if name == "kpi-job" else "Deployment"
        workload = objects[(kind, name)]
        pod = workload["spec"]["jobTemplate"]["spec"]["template"]["spec"] if kind == "CronJob" else workload["spec"]["template"]["spec"]
        container, = pod["containers"]
        assert container["image"] == f"iot/{name}:kind", name
        assert container["imagePullPolicy"] == "Never", name
        assert container["name"] == name
    for name in ("ingestion", "device-registry"):
        ports = {p["name"]: p for p in objects[("Service", name)]["spec"]["ports"]}
        assert ports["metrics"]["port"] == 9090
        assert ports["http"]["port"] in {8080, 8081}


if __name__ == "__main__":
    docs = list(yaml.safe_load_all(Path(sys.argv[1]).read_text()))
    validate(docs)
    print("PASS: six portable in-cluster workloads, local-only images, API+metrics Services")
