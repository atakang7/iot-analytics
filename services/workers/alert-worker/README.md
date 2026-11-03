Part of [iot-analytics](../../../README.md).

# alert-worker

Persists Kafka alerts by stable alert identity.

## Run

```bash
docker compose -f services/docker-compose.yml up -d --build alert-worker
```

## Test

```bash
(cd services/workers/alert-worker && PYTHONPATH=.. python -m pytest -q)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `KAFKA_ALERTS_TOPIC` | `iot.alerts` | Input topic |
| `KAFKA_BOOTSTRAP` | `localhost:9092` | Broker |
| `DB_PASSWORD` | Unset | SQL credential |
| `METRICS_PORT` | `8000` | Prometheus endpoint |

## Interfaces

Reads Kafka group `alert-worker`; upserts table `alerts` on `alert_id` and commits the offset after the write. See [event fields](../../../docs/reference/events.md).
