# IoT Analytics

A local telemetry pipeline with Java 21 APIs, Kafka, Python 3.11 workers and TimescaleDB. It accepts sensor readings, stores them without duplicate samples, generates alerts and computes five-minute KPIs.

## Run locally

You need Docker Engine with Compose v2, Bash, OpenSSL and `sed`. Run these commands from the repository root:

```bash
[ -e services/.env ] || sed "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env.example > services/.env
chmod 600 services/.env
docker compose -f services/docker-compose.yml up -d --build
bash scripts/smoke-local.sh
```

Keep `services/.env` between restarts; changing the password does not change the database user's password in an existing volume. The smoke test creates a device, sends the same reading twice, checks storage and alerts, then runs the KPI job.

The batch job is opt-in:

```bash
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

Stop the stack without deleting data:

```bash
docker compose -f services/docker-compose.yml down
```

See [RUNBOOK.md](RUNBOOK.md) for logs, backups and recovery checks.

## Configuration

`services/.env.example` lists the local settings:

| Variable | Purpose |
| --- | --- |
| `IOT_DB_PASSWORD` | Required database password; generate a unique value |
| `KAFKA_TELEMETRY_TOPIC` | Input topic, default `iot.telemetry` |
| `KAFKA_ALERTS_TOPIC` | Alert topic, default `iot.alerts` |

Compose passes the topic names to the relevant services. The Java ingestion service reads `KAFKA_TELEMETRY_TOPIC`; Python workers read both names from their environment. Local HTTP ports are bound to `127.0.0.1`.

## API and data flow

```text
POST /devices  -> device-registry -> TimescaleDB.devices

POST /telemetry -> ingestion -> Kafka iot.telemetry
                                 |-> telemetry-worker -> TimescaleDB.telemetry
                                 |-> stream-worker -> Kafka iot.alerts
                                                       |-> alert-worker -> TimescaleDB.alerts

TimescaleDB.telemetry -> kpi-job -> TimescaleDB.kpis
```

The registry listens on `127.0.0.1:8080` (`POST /devices`, `GET /devices`, `GET /devices/{id}`, `PUT /devices/{id}`, `DELETE /devices/{id}`). Ingestion listens on `127.0.0.1:8081`.

```bash
curl -i http://127.0.0.1:8081/telemetry \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"motor-1","deviceType":"motor","sensorId":"temp-1","sensorType":"temperature","timestamp":"2026-11-03T10:00:00Z","unit":"celsius","value":{"value":72.5}}'
```

HTTP `202` confirms Kafka acknowledged the message, not that SQL storage has finished. Workers commit offsets after a successful write or publish. The telemetry key is `(device_id, sensor_id, timestamp)`; alerts use stable IDs to handle retries. Each KPI invocation processes one closed five-minute window. Details are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Verification and deployment

[GitHub Actions](.github/workflows/ci.yaml) runs Java builds and tests, Python tests, seven image builds, Helm checks and a real HTTP-to-database smoke test. It also checks a disposable Kubernetes cluster, backup/restore behavior, the monitoring stack and an OCI publish/signing rehearsal.

For a local Kubernetes run:

```bash
make kind-up
make kind-smoke
make kind-down
```

The [OpenShift Helm chart](iot-helm/README.md) is an optional deployment path, with an [immutable release workflow](delivery/README.md). CI tests the chart but does not deploy to a live OpenShift cluster. Environment release files in `state/` start empty.

## Limits

This is a development and integration-test setup, not a public-facing service. The local Kafka broker has no authentication or TLS, the APIs have no authentication or rate limiting, and TimescaleDB uses one persistent Compose volume. SQL initialization applies to new volumes only; existing data needs a reviewed migration. Telemetry device IDs are not foreign keys to registry entries.

Licensed under [MIT](LICENSE).
