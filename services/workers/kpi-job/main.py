"""Incremental 5-minute KPIs, transactionally checkpointed.

Each run processes one closed interval. A crash rolls back its KPI writes and
checkpoint together; subsequent runs resume that exact interval.
"""
import json
import math
import statistics
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from psycopg2.extras import RealDictCursor

from common.db import get_connection
from common.logger import get_logger
from common.metrics import kpi_job_duration, kpis_computed, push_metrics

log = get_logger("kpi-job")
JOB_NAME = "kpi_5min"
WINDOW = timedelta(minutes=5)


def extract_value(value_json: str | dict, sensor_type: str) -> float | None:
    value = json.loads(value_json) if isinstance(value_json, str) else value_json
    if not isinstance(value, dict):
        raise ValueError("Telemetry value must be an object")
    if sensor_type == "vibration":
        axes = [float(value.get(axis, 0)) for axis in ("x", "y", "z")]
        result = math.sqrt(sum(axis * axis for axis in axes))
    elif "value" in value:
        result = float(value["value"])
    else:
        return None
    if not math.isfinite(result):
        raise ValueError("Telemetry value must be finite")
    return result


def compute_kpis(values: list[float], sensor_type: str) -> dict[str, float]:
    if not values:
        return {}
    result = {
        "avg": statistics.mean(values),
        "min": min(values),
        "max": max(values),
        "count": len(values),
    }
    if len(values) >= 2:
        result["std_dev"] = statistics.stdev(values)
        result["range"] = max(values) - min(values)
    if sensor_type == "vibration":
        result["rms"] = math.sqrt(sum(value ** 2 for value in values) / len(values))
        if result["rms"] > 0:
            result["crest_factor"] = max(abs(value) for value in values) / result["rms"]
    if sensor_type == "temperature" and len(values) >= 2:
        result["rate_of_change"] = values[-1] - values[0]
    if sensor_type == "power":
        # This is a sample sum, NOT energy; actual energy needs time integration.
        result["sum"] = sum(values)
    return result


@kpi_job_duration.time()
def run_job(now: datetime | None = None) -> int:
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    cutoff = now.replace(minute=(now.minute // 5) * 5, second=0, microsecond=0)

    conn = get_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            # Serialize competing CronJobs: row lock + writes + watermark.
            cursor.execute(
                "SELECT last_processed_at FROM job_watermarks WHERE job_name = %s FOR UPDATE",
                (JOB_NAME,),
            )
            state = cursor.fetchone()
            if not state:
                raise RuntimeError(f"Missing watermark row: {JOB_NAME}")

            start = state["last_processed_at"]
            if start >= cutoff:
                conn.commit()
                return 0

            end = min(start + WINDOW, cutoff)
            cursor.execute(
                """SELECT device_id, device_type, sensor_id, sensor_type, unit, time, value
                   FROM telemetry
                   WHERE time >= %s AND time < %s
                   ORDER BY device_id, sensor_id, time""",
                (start, end),
            )
            rows = cursor.fetchall()
            groups = defaultdict(list)
            units = {}
            for row in rows:
                key = (
                    row["device_id"], row["device_type"],
                    row["sensor_id"], row["sensor_type"],
                )
                value = extract_value(row["value"], row["sensor_type"])
                if value is not None:
                    groups[key].append(value)
                    units[key] = row["unit"]

            inserted = 0
            for (device_id, device_type, sensor_id, sensor_type), values in groups.items():
                for name, value in compute_kpis(values, sensor_type).items():
                    full_name = f"{sensor_type}_{name}"
                    cursor.execute(
                        """INSERT INTO kpis (
                               created_at, device_id, device_type, sensor_id, kpi_name,
                               kpi_value, unit, window_start, window_end, sample_count
                           ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                           ON CONFLICT (device_id, sensor_id, kpi_name, window_start)
                           DO UPDATE SET
                               created_at = EXCLUDED.created_at,
                               kpi_value = EXCLUDED.kpi_value,
                               unit = EXCLUDED.unit,
                               window_end = EXCLUDED.window_end,
                               sample_count = EXCLUDED.sample_count""",
                        (
                            now, device_id, device_type, sensor_id, full_name,
                            value, units[key], start, end, len(values),
                        ),
                    )
                    inserted += 1

            cursor.execute(
                """UPDATE job_watermarks
                   SET last_processed_at = %s, updated_at = NOW()
                   WHERE job_name = %s""",
                (end, JOB_NAME),
            )
        conn.commit()
        for (device_id, device_type, sensor_id, sensor_type), values in groups.items():
            for name in compute_kpis(values, sensor_type):
                kpis_computed.labels(kpi_name=f"{sensor_type}_{name}").inc()
        log.info(
            "Window committed",
            extra={"extra": {"from": start.isoformat(), "to": end.isoformat(),
                              "readings": len(rows), "kpis": inserted}},
        )
        return inserted
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def main():
    try:
        run_job()
        try:
            push_metrics(JOB_NAME)
        except Exception:
            log.warning("Pushgateway unavailable; database results are committed", exc_info=True)
    except Exception:
        log.exception("KPI job failed")
        raise


if __name__ == "__main__":
    main()
