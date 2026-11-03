# Services

Local run: [../README.md](../README.md) · operational commands:
[../RUNBOOK.md](../RUNBOOK.md).

| Component | Container | Interface |
| --- | --- | --- |
| device-registry | Spring Boot / Java 21 | localhost:8080 |
| ingestion | Spring Boot / Java 21 | localhost:8081 |
| kafka | Single-node Apache Kafka | internal:9092 |
| timescaledb | TimescaleDB on PostgreSQL | localhost:5432 |
| telemetry-worker | Python 3.11 | Kafka → telemetry |
| stream-worker | Python 3.11 | Kafka → alerts topic |
| alert-worker | Python 3.11 | alerts topic → DB |
| kpi-job | Python 3.11, one-shot | DB → KPIs |

Both Java services use Maven and have unit tests. Every Python worker has
unit tests. The real container/database/flow checks run on every PR.

```bash
docker compose -f services/docker-compose.yml up -d --build
bash scripts/smoke-local.sh
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

**Data-model compatibility:** the SQL init script creates a fresh schema.
Existing volumes require a planned migration; do not delete production data.
The device registry's UUID is a management ID, whereas telemetry's `deviceId`
is a logical source key. They are not currently linked by a foreign key.

See [architecture](../docs/ARCHITECTURE.md) for delivery and replay semantics.
