Part of [iot-analytics](../../README.md).

# device-registry

Spring Boot API for device metadata stored in PostgreSQL.

## Run

From the repository root: `docker compose -f services/docker-compose.yml up -d --build device-registry`.

## Test

```bash
mvn -B -ntp -f services/device-registry/pom.xml verify
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `DB_HOST` | `localhost` | Database hostname |
| `DB_NAME` | `iot` | Database name |
| `DB_USER` | `iot` | Database user |
| `DB_PASSWORD` | Required | Database password |

## Interfaces

HTTP on `8080`: `GET/POST /devices` and `GET/PUT/DELETE /devices/{id}`. Actuator listens on `9090` inside the container (`9091` on the Compose host). See the [API reference](../../docs/reference/api.md).
