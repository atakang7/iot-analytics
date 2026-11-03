# Back up the development database

The backup script dumps the current `iot` database into a private archive. Supply a new absolute path outside the repository.

```bash
mkdir -p /tmp/iot-snapshots
make backup DEST=/tmp/iot-snapshots/iot.dump
```

The command refuses to replace an existing file. It creates a SHA-256 checksum beside the archive. Move both files to protected storage off the host. A checksum detects accidental changes; it is not a tamper-proof signature.

## Rehearse restoration

The automated CI recovery test seeds disposable data, takes a dump and restores it to a separate database with the TimescaleDB pre/post restore hooks. It checks the source records, hypertables and unique indexes.

`infra/db/bin/restore-check` checks specific `ci-recovery` fixture records. Do not use it as proof that an arbitrary business backup is complete.

For a real recovery, create a new database or instance, follow [TimescaleDB's documented logical restore procedure](https://www.tigerdata.com/docs/deploy/self-hosted/backup-and-restore/logical-backup), validate row counts and application behavior, and perform a deliberate cutover. The bootstrap SQL does not migrate existing databases.
