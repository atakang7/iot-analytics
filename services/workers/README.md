# Analytics workers

`common/models.py` defines the Python telemetry and alert objects. `common/kafka.py` configures the producer and consumers; `common/db.py` owns SQL connections and transactions.

`telemetry-worker` writes deduplicated samples. `stream-worker` checks configured thresholds and publishes alerts. `alert-worker` upserts alerts. `kpi-job` processes one closed five-minute window and commits its watermark with the KPI rows.

Source offsets commit after the relevant write or publish acknowledgment. Invalid messages currently block their partition. Stream rate and stuck-sensor history resets on restart.

Run each worker test suite:

~~~bash
(cd services/workers && for worker in telemetry-worker stream-worker alert-worker kpi-job; do
  (cd "$worker" && PYTHONPATH=.. python -m pytest -q) || exit 1
done)
~~~

See [replay semantics](../../docs/explanation/consistency.md), [data model](../../docs/reference/data-model.md) and [configuration](../../docs/reference/configuration.md).
