Part of [iot-analytics](../../README.md).

# kind

Disposable Kubernetes runtime for all six application images and local dependencies.

## Run

```bash
make kind-up
make kind-smoke
make kind-down
```

## Test

```bash
bash -n infra/kind/bin/up infra/kind/bin/down
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `IOT_KIND_CLUSTER` | `iot-analytics` | New Kind cluster name |
| `IOT_KIND_NAMESPACE` | `iot-validation` | Application namespace |

## Interfaces

`bin/up` creates application and dependency namespaces, loads local `iot/*:kind` images, and installs the [apps chart](../../iot-helm/charts/apps/README.md). Dependency storage is ephemeral. `bin/down` removes only the named Kind cluster. See [Kubernetes validation](../../docs/how-to/test-kubernetes.md).
