Part of [iot-analytics](../../README.md).

# Kind application validation

Shell checks for the deployed HTTP, Kafka, TimescaleDB, alerts and KPI path.

## Run

```bash
make kind-up
make kind-smoke
make kind-down
```

## Test

```bash
bash -n validation/kind/e2e.sh
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `IOT_KIND_CLUSTER` | `iot-analytics` | Allowed Kind context |
| `IOT_KIND_NAMESPACE` | `iot-validation` | App namespace |

## Interfaces

`e2e.sh` opens temporary API port forwards, publishes test readings and queries SQL results. It refuses a nonmatching Kind context. See [Kubernetes procedure](../../docs/how-to/test-kubernetes.md).
