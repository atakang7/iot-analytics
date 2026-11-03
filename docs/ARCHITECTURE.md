# Architecture

The registry manages device metadata; ingestion sends JSON telemetry to Kafka while workers persist readings, alerts and KPIs.

```text
+---------------+ Kafka +------------+ Kafka +--------------+ writes +-------------+
| stream-worker | ----> | iot.alerts | ----> | alert-worker | ------> | timescaledb |
+---------------+       +------------+       +--------------+         +-------------+
```

## Event

`POST /telemetry` on port `8081` accepts:

```json
{
  "deviceId": "motor-1",
  "deviceType": "motor",
  "sensorId": "temp-1",
  "sensorType": "temperature",
  "timestamp": "2026-11-03T10:00:00Z",
  "unit": "celsius",
  "value": {"value": 72.5}
}
```

Vibration uses `{"x": 0.2, "y": 0.1, "z": 0.0}`; timestamps need a UTC offset, and workers reject non-finite numeric values.

## Delivery

- Ingestion returns HTTP `202` after Kafka acknowledges the publish.
- Consumer offsets commit after the SQL write or downstream publish, so delivery is at least once.
- Telemetry deduplicates on `(device_id, sensor_id, time)`.
- Alerts use stable UUID5 IDs and database upserts.
- KPIs deduplicate on `(device_id, sensor_id, kpi_name, window_start)`; the watermark and KPI rows commit together.
- Invalid events block their consumer until corrected; there is no dead-letter topic.

## Windows and state

- `kpi-job` processes one closed five-minute window per invocation, using `[start, end)`.
- Retention is 30 days and compression starts after seven days in a newly initialized TimescaleDB.
- Power `sum` adds samples; it does not calculate energy.
- Stream-worker rate and stuck-sensor state resets on restart; threshold changes require a restart.
- Device-registry UUIDs are not validated against telemetry `deviceId` values.

The Compose stack is local; [OpenShift](OPENSHIFT.md) is an optional deployment target with no automatic rollout.
