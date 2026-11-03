#!/usr/bin/env python3
"""Namespace-scoped, best-effort Kubernetes Pod log forwarder to Loki.

No host mounts, cluster roles, privileged container or shelling out to kubectl.
A cursor advances only after Loki accepts the batch; restart replays tail logs.
"""
import calendar
import json
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime

NAMESPACE = os.environ.get("POD_NAMESPACE", "iot-validation")
LOKI_URL = os.environ.get(
    "LOKI_PUSH_URL",
    "http://loki.iot-observability.svc.cluster.local:3100/loki/api/v1/push",
)
SERVICE_ACCOUNT = "/var/run/secrets/kubernetes.io/serviceaccount"
API_BASE = "https://kubernetes.default.svc"
LABEL_SELECTOR = "app.kubernetes.io/part-of=iot-analytics"
TIMESTAMP = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?Z$")


def log_time_ns(value: str) -> int:
    """Preserve Kubernetes nanosecond timestamps rather than using floats."""
    match = TIMESTAMP.fullmatch(value)
    if match is None:
        raise ValueError("unsupported Kubernetes log timestamp")
    seconds = datetime.strptime(match.group(1), "%Y-%m-%dT%H:%M:%S")
    return calendar.timegm(seconds.timetuple()) * 1_000_000_000 + int(
        (match.group(2) or "").ljust(9, "0") or "0"
    )


def parse_lines(raw: str, after: int) -> list[tuple[int, str]]:
    events = []
    for line in raw.splitlines():
        token, separator, message = line.partition(" ")
        if not separator or not message:
            continue
        try:
            timestamp = log_time_ns(token)
        except ValueError:
            continue
        if timestamp > after:
            events.append((timestamp, message[:8192]))
    return events


def loki_payload(namespace: str, pod: str, service: str,
                 entries: list[tuple[int, str]]) -> dict:
    return {
        "streams": [{
            "stream": {"namespace": namespace, "pod": pod, "service": service},
            "values": [[str(ts), line] for ts, line in entries],
        }]
    }


class Collector:
    def __init__(self, namespace: str = NAMESPACE):
        self.namespace = namespace
        self.token = open(f"{SERVICE_ACCOUNT}/token", encoding="utf-8").read().strip()
        self.context = ssl.create_default_context(
            cafile=f"{SERVICE_ACCOUNT}/ca.crt"
        )
        self.cursors: dict[str, int] = {}

    def kubernetes(self, path: str, params: dict | None = None):
        address = API_BASE + path
        if params:
            address += "?" + urllib.parse.urlencode(params)
        request = urllib.request.Request(address, headers={
            "Authorization": "Bearer " + self.token,
        })
        with urllib.request.urlopen(request, context=self.context, timeout=10) as response:
            return response.read(500_001).decode("utf-8")

    def collect_once(self):
        prefix = "/api/v1/namespaces/" + urllib.parse.quote(self.namespace, safe="")
        pods = json.loads(self.kubernetes(
            prefix + "/pods", {"labelSelector": LABEL_SELECTOR}
        ))["items"]
        active = set()
        for pod in pods:
            if pod.get("status", {}).get("phase") != "Running":
                continue
            metadata = pod["metadata"]
            name = metadata["name"]
            uid = metadata["uid"]
            service = metadata.get("labels", {}).get("app")
            if not service:
                continue
            active.add(uid)
            log = self.kubernetes(
                prefix + "/pods/" + urllib.parse.quote(name, safe="") + "/log",
                {"timestamps": "true", "tailLines": "100"},
            )
            events = parse_lines(log, self.cursors.get(uid, 0))
            if not events:
                continue
            data = json.dumps(
                loki_payload(self.namespace, name, service, events),
                separators=(",", ":"),
            ).encode("utf-8")
            request = urllib.request.Request(
                LOKI_URL, data=data, headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(request, timeout=10) as response:
                if response.status not in (200, 204):
                    raise RuntimeError("Loki rejected log batch")
            self.cursors[uid] = max(timestamp for timestamp, _ in events)
        self.cursors = {uid: offset for uid, offset in self.cursors.items() if uid in active}


def main():
    collector = Collector()
    print("Namespace-scoped Loki collector started", flush=True)
    while True:
        try:
            collector.collect_once()
        except (OSError, ValueError, KeyError, urllib.error.URLError,
                RuntimeError) as exc:
            print(f"Log collection retry: {type(exc).__name__}: {exc}",
                  file=sys.stderr, flush=True)
        time.sleep(3)


if __name__ == "__main__":
    main()
