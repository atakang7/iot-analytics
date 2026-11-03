# Analytics workers

Event flow:

```text
Kafka iot.telemetry
  ├── telemetry-worker ──► TimescaleDB.telemetry ──► kpi-job ──► TimescaleDB.kpis
  └── stream-worker ──► Kafka iot.alerts ──► alert-worker ──► TimescaleDB.alerts
```

All streaming consumers commit Kafka offsets **only after** their relevant
database write or Kafka publish succeeds. Delivery is at least once and
replays are deduplicated by logical event keys.

- Telemetry: bounded batches, finite numbers, and duplicate sample identity
  `(device_id, sensor_id, timestamp)`.
- Stream: global or device-type thresholds, rate-change and repeated-value
  alerts. Stream history is held in memory and resets after restart.
- Alerts: stable alert IDs, idempotent updates and persisted acknowledgement
  flags.
- KPIs: one closed five-minute window per invocation, by device **and sensor**;
  computed rows and watermark share one SQL transaction. The power-sample
  `sum` is not a physical energy calculation.

`kpi-job` is a one-shot batch task, not a long-running worker:

```bash
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

Isolated Python unit tests:

```bash
cd services/workers
for worker in telemetry-worker stream-worker alert-worker kpi-job; do
  (cd "$worker" && PYTHONPATH=.. python -m pytest -q)
done
```

The dependencies are in each worker's `requirements.txt`; GitHub Actions
installs them and runs these tests on every PR. See
[architecture](../../docs/ARCHITECTURE.md) and [runbook](../../RUNBOOK.md).
