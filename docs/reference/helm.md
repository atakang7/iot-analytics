# Helm charts and image modes

The parent chart at [iot-helm](../../iot-helm/) has three subcharts: `infra`, `apps` and `monitoring`. Its OpenShift BuildConfigs, ImageStreams and Routes are not portable to vanilla Kubernetes.

| Setting | Default | Effect |
| --- | --- | --- |
| `infra.enabled` | `true` | Includes Kafka, TimescaleDB and Loki in the OpenShift lab |
| `apps.enabled` | `true` | Includes six application workloads |
| `monitoring.enabled` | `true` | Includes Prometheus, Grafana and log collector |
| `apps.imageMode` | `lab` | Picks lab, kind or release image mode |
| `apps.images` | Empty | Requires six immutable references when image mode is `release` |
| `apps.dbHost` | `timescaledb` | Database address for workers |
| `apps.kafkaBootstrap` | `kafka:9092` | Broker address for applications |
| `apps.routes.enabled` | `false` | Keeps API Routes private unless opted in |
| `monitoring.routes.grafana` | `false` | Keeps Grafana Route private unless opted in |

`lab` enables OpenShift binary builds. `kind` renders application resources using local images loaded into the disposable cluster. `release` requires the six digest-pinned GHCR images and omits application BuildConfigs and ImageStreams.

The portable `iot-helm/charts/apps` leaf chart runs inside the Kind application tests. The parent chart is rendered and linted in CI but is not installed into a real OpenShift environment.

~~~bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml
~~~

Production needs operator-provided namespaces, registry permissions, Secrets, network policy, storage and migrations. See [OpenShift lab checks](../how-to/openshift-lab.md).
