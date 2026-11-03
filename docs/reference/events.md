# Event contracts

## Telemetry

Kafka topic: `iot.telemetry`. Message key: `deviceId`.

```json
{
  "deviceId":"motor-1",
  "deviceType":"motor",
  "sensorId":"temp-1",
  "sensorType":"temperature",
  "timestamp":"2026-11-03T10:00:00Z",
  "unit":"celsius",
  "value":{"value":72.5}
}
```

| Field | Meaning |
| --- | --- |
| `deviceId` | Logical source identifier; independent of the registry UUID |
| `deviceType` | Classification used to select thresholds |
| `sensorId` | Sensor identity within the source |
| `sensorType` | Measurement category |
| `timestamp` | ISO 8601 observation time with UTC offset |
| `unit` | Producer-supplied measurement unit |
| `value` | Object containing the reading payload |

For scalar sensors, workers expect a numeric `value.value`. For `vibration`, the worker calculates a magnitude from `x`, `y` and `z`, treating omitted axes as zero. Non-finite numeric values fail worker validation. The HTTP producer does not yet enforce these full sensor-specific rules.

A stored sample is unique by `(device_id, sensor_id, time)`. Sending a different value with the same identity will not overwrite the first sample.

## Alert

Kafka topic: `iot.alerts`. The stream worker generates an alert with `alertId`, `deviceId`, `deviceType`, `alertType`, `severity`, `message`, `createdAt` and optional `threshold` and `value`.

```json
{
  "alertId":"c12b3d2e-bdb4-54d3-b75c-3cb1aa2f33d2",
  "deviceId":"motor-1",
  "deviceType":"motor",
  "alertType":"threshold_breach",
  "severity":"critical",
  "message":"temperature value 90.00 breached limit 85.0",
  "createdAt":"2026-11-03T10:00:00+00:00",
  "threshold":85.0,
  "value":90.0
}
```

The illustrated `alertId` is an example, not a computed ID for this payload. Actual IDs are deterministic UUID5 values derived from the reading identity, alert type and severity.

## Processing guarantees

- Source offsets are committed after the SQL write or downstream Kafka acknowledgement.
- Duplicate telemetry identities are ignored, and duplicate alert IDs are upserted.
- A Kafka replay can repeat evaluation and metric increments.
- Current consumers stop on a malformed event before committing its offset.

See [failure semantics](../explanation/consistency.md).
