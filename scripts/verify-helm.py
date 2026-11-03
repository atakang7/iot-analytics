#!/usr/bin/env python3
"""Validate rendered Helm manifests, not just template syntax."""
import argparse
from pathlib import Path

import yaml


EXPECTED = {
    "prometheus": ("localhost:9090", "/metrics"),
    "device-registry": ("device-registry:9090", "/actuator/prometheus"),
    "ingestion": ("ingestion:9090", "/actuator/prometheus"),
    "telemetry-worker": ("telemetry-worker:8000", "/metrics"),
    "stream-worker": ("stream-worker:8000", "/metrics"),
    "alert-worker": ("alert-worker:8000", "/metrics"),
}


def validate_manifests(manifests: list[dict], public_routes: bool = False):
    by_kind = {}
    for manifest in manifests:
        if not manifest:
            continue
        name = manifest["metadata"]["name"]
        key = (manifest["kind"], name)
        if key in by_kind:
            raise AssertionError(f"Duplicate resource {key}")
        by_kind[key] = manifest

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
    parser.add_argument("--export-prometheus-config", type=Path)
    args = parser.parse_args()
    docs = list(yaml.safe_load_all(args.rendered.read_text()))
    validate_manifests(docs, public_routes=args.routes_enabled)
    if args.export_prometheus_config is not None:
        config = next(d for d in docs if d and d.get("kind") == "ConfigMap" and d["metadata"]["name"] == "prometheus-config")
        args.export_prometheus_config.write_text(config["data"]["prometheus.yml"])
    print(f"PASS: {len([x for x in docs if x])} Helm resources, scrape targets, worker metrics, route defaults")


if __name__ == "__main__":
    main()
