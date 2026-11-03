# IoT Analytics

An end-to-end telemetry laboratory: a Spring Boot 4 / Java 21 device registry and ingestion API,
Kafka streaming consumers, TimescaleDB storage and five-minute analytics. The
repository deliberately separates **application correctness**, **local operation**,
and an **optional OpenShift deployment experiment**.

## Repository map

| Path | Responsibility |
| --- | --- |
| [services/](services/README.md) | Java APIs, Python workers, database schema, local Compose |
| [scripts/](scripts/) | Simulator and reproducible smoke checks |
| [system-test/](system-test/README.md) | Bounded, measured HTTP load testing |
| [iot-helm/](iot-helm/README.md) | OpenShift-oriented chart (not a vanilla Kubernetes chart) |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Event contract, delivery and consistency model |
| [RUNBOOK.md](RUNBOOK.md) | Start, verify, investigate, recover, shut down |
| [.github/workflows/ci.yaml](.github/workflows/ci.yaml) | GitHub-hosted verification gates |

## Data flow

```text
                           ┌───────────────────┐
POST /devices ────────────►│ Spring registry   │──────────► devices
                           └───────────────────┘               │
                                                               ▼
POST /telemetry  ──► Spring ingestion ──► Kafka: iot.telemetry ─┬─► telemetry worker
                 202 on Kafka acknowledgment                  │       │
                                                             │       ▼
                                                             │   TimescaleDB
                                                             │    telemetry
                                                             │       │
                                                             │       ▼
                                                             │  5-minute KPI job ──► kpis
                                                             │
                                                             └─► stream worker
                                                                    │
                                                              Kafka: iot.alerts
                                                                    │
                                                              alert worker ──► alerts
```

The registry owns its UUID database key; the telemetry `deviceId` is a
logical sensor source identifier and is not currently foreign-key validated
against the registry.

## Quick start (local development)

Requirements: Docker Engine with Compose v2, a Bash shell, and `openssl`.

```bash
cp services/.env.example services/.env
sed -i "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env
chmod 600 services/.env

docker compose -f services/docker-compose.yml up -d --build
bash scripts/smoke-local.sh
```

On a fresh volume, Compose initializes the TimescaleDB schema automatically.
It starts the APIs, Kafka, three long-running workers and the database. The
`kpi-job` is deliberately one-shot:

```bash
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

Use [RUNBOOK.md](RUNBOOK.md) for diagnostics, clean shutdown and safe upgrades.

## API contract

- `POST /devices` on `127.0.0.1:8080`: JSON device metadata; returns 201 + `Location`.
- `GET /devices`, `GET /devices/{id}`, `PUT /devices/{id}`, `DELETE /devices/{id}`.
- `POST /telemetry` on `127.0.0.1:8081`: returns **202 only after Kafka acknowledges the publish**; 400 for invalid input, 503 for publish failure.
- `GET /telemetry/health`: ingestion process-only health endpoint.
- Management health + Prometheus metrics: `127.0.0.1:9090/actuator/...` for ingestion, `127.0.0.1:9091/actuator/...` for registry. Separate management ports are not exposed by the OpenShift Route.

Example:

```bash
curl -i http://127.0.0.1:8081/telemetry \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"motor-1","deviceType":"motor","sensorId":"temp-1","sensorType":"temperature","timestamp":"2026-11-03T10:00:00Z","unit":"celsius","value":{"value":72.5}}'
```

`202` means Kafka accepted the event, **not** that downstream storage/analytics
has completed. See [event semantics](docs/ARCHITECTURE.md).

## Immutable release and promotion

The [delivery workflow](delivery/README.md) implements build-once OCI
publication with a critical-vulnerability gate, CycloneDX SBOMs and keyless
Cosign signatures. Deployments require a six-service digest manifest; the
OpenShift chart rejects mutable release tags and removes in-cluster BuildConfigs
in release mode.

[Environment state](state/README.md) is versioned in Git:
`dev -> stage -> prod`. Promotion preserves the original six digests and CI
checks that each promoted release appeared in the preceding environment's
**Git history**. All states initially contain `null` because publication and
cluster deployments have not yet occurred. No live deployment is implied.

## Verification and operating limits

Pull requests run Python tests, Java tests, **six image builds**, Helm lint and
rendering, a real TimescaleDB initialization/constraint test, and a full
HTTP → Kafka → storage → alert → KPI integration smoke test.

This is a reproducible **development/portfolio platform, not a production
service**. Local Kafka has no authentication/TLS, APIs have no authentication
or rate limits, and the database uses a single persistent Compose volume.
The OpenShift manifests remain an optional, environment-specific lab; CI
does not claim to have deployed to a live OpenShift cluster. Existing database
volumes need explicit migrations; the SQL files initialize **new volumes only**.

License: [MIT](LICENSE).
