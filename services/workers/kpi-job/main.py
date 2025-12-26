#!/usr/bin/env python3
"""
KPI Job (CronJob)
TimescaleDB: telemetry → compute KPIs → TimescaleDB: kpis
"""
import sys
sys.path.insert(0, "/app")

import json
import statistics
from datetime import datetime, timedelta
from collections import defaultdict

from common.db import query, execute, upsert_one
from common.metrics import kpis_computed, kpi_job_duration, push_metrics
from common.logger import get_logger


log = get_logger("kpi-job")


def get_watermark(job_name: str) -> datetime:
    rows = query("SELECT last_processed_at FROM job_watermarks WHERE job_name = %s", (job_name,))
    if rows:
        return rows[0]["last_processed_at"]
    return datetime(1970, 1, 1)


def update_watermark(job_name: str, ts: datetime):
    execute(
        "UPDATE job_watermarks SET last_processed_at = %s, updated_at = NOW() WHERE job_name = %s",
        (ts, job_name)
    )


def extract_value(value_json: str, sensor_type: str) -> float | None:
    value = json.loads(value_json) if isinstance(value_json, str) else value_json
    
    if sensor_type == "vibration":
        x = value.get("x", 0)
        y = value.get("y", 0)
        z = value.get("z", 0)
        return (x**2 + y**2 + z**2) ** 0.5
    
    return value.get("value")


def compute_kpis(values: list[float], sensor_type: str) -> dict[str, float]:
    if not values:
        return {}

    kpis = {
        "avg": statistics.mean(values),
        "min": min(values),
        "max": max(values),
        "count": len(values),
    }

    if len(values) >= 2:
        kpis["std_dev"] = statistics.stdev(values)
        kpis["range"] = max(values) - min(values)

    if sensor_type == "vibration":
        kpis["rms"] = (sum(v**2 for v in values) / len(values)) ** 0.5
        if kpis["rms"] > 0:
            kpis["crest_factor"] = max(abs(v) for v in values) / kpis["rms"]

    if sensor_type == "temperature" and len(values) >= 2:
        kpis["rate_of_change"] = values[-1] - values[0]

    if sensor_type == "power":
        kpis["energy"] = sum(values)

    return kpis


@kpi_job_duration.time()
def run_job():
    job_name = "kpi_5min"

    watermark = get_watermark(job_name)
    now = datetime.utcnow()
    
    log.info("Processing window", extra={"extra": {
        "from": watermark.isoformat(),
        "to": now.isoformat()
    }})

    rows = query("""
        SELECT device_id, device_type, sensor_id, sensor_type, time, value
        FROM telemetry
        WHERE time > %s AND time <= %s
        ORDER BY device_id, sensor_id, time
    """, (watermark, now))

    if not rows:
        log.info("No new telemetry data")
        return

    groups = defaultdict(list)
    max_time = watermark
    
    for row in rows:
        key = (row["device_id"], row["device_type"], row["sensor_id"], row["sensor_type"])
        value = extract_value(row["value"], row["sensor_type"])
        if value is not None:
            groups[key].append(value)
        if row["time"] > max_time:
            max_time = row["time"]

    kpi_count = 0
    for (device_id, device_type, sensor_id, sensor_type), values in groups.items():
        kpis = compute_kpis(values, sensor_type)
        
        window_start = watermark
        window_end = max_time

        for kpi_name, kpi_value in kpis.items():
            full_kpi_name = f"{sensor_type}_{kpi_name}"
            
            upsert_one("kpis", {
                "created_at": now,
                "device_id": device_id,
                "device_type": device_type,
                "kpi_name": full_kpi_name,
                "kpi_value": kpi_value,
                "unit": None,
                "window_start": window_start,
                "window_end": window_end,
                "sample_count": len(values),
            }, conflict_cols=["device_id", "kpi_name", "window_start"])

            kpis_computed.labels(kpi_name=full_kpi_name).inc()
            kpi_count += 1

    update_watermark(job_name, max_time)

    log.info("Job completed", extra={"extra": {
        "kpis_computed": kpi_count,
        "readings_processed": len(rows),
        "devices": len(groups)
    }})


def main():
    log.info("Starting kpi-job")
    
    try:
        run_job()
        try:
            push_metrics("kpi-job")
        except Exception:
            pass
        log.info("KPI job completed successfully")
    except Exception as e:
        log.exception("KPI job failed")
        raise


if __name__ == "__main__":
    main()

