Part of [iot-analytics](../../README.md).

# cluster validation

Live checks for a three-node Kind cluster's network, persistent storage and admission.

## Run

```bash
make foundation-up
make foundation-validate
make foundation-down
```

## Test

```bash
bash -n validation/cluster/validate.sh
```

## Config

| Setting | Value | What |
| --- | --- | --- |
| Context | `kind-iot-foundation` | Required cluster |
| Namespace | `iot-cluster-proof` | Temporary test resources |

## Interfaces

`validate.sh` checks Ready nodes, cross-worker Service traffic, persistent volume data after Pod replacement, and allowed and denied admission fixtures. Test namespace cleanup is scoped. See [foundation setup](../../infra/cluster/README.md).
