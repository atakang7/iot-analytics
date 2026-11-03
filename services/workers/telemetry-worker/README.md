Part of [iot-analytics](../../../README.md).

# telemetry-worker

Consumes telemetry records and inserts deduplicated readings in TimescaleDB.

## Run

```bash
docker compose -f services/docker-compose.yml up -d --build telemetry-worker
```

## Test

```bash
(cd services/workers/telemetry-worker && PYTHONPATH=.. python -m pytest -q)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `KAFKA_TELEMETRY_TOPIC` | `iot.telemetry` | Input topic |
| `KAFKA_BOOTSTRAP` | `localhost:9092` | Broker |
| `DB_PASSWORD` | Unset | SQL credential |
| `METRICS_PORT` | `8000` | Prometheus endpoint |

## Interfaces

Reads Kafka group `telemetry-worker`; writes `telemetry` rows in batches of at most 500. Commits source offsets after the SQL transaction. See [event contract](../../../docs/reference/events.md).
