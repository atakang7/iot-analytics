# IoT Analytics

An HTTP-to-Kafka telemetry pipeline with Spring Boot APIs, Python consumers, TimescaleDB storage and five-minute KPIs. Docker Compose runs the local system; GitHub Actions checks it against disposable Kubernetes clusters.

## Run it

Requires Docker Compose v2, Bash and OpenSSL.

```bash
cp services/.env.example services/.env
sed -i "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env
chmod 600 services/.env
make up
make smoke
make kpi
```

Keep the same password for subsequent starts. `make down` preserves the database volume.

## Event path

```text
+-----------------+   HTTP   +-----------+  Kafka   +------------------+
| telemetry client| -------> | ingestion | -------> | telemetry-worker |
+-----------------+          +-----------+          +------------------+
                                                          |
                                                        writes
                                                          v
                                                     +-----------+
                                                     | telemetry |
                                                     +-----------+
                                                          |
                                                        reads
                                                          v
                                                      +---------+
                                                      | kpi-job |
                                                      +---------+

+-----------+  Kafka   +---------------+  Kafka   +--------------+
| ingestion | -------> | stream-worker | -------> | alert-worker |
+-----------+          +---------------+          +--------------+
                                                     |
                                                   writes
                                                     v
                                                   alerts
```

The registry stores device metadata. Telemetry uses a separate logical device identifier and does not check it against the registry. An ingestion response of `202` confirms a Kafka acknowledgment; it does not confirm persistence.

## Documentation

- [Start from a blank machine](docs/tutorials/local-pipeline.md)
- [Operate and recover](docs/how-to/operate-compose.md)
- [APIs, event fields and configuration](docs/reference/index.md)
- [Why the system works this way](docs/explanation/architecture.md)
- [Docs index](docs/README.md), [domain terms](CONTEXT.md), [glossary](GLOSSARY.md)
- [Instructions for coding agents](AGENTS.md)

Java and Python unit tests, database invariants, OCI build and signing tests, full Compose integration, Kubernetes admission and observability tests run in [GitHub Actions](.github/workflows/ci.yaml).

This repository is a working engineering lab. Its OpenShift path has not been tested on a live production cluster. Local Kafka lacks authentication, and the deployment does not include HA, live database migrations or production secrets management. See [production gaps](docs/explanation/production-boundaries.md).

[MIT license](LICENSE).
