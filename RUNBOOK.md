# Operator runbook

For a new checkout, follow [the local pipeline tutorial](docs/tutorials/local-pipeline.md).

To operate a running stack, use [Compose operations](docs/how-to/operate-compose.md). The [backup guide](docs/how-to/backup-and-restore.md) covers safe snapshots and recovery rehearsals.

The [Kubernetes guide](docs/how-to/test-kubernetes.md) runs the disposable cluster tests. OpenShift lab checks have [their own procedure](docs/how-to/openshift-lab.md).

The database bootstrap schema runs only on a fresh volume. Existing data needs a reviewed migration before upgrade. Never use `docker compose down -v` to solve a migration problem.
