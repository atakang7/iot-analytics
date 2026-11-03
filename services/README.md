# Services

The local Compose stack runs Java 21 APIs, Python 3.11 workers, Kafka and TimescaleDB.

| component | port | role |
| --- | --- | --- |
| `device-registry` | 8080 | Device CRUD |
| `ingestion` | 8081 | Kafka telemetry publish |
| `timescaledb` | 5432 | Telemetry, alerts and KPIs |
| `kafka` | internal 9092 | Event broker |

## Run

```bash
docker compose -f services/docker-compose.yml up -d --build
bash scripts/smoke-local.sh
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

## Limits

- Both APIs bind to `127.0.0.1` in Compose; Kafka has no TLS or authentication.
- The registry UUID and telemetry `deviceId` are separate identifiers.
- Existing SQL volumes need explicit migrations; see [runbook](../RUNBOOK.md).
