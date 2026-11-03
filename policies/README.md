Part of [iot-analytics](../README.md).

# policies

Native Kubernetes admission checks for application Pod resources and process security.

## Run

```bash
make foundation-up
make foundation-validate
make foundation-down
```

## Test

```bash
bash -n policies/bin/smoke
```

## Config

| Setting | Value | What |
| --- | --- | --- |
| Namespace label | `iot-policy=enforce` | Policy binding selector |
| `failurePolicy` | `Fail` | Reject failed evaluations |
| Action | `Deny` | Reject invalid Pods |

## Interfaces

`admission.yaml` requires CPU and memory bounds, a nonroot UID, read-only root filesystem, dropped capabilities and disabled privilege escalation. `bin/smoke` tests allowed and denied fixtures with API server dry-runs. See [cluster validation](../validation/cluster/README.md).
