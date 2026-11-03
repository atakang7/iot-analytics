Part of [iot-analytics](../../README.md).

# observability

Private Prometheus, Alertmanager, Grafana and Loki stack for the Kind test environment.

```text
+------------------+  logs  +---------------+  HTTP  +------+
| telemetry-worker | -----> | log-collector | -----> | Loki |
+------------------+        +---------------+        +------+
```

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
(cd platform/observability/collector && python3 -m unittest discover -p 'test_*.py' -v)
```

## Config

| Path | What |
| --- | --- |
| `config/prometheus.yml` | Scrape targets |
| `config/rules.yml` | Alert rules |
| `config/loki.yml` | Loki storage and listener |

## Interfaces

`bin/up` creates `iot-observability` and deploys [collector](collector/README.md). [Live tests](../../validation/observability/README.md) check five application scrapes, dashboards and log arrival. Storage and alert sink are temporary.
