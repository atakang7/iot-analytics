# Run a telemetry reading through the pipeline

This tutorial starts the local system, sends a reading and looks for its stored effects.

## Prepare the database password

You need Docker Compose v2, OpenSSL, Bash and a fresh local checkout.

```bash
cp services/.env.example services/.env
sed -i "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env
chmod 600 services/.env
make up
make ps
```

Wait for Kafka, TimescaleDB and both APIs to become healthy. The containers build on the first start.

## Run the complete sample

```bash
make smoke
```

The smoke script creates a device, publishes telemetry, checks storage and alerts, and runs the KPI batch. A successful command exits with status 0. If it fails, inspect `make logs`.

## Inspect the stored results

```bash
docker compose -f services/docker-compose.yml exec -T timescaledb \
  psql -U iot -d iot -c 'SELECT count(*) FROM telemetry'
docker compose -f services/docker-compose.yml exec -T timescaledb \
  psql -U iot -d iot -c 'SELECT count(*) FROM alerts'
docker compose -f services/docker-compose.yml exec -T timescaledb \
  psql -U iot -d iot -c 'SELECT job_name, last_processed_at FROM job_watermarks'
```

A reading may exist before its derived KPI is calculated. The KPI job handles one closed five-minute window per invocation. You can run it again with `make kpi`.

## Stop the stack

```bash
make down
```

This stops containers and keeps the data volume. For the next start use `make up` without regenerating the password.

The [HTTP reference](../reference/api.md) explains each response status.
