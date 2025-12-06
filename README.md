# IoT Analytics Platform

Microservices-based IoT data platform deployed on OpenShift.

## Services

- **Device Registry** — device management, metadata
- **Ingestion** — receives sensor data, emits events
- **Analytics** — aggregates data, time-series storage

## Tech Stack

- Python / FastAPI
- PostgreSQL (Device Registry)
- InfluxDB (Analytics)
- RabbitMQ (messaging)
- OpenShift / Kubernetes
- GitHub Actions (CI/CD)
- Prometheus / Grafana (monitoring)
