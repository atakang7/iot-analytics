# Backup and recovery

`bin/backup` takes a protected, non-overwriting `pg_dump -Fc` snapshot and
writes a SHA-256 checksum. Store backups **outside the repository** and off-host.

`bin/restore-check` is a non-destructive CI rehearsal: it creates a new
temporary database, invokes the TimescaleDB pre/post-restore hooks, restores
from the archive, tests fixture rows and replay-safety indexes, and drops only
the temporary test database. It does not touch `iot` except to read a dump.

```bash
bash infra/db/bin/backup /absolute/backup/dir/iot.dump
bash infra/db/bin/restore-check /absolute/backup/dir/iot.dump
```

The restore-check requires the CI fixture rows and is **not** a production
data-validation tool. For live recovery, follow the
[official TimescaleDB logical restore procedure](https://www.tigerdata.com/docs/deploy/self-hosted/backup-and-restore/logical-backup)
on a separate database and verify complete business data before cutover.
This is not automated off-site backup, WAL/PITR, encryption, HA or a data
migration process. Production RPO/RTO have not been established.
