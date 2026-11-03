Part of [iot-analytics](../../../README.md).

# log collector

Python process that copies application Pod logs into Loki in the disposable Kind cluster.

## Run

```bash
make kind-up
bash platform/observability/bin/up
```

## Test

```bash
(cd platform/observability/collector && python3 -m unittest discover -p 'test_*.py' -v)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `LOKI_URL` | Set by Kubernetes manifest | Loki push endpoint |

## Interfaces

`collector.py` polls the namespaced Kubernetes Pod log API; `kind.yaml` defines the collector Deployment and access rules. [Observability checks](../../../docs/how-to/test-kubernetes.md) exercise log delivery.
