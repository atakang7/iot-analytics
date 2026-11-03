Part of [iot-analytics](../README.md).

# scripts

Local smoke checks, manifest validators and OpenShift helper commands.

## Run

```bash
bash scripts/smoke-local.sh
```

## Test

```bash
bash -n scripts/*.sh
python3 scripts/verify-docs.py
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `INGESTION_URL` | `http://127.0.0.1:8081` | Smoke API |
| `REGISTRY_URL` | `http://127.0.0.1:8080` | Registry API |
| `NAMESPACE` | `atakangul-dev` | OpenShift helper namespace |

## Interfaces

`smoke-local.sh` tests APIs, broker, persistence and KPIs. `verify-helm.py`, `verify-kind.py` and `verify-observability.py` inspect manifests. `verify-docs.py` checks Markdown navigation. `add-devices.sh` and `build-and-deploy.sh` use `oc`. See [verification commands](../docs/reference/verification.md).
