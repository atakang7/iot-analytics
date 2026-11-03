Part of [iot-analytics](../../../README.md).

# monitoring

Helm subchart for Prometheus, Grafana and the namespace log collector.

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
| `monitoring.enabled` | `true` | Include monitoring subchart |
| `monitoring.routes.grafana` | `false` | Optional Grafana Route |

## Interfaces

Contains Prometheus, Grafana and log collector templates; `configs/dashboards/` holds the IoT panels. For the separately tested Kind monitoring stack see [observability](../../../platform/observability/README.md).
