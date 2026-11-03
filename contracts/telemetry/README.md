Part of [iot-analytics](../../README.md).

# telemetry contract

HTTP ingestion and Python Kafka consumers validate the same reading payload.

## Test

```bash
mvn -B -ntp -f services/ingestion/pom.xml verify
(cd services/workers/telemetry-worker && PYTHONPATH=.. python -m pytest -q)
```

## Interfaces

`POST /telemetry` rejects invalid JSON fields with HTTP `400`. Python consumers recheck Kafka events that bypass HTTP ingestion. See the [field rules](../../docs/reference/events.md) and [API statuses](../../docs/reference/api.md).
