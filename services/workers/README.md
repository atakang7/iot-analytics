Part of [iot-analytics](../../README.md).

# workers

Four Python entry points share event, transport and database code.

## Run

```bash
docker compose -f services/docker-compose.yml up -d --build telemetry-worker stream-worker alert-worker
make kpi
```

## Test

```bash
(cd services/workers && for worker in telemetry-worker stream-worker alert-worker kpi-job; do
  (cd "$worker" && PYTHONPATH=.. python -m pytest -q) || exit 1
done)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `KAFKA_BOOTSTRAP` | `localhost:9092` | Broker address |
| `DB_PASSWORD` | Required for SQL | Database credential |
| `METRICS_PORT` | `8000` | Worker metrics listener |

## Interfaces

| Component | Input and output |
| --- | --- |
| [telemetry-worker](telemetry-worker/README.md) | Kafka telemetry to SQL |
| [stream-worker](stream-worker/README.md) | Kafka telemetry to Kafka alerts |
| [alert-worker](alert-worker/README.md) | Kafka alerts to SQL |
| [kpi-job](kpi-job/README.md) | SQL telemetry to window KPIs |
| [common](common/README.md) | Event models and adapters |

See [replay behavior](../../docs/explanation/consistency.md).
