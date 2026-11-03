Part of [iot-analytics](../README.md).

# validation

Checks against disposable Kubernetes deployments and running application components.

## Run

```bash
make kind-up
make kind-smoke
make kind-down
```

## Test

```bash
bash -n validation/kind/e2e.sh validation/cluster/validate.sh validation/observability/smoke.sh
```

## Interfaces

| Component | Check |
| --- | --- |
| [kind](kind/README.md) | HTTP, Kafka, SQL, KPI pipeline |
| [cluster](cluster/README.md) | Nodes, networking, volumes and admission |
| [observability](observability/README.md) | Prometheus, Grafana, alerts and logs |

See [test procedures](../docs/how-to/test-kubernetes.md).
