Part of [iot-analytics](../README.md).

# simulator

BusyBox sensor emitter for an existing OpenShift lab namespace.

## Run

```bash
NAMESPACE=my-lab bash simulator/deploy-simulator.sh motor-001 motor 5
```

## Test

```bash
bash -n simulator/*.sh
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `NAMESPACE` | `atakangul-dev` | OpenShift namespace |
| `DEVICE_ID` | Generated | Logical source identifier |
| `DEVICE_TYPE` | `motor` | Sensor preset |
| `INTERVAL` | `5` | Seconds between readings |
| `INGESTION_URL` | `http://ingestion:8081/telemetry` | Target HTTP API |

## Interfaces

`deploy-simulator.sh` creates a ConfigMap and Deployment; `simulator.sh` posts telemetry JSON. `cleanup-simulators.sh` removes simulator resources. Requires authorized `oc` access.
