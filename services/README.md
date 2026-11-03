# Services

| Path | Responsibility |
| --- | --- |
| `ingestion/` | Java 21 HTTP ingestion and Kafka producer |
| `device-registry/` | Java 21 device metadata CRUD |
| `workers/common/` | Python 3.11 domain and transport code |
| `workers/telemetry-worker/` | Kafka telemetry to TimescaleDB |
| `workers/stream-worker/` | Threshold checks and alert publishing |
| `workers/alert-worker/` | Kafka alerts to TimescaleDB |
| `workers/kpi-job/` | Closed five-minute KPI computation |
| `schema.sql` | Fresh database bootstrap |
| `docker-compose.yml` | Local stack |

The registry UUID and the telemetry source ID are separate. See [domain context](../CONTEXT.md), [event fields](../docs/reference/events.md) and [local operations](../docs/how-to/operate-compose.md).

Run the full local pipeline with `make up && make smoke` from the repository root. Each Java service has Maven tests; each Python worker has pytest tests.
