#!/usr/bin/env python3
"""Validate rendered Helm manifests, not just template syntax."""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'delivery'))
from release import load_release

import yaml


EXPECTED = {
    "prometheus": ("localhost:9090", "/metrics"),
    "device-registry": ("device-registry:9090", "/actuator/prometheus"),
    "ingestion": ("ingestion:9090", "/actuator/prometheus"),
    "telemetry-worker": ("telemetry-worker:8000", "/metrics"),
    "stream-worker": ("stream-worker:8000", "/metrics"),
    "alert-worker": ("alert-worker:8000", "/metrics"),
}


def validate_manifests(manifests: list[dict], public_routes: bool = False, release: dict | None = None):
    by_kind = {}
    for manifest in manifests:
        if not manifest:
            continue
        name = manifest["metadata"]["name"]
        key = (manifest["kind"], name)
        if key in by_kind:
            raise AssertionError(f"Duplicate resource {key}")
        by_kind[key] = manifest

    app_names = ("ingestion", "device-registry", "telemetry-worker",
                 "stream-worker", "alert-worker", "kpi-job")
    if release is not None:
        # Immutable releases must contain no in-cluster build pipeline and every
        # workload must run the image that was actually scanned and published.
        assert not any(kind in {"BuildConfig", "ImageStream"} for kind, _ in by_kind), (
            "release mode must not mutate images inside the cluster"
        )
        for name in app_names:
            if name == "kpi-job":
                workload = by_kind[("CronJob", name)]
                containers = workload["spec"]["jobTemplate"]["spec"]["template"]["spec"]["containers"]
            else:
                workload = by_kind[("Deployment", name)]
                containers = workload["spec"]["template"]["spec"]["containers"]
            assert len(containers) == 1
            assert containers[0]["image"] == release["images"][name], name
    else:
        assert sum(kind == "BuildConfig" for kind, _ in by_kind) == len(app_names), (
            "lab mode must define local binary BuildConfigs"
        )

    # The rendered Pods must satisfy our fail-closed admission policy.
    for name in app_names:
        kind = "CronJob" if name == "kpi-job" else "Deployment"
        workload = by_kind[(kind, name)]
        template = (workload["spec"]["jobTemplate"]["spec"]["template"]
                    if kind == "CronJob" else workload["spec"]["template"])
        pod = template["spec"]
        assert template["metadata"]["labels"]["app.kubernetes.io/part-of"] == "iot-analytics", name
        assert pod["securityContext"]["seccompProfile"]["type"] == "RuntimeDefault", name
        for container in pod.get("initContainers", []) + pod["containers"]:
            controls = container["securityContext"]
            assert controls["runAsNonRoot"] is True, name
            assert controls["runAsUser"] == 10001, name
            assert controls["allowPrivilegeEscalation"] is False, name
            assert controls["readOnlyRootFilesystem"] is True, name
            assert "ALL" in controls["capabilities"]["drop"], name
            for bound in ("requests", "limits"):
                assert set(container["resources"][bound]) >= {"cpu", "memory"}, name
        if name in ("ingestion", "device-registry"):
            app = pod["containers"][0]
            assert any(m["mountPath"] == "/tmp" for m in app["volumeMounts"]), name
            assert any(v["name"] == "runtime-tmp" for v in pod["volumes"]), name

    # No dormant deployment agent with blanket access to cluster secrets.
    assert not any(name.startswith("gitops-") for _, name in by_kind)

    configmap = by_kind[("ConfigMap", "prometheus-config")]
    prometheus = yaml.safe_load(configmap["data"]["prometheus.yml"])
    targets = {
        job["job_name"]: (
            job["static_configs"][0]["targets"][0],
            job.get("metrics_path", "/metrics"),
        )
        for job in prometheus["scrape_configs"]
    }
    assert targets == EXPECTED, f"Invalid scrape targets: {targets!r}"

    for name in ("telemetry-worker", "stream-worker", "alert-worker"):
        service = by_kind[("Service", name)]
        assert service["spec"]["ports"][0]["port"] == 8000
        deployment = by_kind[("Deployment", name)]
        container = deployment["spec"]["template"]["spec"]["containers"][0]
        assert container["securityContext"]["runAsNonRoot"] is True
        assert container["securityContext"]["allowPrivilegeEscalation"] is False
        assert container["securityContext"]["readOnlyRootFilesystem"] is True
        assert container["readinessProbe"]["httpGet"]["path"] == "/metrics"

    # The Prometheus static target must actually resolve through a Service.
    for name in ("ingestion", "device-registry"):
        ports = {p["name"]: p for p in by_kind[("Service", name)]["spec"]["ports"]}
        assert ports["metrics"]["port"] == 9090, f"{name} metrics Service missing"
        assert ports["metrics"]["targetPort"] == "management", name

    prometheus_image = by_kind[("Deployment", "prometheus")]["spec"]["template"]["spec"]["containers"][0]["image"]
    assert prometheus_image == "prom/prometheus:v3.15.1"
    routes = {name for kind, name in by_kind if kind == "Route"}
    # Prometheus must never be exposed by a public Route in the demo stack.
    assert "prometheus" not in routes
    public_components = {"device-registry", "ingestion", "grafana"}
    actual = routes & public_components
    expected = public_components if public_routes else set()
    assert actual == expected, f"Unexpected public Routes: {actual}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rendered", type=Path)
    parser.add_argument("--routes-enabled", action="store_true")
    parser.add_argument("--release-manifest", type=Path)
    parser.add_argument("--export-prometheus-config", type=Path)
    args = parser.parse_args()
    docs = list(yaml.safe_load_all(args.rendered.read_text()))
    release = load_release(args.release_manifest) if args.release_manifest else None
    validate_manifests(docs, public_routes=args.routes_enabled, release=release)
    if args.export_prometheus_config is not None:
        config = next(d for d in docs if d and d.get("kind") == "ConfigMap" and d["metadata"]["name"] == "prometheus-config")
        args.export_prometheus_config.write_text(config["data"]["prometheus.yml"])
    print(f"PASS: {len([x for x in docs if x])} Helm resources, scrape targets, worker metrics, route defaults")


if __name__ == "__main__":
    main()
