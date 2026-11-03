# Operator runbook

Commands below assume the repository root, Docker Compose v2 and Bash.

## Start from a NEW volume

```bash
[ -e services/.env ] || sed "s/^IOT_DB_PASSWORD=.*/IOT_DB_PASSWORD=$(openssl rand -hex 32)/" services/.env.example > services/.env
chmod 600 services/.env

docker compose -f services/docker-compose.yml up -d --build
docker compose -f services/docker-compose.yml ps
bash scripts/smoke-local.sh
```

Only create `services/.env` if it does not exist. **Never commit the password**. For normal restarts, keep
the existing value: PostgreSQL role passwords persist in its volume.

## Verify

```bash
docker compose -f services/docker-compose.yml ps
bash scripts/test-ingestion.sh
bash scripts/smoke-local.sh
docker compose -f services/docker-compose.yml logs --tail=100 \
  kafka timescaledb ingestion device-registry telemetry-worker stream-worker alert-worker
```

Inspect SQL (the container has its own database credentials):

```bash
docker compose -f services/docker-compose.yml exec timescaledb \
  psql -U iot -d iot -c 'SELECT count(*) FROM telemetry'
docker compose -f services/docker-compose.yml exec timescaledb \
  psql -U iot -d iot -c 'SELECT count(*) FROM alerts'
docker compose -f services/docker-compose.yml exec timescaledb \
  psql -U iot -d iot -c 'SELECT * FROM job_watermarks'
```

Run one deterministic KPI batch (the Compose batch profile is opt-in):

```bash
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

## Troubleshooting

1. **API not ready:** use `docker compose ... ps` and Java container logs.
   The health endpoint only checks the ingestion process, not Kafka liveness.
2. **No telemetry:** check Kafka health, telemetry worker logs and the
   `iot.telemetry` topic with `bash scripts/consume-kafka.sh`.
3. **No alerts:** look for a threshold breach, then inspect stream/alert worker
   logs; thresholds are loaded at startup.
4. **KPI missing:** the job handles one *completed* 5-minute window. Query
   `job_watermarks` and rerun the job to advance the backlog window by window.
5. **Poison event blocks a consumer:** inspect logs, preserve message content
   and offset, and repair the producer/input. Offsets are not committed on errors.

## Protected backups and recovery rehearsal

```bash
bash infra/db/bin/backup /absolute/backup/dir/iot.dump
# This check is for a backup containing the CI fixtures:
bash infra/db/bin/restore-check /absolute/backup/dir/iot.dump
```

CI exercises the complete `pg_dump` → TimescaleDB restore cycle into a new
temporary database, and asserts source data, hypertables and unique indexes.
The live `iot` database is never overwritten. See
[the recovery boundary](infra/db/README.md) for external backups and the
separate production recovery procedure.

## Existing database upgrade

`services/schema.sql` and the two Helm copies are **bootstrap definitions**
run only on a new database. They do **not** upgrade existing TimescaleDB volumes.
Before applying this rewrite to an existing environment, back up data and
build a reviewed SQL migration for the changed hypertables, unique indexes,
alerts and KPI schema. Do not assume a restart or `docker compose up`
migrates state; do not delete the volume to hide a migration problem.

For backups, use a destination outside the repository and retain copies
separately from the Compose volume.

## Shutdown / cleanup

```bash
docker compose -f services/docker-compose.yml down
```

This preserves the database volume. **Do not use `down -v` unless you intend
to permanently erase your local data.**

## Deployment

This repository's Helm chart is **OpenShift-specific**. GitHub Actions
validates the chart syntax but does not provision/validate a live cluster.
There is no automatic OpenShift CD controller. See
[iot-helm/README.md](iot-helm/README.md) and
[docs/OPENSHIFT.md](docs/OPENSHIFT.md) for the manual lab deployment boundary.
