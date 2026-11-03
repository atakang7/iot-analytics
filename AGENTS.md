# Agent instructions

Read [CONTEXT.md](CONTEXT.md) before changing event semantics. Use [docs/README.md](docs/README.md) to find task-specific guidance.

## Code map

`services/ingestion` owns HTTP acceptance and Kafka publishing. `services/device-registry` owns device CRUD. `services/workers/common` holds Python event and transport code. Worker entry points are in `services/workers/*/main.py`. `services/schema.sql` defines new database bootstrap state; `iot-helm/charts/infra/configs/schema.sql` is its identical chart copy. `delivery` owns release identities. `infra` provisions disposable test environments, while `validation` proves behavior.

## Before changing code

1. Read the owning module and its tests. Trace the event through the next durable boundary.
2. State which contract changes: API, event payload, persisted row, offset or release identity.
3. Add a regression test before changing that boundary. Keep network and database side effects out of pure domain logic.
4. Run the nearest tests and the relevant integration check. Do not claim a production rollout from a passing Kind run.
5. Update the matching Diátaxis page and an ADR only when the decision is hard to reverse, surprising and a real trade-off.

## Checks

```bash
# Python worker tests
(cd services/workers && for worker in telemetry-worker stream-worker alert-worker kpi-job; do
  (cd "$worker" && PYTHONPATH=.. python -m pytest -q) || exit 1
done)
# Both Java modules
mvn -B -ntp -f services/ingestion/pom.xml verify
mvn -B -ntp -f services/device-registry/pom.xml verify
# Local end-to-end behavior, if Docker is available
make up && make smoke
# Documentation contract
python3 scripts/verify-docs.py
```

Never edit `state/prod.json` to create a release that was not committed in `state/stage.json` history. Do not run destructive Compose volume cleanup, force-push shared branches, or deploy to an external cluster without explicit operator approval.

Keep this file short. For runtime details read [operations](docs/how-to/operate-compose.md), [Kubernetes checks](docs/how-to/test-kubernetes.md) or [delivery](docs/how-to/publish-release.md).
