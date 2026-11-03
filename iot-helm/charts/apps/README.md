Part of [iot-analytics](../../../README.md).

# apps

Helm subchart for the six application workloads, Services and optional OpenShift Routes.

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
| `apps.imageMode` | `lab` | OpenShift build, local Kind image or release digest |
| `apps.kafkaBootstrap` | `kafka:9092` | Broker endpoint |
| `apps.routes.enabled` | `false` | API Routes |

## Interfaces

Templates create API Deployments, worker Deployments and a KPI CronJob. Image modes are defined in [Helm reference](../../../docs/reference/helm.md).
