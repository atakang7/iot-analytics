# IoT Analytics

Java 21 APIs send sensor readings through Kafka to Python 3.11 workers and TimescaleDB for alerts and five-minute KPIs.

```text
+-----------+ Kafka +---------------+ Kafka +------------------+ writes +-------------+ reads +---------+
| ingestion | ----> | iot.telemetry | ----> | telemetry-worker | ------> | timescaledb | ----> | kpi-job |
+-----------+       +---------------+       +------------------+         +-------------+       +---------+
                         |
                         | Kafka
                         v
                 +---------------+ Kafka +--------------+
                 | stream-worker | ----> | alert-worker |
                 +---------------+       +--------------+
```

The `stream-worker` publishes to `iot.alerts`; `alert-worker` writes those alerts to TimescaleDB.

```text
+--------------+ trigger +---------+
| pull_request | ------> | ci.yaml |
+--------------+         +---------+
                             |       |
                           runs     runs
                             v       v
                         +------+ +------------+
                         | java | | kubernetes |
                         +------+ +------------+
```

CI runs other checks too; see [the workflow](.github/workflows/ci.yaml) and [CI notes](.github/workflows/README.md).

## Run

Requires Docker Engine with Compose v2, Bash, OpenSSL and `sed`; run from the repository root.

```bash
[ -e services/.env ] || sed "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env.example > services/.env
chmod 600 services/.env
docker compose -f services/docker-compose.yml up -d --build
bash scripts/smoke-local.sh
```

Run a KPI batch or stop without deleting the database volume:

```bash
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
docker compose -f services/docker-compose.yml down
```

API ports: registry `127.0.0.1:8080`, ingestion `127.0.0.1:8081`; see [the runbook](RUNBOOK.md) for checks and [the event contract](docs/ARCHITECTURE.md) for payloads.

## Config

Set these in `services/.env` using [the example](services/.env.example).

| var | default | what |
| --- | --- | --- |
| `IOT_DB_PASSWORD` | none (required) | Database user password |
| `KAFKA_TELEMETRY_TOPIC` | `iot.telemetry` | Telemetry topic |
| `KAFKA_ALERTS_TOPIC` | `iot.alerts` | Alert topic |

## Limits

- Local Kafka and APIs have no authentication; ports are bound to localhost.
- HTTP `202` means Kafka acknowledged a message, not that the database stored it.
- Existing TimescaleDB volumes need explicit migrations; SQL initialization runs only on new volumes.
- Stream-worker detection state resets on restart; malformed events can block a consumer.
- OpenShift deployment is manual and has not been verified against a live cluster; see [OpenShift notes](docs/OPENSHIFT.md).

[MIT license](LICENSE).
