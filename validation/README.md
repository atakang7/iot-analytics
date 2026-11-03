# Validation is evidence, not deployment

The golden reference distinguishes validation from configuration ownership.
This repo now makes that distinction executable:

- `services/`: Java/Python unit tests and local full-stack Compose E2E
- `iot-helm/`: OpenShift lab manifest checks and digest-pinned release mode
- `infra/kind/`: isolated Kubernetes foundation, ephemeral Kafka/TimescaleDB
- `validation/kind/e2e.sh`: running Pod, Service, health/metrics and full
  telemetry -> Kafka -> TimescaleDB/alert -> KPI integration proof
- `delivery/`: immutable OCI provenance and environment promotion rules

The kind test has no cluster ingress or production credentials. The validator
only exercises the state it was given and **does not repair it**; failures
require fixing the owning layer and rerunning the proof.

The [observability validator](observability/) also proves real Prometheus
scrapes, alert loading, Grafana provisioning, and Kubernetes Pod logs
reaching Loki. No validator changes infrastructure state to force success.

The independent [three-node cluster validation](cluster/README.md) verifies
Ready nodes, DNS/CNI traffic between workers, dynamic persistent volumes and
Kubernetes API admission allow/deny decisions, then cleans up only its own
temporary resources.
