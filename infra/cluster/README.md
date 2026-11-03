Part of [iot-analytics](../../README.md).

# cluster

Three-node Kind cluster for network, storage and admission checks.

## Run

```bash
make foundation-up
make foundation-validate
make foundation-down
```

## Test

```bash
bash -n infra/cluster/bin/up infra/cluster/bin/down
```

## Config

| Setting | Default | What |
| --- | --- | --- |
| Cluster | `iot-foundation` | Dedicated disposable Kind context |
| Nodes | 1 control plane, 2 workers | `kind.yaml` topology |

## Interfaces

`bin/up` provisions the cluster and applies [admission policy](../../policies/README.md). `validation/cluster/validate.sh` checks cross-worker DNS, Service traffic and persistent storage. `bin/down` removes the named cluster.
