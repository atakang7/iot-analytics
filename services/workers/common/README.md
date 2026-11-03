Part of [iot-analytics](../../../README.md).

# common

Shared Python event models, Kafka adapters, database access, logging and metrics.

## Run

Worker entry points import this package through `PYTHONPATH=..`.

## Test

```bash
(cd services/workers && for worker in telemetry-worker stream-worker alert-worker kpi-job; do
  (cd "$worker" && PYTHONPATH=.. python -m pytest -q) || exit 1
done)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `KAFKA_BOOTSTRAP` | `localhost:9092` | Kafka broker |
| `DB_PASSWORD` | Unset | Required when connecting to SQL |
| `METRICS_PORT` | `8000` | Worker metrics listener |

## Interfaces

`models.py` owns the wire objects; `kafka.py` owns offset commits and send acknowledgments; `db.py` owns SQL transactions. Full settings are in [configuration](../../../docs/reference/configuration.md).
