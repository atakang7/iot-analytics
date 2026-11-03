#!/usr/bin/env python3
"""Measured, bounded HTTP load test for a development ingestion endpoint.

No scaling, cluster mutation or claimed performance target. The tool records
actual observed HTTP 202 acknowledgements and wall-clock throughput.
"""
import argparse
import json
import math
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def validate_url(url: str, allow_remote: bool = False) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("URL must be an absolute HTTP(S) address")
    if parsed.username or parsed.password or parsed.fragment:
        raise ValueError("Do not include credentials or fragments in the URL")
    if not allow_remote and parsed.hostname not in {"localhost", "127.0.0.1", "::1"}:
        raise ValueError("Remote targets require --allow-remote")
    if parsed.hostname not in {"localhost", "127.0.0.1", "::1"} and parsed.scheme != "https":
        raise ValueError("Remote benchmarks must use HTTPS")
    return url


def make_payload(device_id: str, index: int, base_time: datetime) -> dict:
    timestamp = base_time + timedelta(microseconds=index)
    return {
        "deviceId": device_id,
        "deviceType": "benchmark",
        "sensorId": "temperature",
        "sensorType": "temperature",
        "timestamp": timestamp.isoformat().replace("+00:00", "Z"),
        "unit": "celsius",
        "value": {"value": 20.0 + float(index % 10)},
    }


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    sorted_values = sorted(values)
    index = max(0, math.ceil(fraction * len(sorted_values)) - 1)
    return round(sorted_values[index], 2)


def send(url: str, payload: dict, timeout: float) -> tuple[int, float]:
    request = Request(
        url,
        data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    start = time.perf_counter()
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.status, (time.perf_counter() - start) * 1000
    except HTTPError as exc:
        exc.close()
        return exc.code, (time.perf_counter() - start) * 1000
    except (URLError, TimeoutError, OSError):
        return 0, (time.perf_counter() - start) * 1000


def benchmark(url: str, count: int, concurrency: int, timeout: float) -> dict:
    if not 1 <= count <= 10000:
        raise ValueError("count must be between 1 and 10000")
    if not 1 <= concurrency <= 64:
        raise ValueError("concurrency must be between 1 and 64")
    if not 0 < timeout <= 120:
        raise ValueError("timeout must be in (0, 120] seconds")

    run_id = f"bench-{uuid.uuid4().hex[:12]}"
    base_time = datetime.now(timezone.utc)
    start = time.perf_counter()
    results: list[tuple[int, float]] = []

    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        jobs = [
            pool.submit(send, url, make_payload(run_id, i, base_time), timeout)
            for i in range(count)
        ]
        for job in as_completed(jobs):
            results.append(job.result())

    elapsed = time.perf_counter() - start
    successes = [latency for status, latency in results if status == 202]
    status_counts: dict[str, int] = {}
    for status, _ in results:
        label = str(status) if status else "transport_error"
        status_counts[label] = status_counts.get(label, 0) + 1

    return {
        "device_id": run_id,
        "requested": count,
        "accepted": len(successes),
        "failed": count - len(successes),
        "statuses": status_counts,
        "elapsed_seconds": round(elapsed, 3),
        "accepted_per_second": round(len(successes) / elapsed, 2) if elapsed > 0 else 0,
        "p50_ack_latency_ms": percentile(successes, 0.50),
        "p95_ack_latency_ms": percentile(successes, 0.95),
        "note": "HTTP 202 measures Kafka acknowledgement, not SQL persistence",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8081/telemetry")
    parser.add_argument("--count", type=int, default=100)
    parser.add_argument("--concurrency", type=int, default=5)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("--allow-remote", action="store_true")
    args = parser.parse_args(argv)
    try:
        validate_url(args.url, args.allow_remote)
        result = benchmark(args.url, args.count, args.concurrency, args.timeout)
    except ValueError as exc:
        parser.error(str(exc))
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["failed"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
