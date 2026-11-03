#!/usr/bin/env python3
"""Real HTTP/API acceptance proof of Kubernetes metrics, alerts and logs."""
import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

PROM = "http://127.0.0.1:19092"
LOKI = "http://127.0.0.1:13100"
GRAFANA = "http://127.0.0.1:13000"
ALERTMANAGER = "http://127.0.0.1:19093"
JOBS = frozenset({
    "ingestion", "device-registry", "telemetry-worker",
    "stream-worker", "alert-worker",
})


def api(url: str, password: str | None = None):
    headers = {}
    if password is not None:
        encoded = base64.b64encode(f"admin:{password}".encode()).decode("ascii")
        headers["Authorization"] = "Basic " + encoded
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read(1_000_001))


def check_metrics():
    params = urllib.parse.urlencode({"query": "up"})
    data = api(PROM + "/api/v1/query?" + params)
    jobs = {
        item["metric"]["job"]: float(item["value"][1])
        for item in data["data"]["result"]
    }
    assert all(jobs.get(job) == 1 for job in JOBS), jobs
    rules = api(PROM + "/api/v1/rules")
    names = {
        rule["name"] for group in rules["data"]["groups"]
        for rule in group["rules"]
    }
    assert {"IoTIngestionUnavailable", "IoTStreamWorkerUnavailable"} <= names, names


def check_grafana(password):
    assert api(GRAFANA + "/api/health")["database"] == "ok"
    datasources = api(GRAFANA + "/api/datasources", password)
    assert {"Prometheus", "Loki"} <= {item["name"] for item in datasources}


def check_logs():
    params = urllib.parse.urlencode({
        "query": '{service="telemetry-worker"}',
        "limit": "100",
        "start": str(time.time_ns() - 900_000_000_000),
        "end": str(time.time_ns()),
    })
    result = api(LOKI + "/loki/api/v1/query_range?" + params)
    messages = [
        message for stream in result["data"]["result"]
        for _, message in stream["values"]
    ]
    assert any("Batch committed" in line for line in messages), (
        f"Loki contains {len(messages)} log lines, none from telemetry-worker batches"
    )


def check_alertmanager():
    with urllib.request.urlopen(ALERTMANAGER + "/-/ready", timeout=5) as response:
        assert response.status == 200


def retry(name, func, attempts=90):
    failure = None
    for attempt in range(attempts):
        try:
            func()
            return
        except (AssertionError, KeyError, ValueError, urllib.error.URLError) as exc:
            failure = exc
            time.sleep(2)
    raise AssertionError(f"{name} validation failed: {failure}") from failure


def main():
    retry("Prometheus", check_metrics)
    print("PASS: 5 live Prometheus application targets and alert rules", flush=True)
    retry("Alertmanager", check_alertmanager)
    print("PASS: Alertmanager is healthy", flush=True)
    retry("Grafana", lambda: check_grafana(os.environ["IOT_GRAFANA_PASSWORD"]))
    print("PASS: Grafana Prometheus and Loki data sources", flush=True)
    retry("Loki", check_logs)
    print("PASS: real telemetry-worker logs reached Loki", flush=True)


if __name__ == "__main__":
    main()
