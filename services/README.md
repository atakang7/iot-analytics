Part of [iot-analytics](../README.md).

# services

Compose runs two Java APIs, four Python workers, Kafka and TimescaleDB.

## Run

```bash
make up
make smoke
```

## Test

```bash
mvn -B -ntp -f services/ingestion/pom.xml verify
mvn -B -ntp -f services/device-registry/pom.xml verify
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `IOT_DB_PASSWORD` | Required in `services/.env` | Shared local SQL credential |

## Interfaces

| Component | Interface |
| --- | --- |
| [ingestion](ingestion/README.md) | HTTP telemetry to Kafka |
| [device-registry](device-registry/README.md) | HTTP device metadata |
| [workers](workers/README.md) | Kafka, SQL and KPI processing |
| [schema.sql](schema.sql) | Fresh SQL bootstrap |
| [docker-compose.yml](docker-compose.yml) | Local containers and ports |

See [configuration](../docs/reference/configuration.md) for complete local settings.
