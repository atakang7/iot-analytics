# Configuration

Compose reads `services/.env` for interpolation. The worker process also reads its own environment. Kubernetes installs use chart values and generated secrets instead.

## Local environment

| Setting | Default | Used by |
| --- | --- | --- |
| `IOT_DB_PASSWORD` | None, required | Compose TimescaleDB and workers |
| `DB_HOST` | `localhost` | Python database clients |
| `DB_PORT` | `5432` | Python database clients |
| `DB_NAME` | `iot` | Python database clients |
| `DB_USER` | `iot` | Python database clients |
| `DB_PASSWORD` | None, required to connect | Python database clients |
| `KAFKA_BOOTSTRAP` | `localhost:9092` | Java ingestion and Python consumers |
| `KAFKA_TELEMETRY_TOPIC` | `iot.telemetry` | Python telemetry and stream consumers |
| `KAFKA_ALERTS_TOPIC` | `iot.alerts` | Python stream and alert workers |
| `METRICS_PORT` | `8000` | Python worker metrics |
| `SERVICE_NAME` | `unknown` | Python structured log service name |
| `PUSHGATEWAY_URL` | `http://localhost:9091` | KPI job's optional metrics push |

Compose passes `KAFKA_TELEMETRY_TOPIC` to both the Java ingestion producer and Python telemetry and stream consumers. `KAFKA_ALERTS_TOPIC` is shared by the stream and alert workers. Configure both through `services/.env` before starting the stack.

## Local ports

| Port | Service |
| --- | --- |
| `127.0.0.1:8080` | Device registry API |
| `127.0.0.1:8081` | Ingestion API |
| `127.0.0.1:9090` | Ingestion Actuator |
| `127.0.0.1:9091` | Registry Actuator |
| `127.0.0.1:5432` | TimescaleDB |
| `kafka:9092` | Kafka within Compose network |

Regenerating `IOT_DB_PASSWORD` on an existing database volume will not update the stored role password. Do not put it in Git.

See [the Compose file](../../services/docker-compose.yml) for the exact container environment passed to each service.
