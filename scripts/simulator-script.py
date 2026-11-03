#!/usr/bin/env python3
"""IoT simulator for the ingestion API's documented telemetry envelope."""
import json
import math
import os
import random
import time
import urllib.request
from datetime import datetime, timezone

INGESTION_URL = os.getenv("INGESTION_URL", "http://localhost:8081/telemetry")
DEVICE_ID = os.getenv("DEVICE_ID", "device-001")
DEVICE_TYPE = os.getenv("DEVICE_TYPE", "motor")
INTERVAL_MS = int(os.getenv("INTERVAL_MS", "5000"))
SENSORS_JSON = os.getenv("SENSORS", "[]")


class Simulator:
    def __init__(self):
        self.states = {}
        self.start_time = time.monotonic()

    def get_reading(self, sensor_type, config):
        minimum, maximum = config.get("min", 0), config.get("max", 100)
        pattern = config.get("pattern", "normal")
        key = f"{sensor_type}:{config.get('id', '')}"
        if key not in self.states:
            center = (minimum + maximum) / 2
            self.states[key] = {"base": center, "current": center, "trend": 0.0}
        state = self.states[key]
        span = maximum - minimum
        noise = random.gauss(0, config.get("noise", 0.1) * span * 0.01)
        elapsed = time.monotonic() - self.start_time
        value = state["current"]

        if pattern == "cyclic":
            period = max(1, config.get("period_seconds", 3600))
            value = state["base"] + math.sin(2 * math.pi * elapsed / period) * span * 0.3 + noise
        elif pattern == "load_dependent":
            load = (math.sin(elapsed / 300) + 1) / 2
            target = minimum + span * (0.3 + load * 0.7)
            value += (target - value) * 0.1 + noise
        elif pattern == "spike" and random.random() < config.get("spike_probability", 0.02):
            value += span * config.get("spike_magnitude", 2.0) * 0.2
        elif pattern == "drift":
            state["trend"] = max(-0.01, min(0.01, state["trend"] + random.gauss(0.0001, 0.00005)))
            value += state["trend"] * span + noise
        else:
            value += (state["base"] - value) * 0.05 + noise

        state["current"] = min(max(value, minimum), maximum)
        return round(state["current"], 3)


def payload(device_id, device_type, sensor, reading):
    value = {"x": reading, "y": 0.0, "z": 0.0} if sensor["type"] == "vibration" else {"value": reading}
    return {
        "deviceId": device_id,
        "deviceType": device_type,
        "sensorId": sensor["id"],
        "sensorType": sensor["type"],
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "unit": sensor["unit"],
        "value": value,
    }


def send(device_id, device_type, sensor, reading):
    body = json.dumps(payload(device_id, device_type, sensor, reading)).encode("utf-8")
    request = urllib.request.Request(
        INGESTION_URL, data=body, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return 200 <= response.status < 300
    except Exception as exc:
        print(f"Publish error: {exc}", flush=True)
        return False


def main():
    sensors = json.loads(SENSORS_JSON)
    if not sensors:
        raise SystemExit("SENSORS must contain at least one sensor")
    simulator = Simulator()
    print(f"Simulating {DEVICE_ID} -> {INGESTION_URL}", flush=True)
    while True:
        for sensor in sensors:
            reading = simulator.get_reading(sensor["type"], sensor)
            if not send(DEVICE_ID, DEVICE_TYPE, sensor, reading):
                print(f"Failed to send {sensor['id']}", flush=True)
        time.sleep(INTERVAL_MS / 1000)


if __name__ == "__main__":
    main()
