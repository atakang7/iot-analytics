Part of [iot-analytics](../../README.md).

# ingestion

Spring Boot API that acknowledges telemetry after Kafka accepts the record.

## Run

From the root: `docker compose -f services/docker-compose.yml up -d --build ingestion`.

## Test

```bash
mvn -B -ntp -f services/ingestion/pom.xml verify
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `KAFKA_BOOTSTRAP` | `localhost:9092` | Broker address |
| `KAFKA_TELEMETRY_TOPIC` | `iot.telemetry` | Output topic |

## Interfaces

`POST /telemetry` listens on `8081`; `GET /telemetry/health` returns process status. The producer writes the configured telemetry topic with `deviceId` as the message key. Actuator listens on `9090`. See [API responses](../../docs/reference/api.md) and [event fields](../../docs/reference/events.md).
