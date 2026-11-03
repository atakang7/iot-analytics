# iot-analytics

IoT telemetry lab for engineers testing Spring Boot ingestion, Kafka consumers and TimescaleDB analytics.

```text
+-----------+  HTTP  +-----------+  Kafka  +------------------+  SQL  +-------------+
| simulator | -----> | ingestion | ------> | telemetry-worker | ----> | timescaledb |
+-----------+        +-----------+         +------------------+       +-------------+
                         |
                         | Kafka
                         v
                 +---------------+  Kafka  +--------------+
                 | stream-worker | ------> | alert-worker |
                 +---------------+         +--------------+
```

The alert worker stores alerts in SQL; `kpi-job` calculates five-minute windows from stored telemetry.

## Quick start

Requires Docker Compose v2, Bash and OpenSSL.

```bash
cp services/.env.example services/.env
sed -i "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env
chmod 600 services/.env
make up
make smoke
```

## Layout

| Path | What it is |
| --- | --- |
| [services/](services/README.md) | Java APIs, Python workers and Compose |
| [contracts/telemetry/](contracts/telemetry/README.md) | Shared HTTP and Kafka reading contract |
| [iot-helm/](iot-helm/README.md) | OpenShift lab and application charts |
| [infra/kind/](infra/kind/README.md) | Disposable application cluster |
| [infra/cluster/](infra/cluster/README.md) | Three-node Kubernetes foundation test |
| [infra/db/](infra/db/README.md) | Backup and restore rehearsal |
| [platform/observability/](platform/observability/README.md) | Prometheus, Grafana, Loki and alerts |
| [policies/](policies/README.md) | Kubernetes admission policy |
| [validation/](validation/README.md) | Cluster and application checks |
| [delivery/](delivery/README.md) | OCI publication and release identity |
| [state/](state/README.md) | Git-tracked environment release intent |
| [simulator/](simulator/README.md) | OpenShift sensor emitter |
| [system-test/](system-test/README.md) | Bounded HTTP load check |
| [scripts/](scripts/README.md) | Smoke and manifest checks |
| [security/](security/README.md) | Workflow security checks |
| [.github/workflows/](.github/workflows/README.md) | CI and manual publish |

## Docs

[Docs index](docs/README.md) | [local operations](docs/how-to/operate-compose.md) | [API reference](docs/reference/api.md) | [architecture](docs/explanation/architecture.md)

## Limits

- HTTP `202` confirms a Kafka acknowledgment, not SQL persistence.
- Local Kafka and the HTTP APIs have no authentication.
- Bootstrap SQL applies to new database volumes only.
- Kind tests use disposable infrastructure; live OpenShift deployment is unverified.
