Part of [iot-analytics](../../../README.md).

# infra

Helm subchart for lab Kafka, TimescaleDB and Loki resources.

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
| `infra.enabled` | `true` | Include lab dependencies in the parent chart |

## Interfaces

Templates include `kafka.yaml`, `timescaledb.yaml` and `loki.yaml`; `configs/schema.sql` initializes an empty database. Existing volumes need a separate migration. See [schema reference](../../../docs/reference/data-model.md).
