Part of [iot-analytics](../README.md).

# iot-helm

Parent Helm chart for an OpenShift lab and its portable application subchart.

## Run

```bash
helm dependency build iot-helm
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml
```

## Test

```bash
helm lint iot-helm -f iot-helm/values-dev.yaml
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `apps.imageMode` | `lab` | Image source selection |
| `apps.routes.enabled` | `false` | API exposure |
| `monitoring.routes.grafana` | `false` | Grafana exposure |

## Interfaces

| Chart | Resources |
| --- | --- |
| [apps](charts/apps/README.md) | API, worker and batch workloads |
| [infra](charts/infra/README.md) | Kafka, TimescaleDB and Loki |
| [monitoring](charts/monitoring/README.md) | Metrics, logs and dashboards |

See [Helm values](../docs/reference/helm.md) and [OpenShift procedure](../docs/how-to/openshift-lab.md).
