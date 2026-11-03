# Operator runbook

Run commands from the repository root with Docker Compose v2 and Bash; [README](README.md) covers first-time setup.

## Verify

```bash
docker compose -f services/docker-compose.yml ps
bash scripts/test-ingestion.sh
bash scripts/smoke-local.sh
docker compose -f services/docker-compose.yml logs --tail=100 kafka timescaledb ingestion device-registry telemetry-worker stream-worker alert-worker
```

Inspect stored rows and the KPI checkpoint:

```bash
docker compose -f services/docker-compose.yml exec -T timescaledb psql -U iot -d iot -c 'SELECT count(*) FROM telemetry'
docker compose -f services/docker-compose.yml exec -T timescaledb psql -U iot -d iot -c 'SELECT count(*) FROM alerts'
docker compose -f services/docker-compose.yml exec -T timescaledb psql -U iot -d iot -c 'SELECT * FROM job_watermarks'
```

Run one completed five-minute KPI window:

```bash
docker compose -f services/docker-compose.yml --profile batch run --rm kpi-job
```

## Investigate

- API not ready: inspect `ps` and Java service logs; ingestion health does not check Kafka.
- Telemetry missing: check broker health, `telemetry-worker` logs and `bash scripts/consume-kafka.sh`.
- Alerts missing: inspect `stream-worker` and `alert-worker` logs; thresholds load at startup.
- KPI missing: inspect `job_watermarks`; each invocation advances only one closed window.
- Invalid Kafka event: preserve its payload and offset before repairing it; failed messages are not acknowledged.

## Backup

Save outside the checkout and keep a second copy:

```bash
bash infra/db/bin/backup /absolute/backup/dir/iot.dump
```

The following rehearsal expects a dump containing CI recovery fixtures:

```bash
bash infra/db/bin/restore-check /absolute/backup/dir/iot.dump
```

See [recovery notes](infra/db/README.md) for the restore boundary; the check does not overwrite the running `iot` database.

## Upgrade and stop

SQL files initialize empty volumes only; back up existing data and review a migration before changing the schema.

```bash
docker compose -f services/docker-compose.yml down
```

`down` preserves TimescaleDB storage; `down -v` deletes the local volume.

OpenShift deployment is manual; see [OpenShift notes](docs/OPENSHIFT.md).
