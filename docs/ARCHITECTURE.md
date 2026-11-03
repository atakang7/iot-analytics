# Architecture and delivery semantics

## Control and data planes

The registry is a CRUD API over PostgreSQL/TimescaleDB. Ingestion publishes
a validated JSON envelope to `iot.telemetry` keyed by `deviceId`; a 202
response is returned only after a Kafka broker acknowledges the send.

Two distinct consumer groups read telemetry:

- `telemetry-worker`: batches into the TimescaleDB telemetry hypertable.
- `stream-worker`: evaluates sensor thresholds, rate changes and stuck readings;
  publishes alerts to `iot.alerts`, where `alert-worker` persists them.

`kpi-job` separately reads one closed five-minute window from the database,
calculates per-device/**per-sensor** KPIs, and advances a persisted watermark
within the same transaction.

## Event envelope

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

Vibration readings use `{"x": 0.2, "y": 0.1, "z": 0.0}`; scalar sensors
use `{"value": number}`. The producer requires basic fields, but it does
not yet enforce all sensor-specific numeric schemas. The worker rejects
invalid/non-finite values.

## Failure and replay model

**At least once, not exactly once.** Kafka source offsets are committed only
after successful SQL writes or downstream Kafka acknowledgments. A crash
between the side effect and commit can cause replay.

- Telemetry identity: `(device_id, sensor_id, time)`; duplicate inserts are ignored.
- Alert identity: deterministic UUID5 based on source identity/time, alert type
  and severity; the alert table upserts by ID.
- KPI identity: `(device_id, sensor_id, kpi_name, window_start)`; the checkpoint
  and derived KPI rows commit atomically.
- A poison event currently fails the consumer before acknowledgement. There is
  **no dead-letter topic or quarantine workflow yet**; an operator must inspect
  and resolve/replay the event.
- The stream worker keeps rate-change/stuck state in memory; restarting it
  resets that state. Kafka replay can re-generate alerts, but the persistence
  key deduplicates matching alerts.
- Threshold values are loaded on stream worker startup; an update currently
  requires a restart to take effect.

## Time, retention and analytics

Ingestion requires timestamps with offsets. KPI windows are half-open
`[start, end)`; a scheduled run processes the earliest closed window not
yet checkpointed. This intentionally favors bounded work and recoverability
over catching up many windows in one execution.

The telemetry hypertable compresses after seven days and retains thirty days
under the initialization schema. Set retention to your needs before using
real data. For power, the system reports **sample sum**, not physical energy.
A defensible energy calculation would require power units and time integration.

## Deployment boundaries

`services/docker-compose.yml` is the tested local topology, with internal
broker networking and host-bound API/database ports. `iot-helm/` includes
OpenShift ImageStreams, BuildConfigs, Routes and a legacy CI/CD controller.
These are **not portable Kubernetes primitives** and are not exercised
against an OpenShift cluster by GitHub Actions.

The legacy controller is disabled by default. It is not integrated with the
new verification workflow and must not be mistaken for a release gate.
Prefer explicit operator-controlled deployments until an image digest/
promotion-driven CD design is implemented.
