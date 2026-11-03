# Architecture

Telemetry uses a caller-supplied `deviceId`. The registry creates its own UUID for device metadata. The ingestion API accepts readings without a registry lookup, so a registration cannot establish source ownership.

Kafka separates HTTP acceptance from storage and alert evaluation. Ingestion returns `202` after a broker acknowledgment; the telemetry and stream workers act on the record independently.

The telemetry worker stores each reading by source, sensor and timestamp. The stream worker queries thresholds at startup, evaluates readings and publishes alert events. The alert worker stores alerts by deterministic ID. A separate KPI job advances a completed five-minute window together with its SQL writes.

Workers commit Kafka offsets after the associated SQL transaction or downstream publish acknowledgment. This permits replay after a crash; SQL uniqueness prevents duplicate stored identities. Recent rate and stuck-sensor histories remain in process memory.

## Deployment boundaries

[Compose](../../services/README.md) runs the local stack. [Kind](../../infra/kind/README.md) tests the portable [apps chart](../../iot-helm/charts/apps/README.md). The [parent chart](../../iot-helm/README.md) includes OpenShift BuildConfigs and stateful dependencies. CI does not install it on a live OpenShift cluster.

The separate [observability stack](../../platform/observability/README.md) uses disposable Prometheus, Loki, Grafana and Alertmanager instances.

See [delivery behavior](consistency.md) and [production limits](production-boundaries.md).
