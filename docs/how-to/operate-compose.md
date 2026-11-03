# Operate the local Compose stack

Run commands from the repository root. Configure `services/.env` once, following the [tutorial](../tutorials/local-pipeline.md).

## Start and verify

```bash
make up
make ps
make smoke
```

For an API-only check, run `make api-smoke`. If the system is running but KPIs are missing, run `make kpi` to process the earliest unprocessed closed window.

## Inspect failures

```bash
docker compose -f services/docker-compose.yml ps -a
docker compose -f services/docker-compose.yml logs --tail=150 \
  kafka timescaledb ingestion device-registry telemetry-worker stream-worker alert-worker
```

An HTTP `202` means Kafka acknowledged the publish. If the reading is absent from TimescaleDB, check the telemetry worker logs. If the reading exists but no alert appears, check the stream and alert workers. Threshold changes only take effect when the stream worker reloads them.

The worker commits offsets after the side effect. A malformed Kafka event can block its partition; preserve the topic, partition, offset and payload before repairing or replaying it.

## Check progress

```bash
docker compose -f services/docker-compose.yml exec -T timescaledb \
  psql -U iot -d iot -c 'SELECT count(*) FROM telemetry'
docker compose -f services/docker-compose.yml exec -T timescaledb \
  psql -U iot -d iot -c 'SELECT count(*) FROM alerts'
docker compose -f services/docker-compose.yml exec -T timescaledb \
  psql -U iot -d iot -c 'SELECT * FROM job_watermarks'
```

## Shut down

```bash
make down
```

Avoid `docker compose down -v` unless you intend to delete the local database. [Back up first](backup-and-restore.md) before any schema or volume change.
