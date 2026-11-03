Part of [iot-analytics](../../README.md).

# db

TimescaleDB dump and isolated recovery rehearsal scripts.

## Run

```bash
make backup DEST=/tmp/iot-snapshot.dump
```

## Test

```bash
bash -n infra/db/bin/backup infra/db/bin/restore-check
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `IOT_DB_PASSWORD` | Required in `services/.env` | Compose database credential |

## Interfaces

`bin/backup` accepts an absolute output path and writes a custom-format dump with SHA-256 checksum. `bin/restore-check` accepts the dump path and checks `ci-recovery` fixtures in a separate database. For live recovery use [the backup guide](../../docs/how-to/backup-and-restore.md).
