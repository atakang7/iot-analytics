# Validate Kubernetes behavior

Requires Docker, Kind, kubectl, Helm and Bash. These commands create disposable local clusters and do not contact a production OpenShift environment.

## Application data path

```bash
make kind-up
make kind-smoke
```

The Kind integration test checks the real HTTP, Kafka, TimescaleDB, alert and KPI path. The application namespace is subject to a native admission policy; Kafka and TimescaleDB run in a separate dependency namespace.

## Metrics and logs

With the application cluster still running:

```bash
make observability-up
make observability-smoke
make kind-down
```

The smoke check requires healthy Prometheus scrapes, loaded alert rules, working Grafana data sources and telemetry worker messages in Loki. The test backends use temporary storage.

## Network, storage and admission

The independent three-node foundation cluster checks DNS, cross-worker traffic, persistent volumes and Kubernetes API admission.

```bash
make foundation-up
make foundation-validate
make foundation-down
```

The scripts refuse to reuse an existing cluster with their reserved names. Do not change those guards to operate against your active Kubernetes context. See [platform limitations](../explanation/production-boundaries.md).
