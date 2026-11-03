# Delivery and replay

A successful `POST /telemetry` reports that Kafka accepted the message. It cannot promise that either consumer processed it or that the KPI job has run.

The telemetry consumer writes a batch before committing offsets. If it crashes after SQL commit and before the Kafka commit, the broker can redeliver those records. TimescaleDB's identity index on `(device_id, sensor_id, time)` causes the duplicate write to be ignored.

The stream consumer publishes to the alerts topic before committing the source offset. An alert ID is derived from the source, sensor, timestamp, alert type and severity. The alert consumer upserts on that ID. A repeat delivery can still repeat work and metrics.

A KPI run locks its watermark row, computes one closed five-minute window and commits both the KPI rows and the advanced watermark in one SQL transaction. The next run resumes from that watermark.

Malformed events currently stop a consumer before its offset is committed. An operator must inspect the event and its offset; there is no automatic quarantine workflow. Rate-change and stuck-sensor detection hold recent values in process memory, so restarting the stream worker resets those histories.

[ADR 0002](../adr/0002-at-least-once-events.md) records the replay trade-off. [Operations](../how-to/operate-compose.md) covers checks after an interruption.
