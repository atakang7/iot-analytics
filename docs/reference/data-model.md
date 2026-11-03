# Data model

The bootstrap DDL is [services/schema.sql](../../services/schema.sql). The OpenShift chart keeps a byte-identical copy in [its infra subchart](../../iot-helm/charts/infra/configs/schema.sql). Neither file is a migration.

| Table | Purpose | Identity |
| --- | --- | --- |
| `devices` | Registry metadata | `id`, UUID |
| `telemetry` | Sensor readings | `(device_id, sensor_id, time)` |
| `alerts` | Detected anomalies | `alert_id` |
| `kpis` | Window aggregates | `(device_id, sensor_id, kpi_name, window_start)` |
| `thresholds` | Limits per sensor and optional device type | `(sensor_type, device_type)`, nulls not distinct |
| `job_watermarks` | Batch processing progress | `job_name` |

`telemetry` and `kpis` are TimescaleDB hypertables. The telemetry schema schedules compression after seven days and removal after thirty days. These policies are bootstrap defaults, not a production retention decision.

`alerts` uses an ordinary PostgreSQL table so a unique alert ID works independently of event time. `job_watermarks` advances in the transaction that stores KPI rows.

KPI intervals are half-open: the start is included, the end excluded. The job processes one completed five-minute interval per run. `power_sum` is a sample sum, not a physical energy measurement.

See [ADR 0002](../adr/0002-at-least-once-events.md) for the identity trade-off.
