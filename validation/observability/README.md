Part of [iot-analytics](../../README.md).

# observability validation

Live checks for Prometheus scrapes, Grafana data sources, alerts and worker logs.

## Run

```bash
make kind-up
make kind-smoke
make observability-up
make observability-smoke
make kind-down
```

## Test

```bash
bash -n validation/observability/smoke.sh
python3 -m compileall -q validation/observability
```

## Interfaces

`smoke.sh` opens temporary port forwards; `verify.py` queries Prometheus, Grafana, Alertmanager and Loki. Requires the `kind-iot-analytics` context. See [observability setup](../../platform/observability/README.md).
