Part of [iot-analytics](../../../README.md).

# kpi-job

Computes KPIs for one completed five-minute interval per run.

## Run

```bash
make kpi
```

## Test

```bash
(cd services/workers/kpi-job && PYTHONPATH=.. python -m pytest -q)
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `DB_PASSWORD` | Unset | SQL credential |
| `PUSHGATEWAY_URL` | `http://localhost:9091` | Optional metrics push endpoint |

## Interfaces

Reads `telemetry` and `job_watermarks`; writes `kpis` and advances the watermark in one transaction. The Compose `batch` profile runs it on demand. See [data model](../../../docs/reference/data-model.md).
