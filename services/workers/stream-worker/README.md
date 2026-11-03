Part of [iot-analytics](../../../README.md).

# stream-worker

Evaluates thresholds, rapid changes and repeated sensor values from telemetry events.

## Run

```bash
docker compose -f services/docker-compose.yml up -d --build stream-worker
```

## Test

```bash
(cd services/workers/stream-worker && PYTHONPATH=.. python -m pytest -q)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `KAFKA_TELEMETRY_TOPIC` | `iot.telemetry` | Input topic |
| `KAFKA_ALERTS_TOPIC` | `iot.alerts` | Output topic |
| `DB_PASSWORD` | Unset | Threshold query credential |
| `METRICS_PORT` | `8000` | Prometheus endpoint |

## Interfaces

Reads Kafka group `stream-worker` and SQL table `thresholds`; publishes alerts keyed by `deviceId`. Thresholds load at startup. Recent-value history is process local. See [replay behavior](../../../docs/explanation/consistency.md).
