# Helm reference

The [parent chart](../../iot-helm/README.md) contains [apps](../../iot-helm/charts/apps/README.md), [infra](../../iot-helm/charts/infra/README.md) and [monitoring](../../iot-helm/charts/monitoring/README.md).

| Setting | Default | Effect |
| --- | --- | --- |
| `infra.enabled` | `true` | Kafka, TimescaleDB and Loki lab resources |
| `apps.enabled` | `true` | Six application workloads |
| `monitoring.enabled` | `true` | Prometheus, Grafana and log collector |
| `apps.imageMode` | `lab` | Image selection: `lab`, `kind`, `release` |
| `apps.images` | Empty | Six digests required in `release` mode |
| `apps.dbHost` | `timescaledb` | Worker database hostname |
| `apps.kafkaBootstrap` | `kafka:9092` | Broker address |
| `apps.routes.enabled` | `false` | API OpenShift Routes |
| `monitoring.routes.grafana` | `false` | Grafana OpenShift Route |

| Mode | Image source | Deployment surface |
| --- | --- | --- |
| `lab` | OpenShift binary BuildConfigs | OpenShift lab |
| `kind` | Local `iot/*:kind` images | Disposable Kind |
| `release` | Digest-pinned GHCR references | Operator-managed environment |

OpenShift ImageStreams, BuildConfigs and Routes are present in the parent chart. The application subchart also runs on Kind. The database bootstrap schema is in [configs/schema.sql](../../iot-helm/charts/infra/configs/schema.sql).
