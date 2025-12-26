#!/usr/bin/env python3
"""IoT Device Simulator - Generates realistic sensor telemetry"""
import os, json, time, random, math, urllib.request
from datetime import datetime, timezone

INGESTION_URL = os.getenv("INGESTION_URL", "http://ingestion:8080/telemetry")
DEVICE_ID = os.getenv("DEVICE_ID", "device-001")
DEVICE_TYPE = os.getenv("DEVICE_TYPE", "motor")
INTERVAL_MS = int(os.getenv("INTERVAL_MS", "5000"))
SENSORS_JSON = os.getenv("SENSORS", "[]")

class Simulator:
    def __init__(self):
        self.states = {}
        self.start_time = time.time()
    
    def get_reading(self, sensor_type, config):
        min_v, max_v = config.get("min", 0), config.get("max", 100)
        pattern = config.get("pattern", "normal")
        key = f"{sensor_type}_{config.get('id', '')}"
        
        if key not in self.states:
            base = (min_v + max_v) / 2
            self.states[key] = {"base": base, "current": base, "trend": 0, "noise": config.get("noise", 0.1)}
        
        s = self.states[key]
        elapsed = time.time() - self.start_time
        
        if pattern == "normal":
            noise = random.gauss(0, s["noise"] * (max_v - min_v) * 0.01)
            reversion = (s["base"] - s["current"]) * 0.05
            value = s["current"] + noise + reversion
        elif pattern == "cyclic":
            period = config.get("period_seconds", 3600)
            amplitude = (max_v - min_v) * 0.3
            cycle = math.sin(2 * math.pi * elapsed / period) * amplitude
            noise = random.gauss(0, s["noise"] * amplitude * 0.1)
            value = s["base"] + cycle + noise
        elif pattern == "load_dependent":
            load_cycle = (math.sin(elapsed / 300) + 1) / 2
            load_factor = 0.3 + (load_cycle * 0.7)
            target = min_v + (max_v - min_v) * load_factor
            change = (target - s["current"]) * 0.1
            noise = random.gauss(0, s["noise"] * (max_v - min_v) * 0.01)
            value = s["current"] + change + noise
        elif pattern == "spike":
            noise = random.gauss(0, s["noise"] * (max_v - min_v) * 0.01)
            reversion = (s["base"] - s["current"]) * 0.05
            value = s["current"] + noise + reversion
            if random.random() < config.get("spike_probability", 0.02):
                spike = random.uniform(1.5, config.get("spike_magnitude", 2.0)) * (max_v - min_v) * 0.2
                value = min(max_v, value + spike)
        elif pattern == "drift":
            s["trend"] += random.gauss(0.0001, 0.00005)
            s["trend"] = max(-0.01, min(0.01, s["trend"]))
            drift = s["trend"] * (max_v - min_v)
            noise = random.gauss(0, s["noise"] * (max_v - min_v) * 0.01)
            value = s["current"] + drift + noise
        else:
            value = s["current"]
        
        value = max(min_v, min(max_v, value))
        s["current"] = value
        return round(value, 3)

def send(device_id, device_type, sensor, value):
    payload = {
        "deviceId": device_id,
        "deviceType": device_type,
        "sensorId": sensor["id"],
        "sensorType": sensor["type"],
        "timestamp": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "unit": sensor["unit"],
        "value": {"reading": value}
    }
    try:
        data = json.dumps(payload).encode()
        req = urllib.request.Request(INGESTION_URL, data=data, headers={"Content-Type": "application/json"})
        resp = urllib.request.urlopen(req, timeout=5)
        return resp.status == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    print(f"Device Simulator Starting")
    print(f"  ID: {DEVICE_ID}")
    print(f"  Type: {DEVICE_TYPE}")
    print(f"  Interval: {INTERVAL_MS}ms")
    print(f"  Ingestion: {INGESTION_URL}")
    
    sensors = json.loads(SENSORS_JSON) if SENSORS_JSON else []
    if not sensors:
        print("ERROR: No sensors configured!")
        return
    
    print(f"  Sensors: {[s['id'] for s in sensors]}")
    
    sim = Simulator()
    
    print("Starting telemetry loop...")
    count = 0
    errors = 0
    while True:
        for sensor in sensors:
            value = sim.get_reading(sensor["type"], sensor)
            if send(DEVICE_ID, DEVICE_TYPE, sensor, value):
                count += 1
                if count % 20 == 0:
                    print(f"[{DEVICE_ID}] Sent {count} readings | {sensor['type']}={value}{sensor['unit']}")
            else:
                errors += 1
                if errors % 10 == 0:
                    print(f"[{DEVICE_ID}] Errors: {errors}")
        
        time.sleep(INTERVAL_MS / 1000.0)

if __name__ == "__main__":
    main()