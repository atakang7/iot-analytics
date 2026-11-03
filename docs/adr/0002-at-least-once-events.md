# 0002: Use at-least-once delivery with replay-safe writes

Status: Accepted

## Context

Kafka offset commits and database writes are separate operations. The stream processor also produces alerts to another topic. A crash can occur after the side effect but before source progress is recorded.

## Decision

Commit source offsets only after the corresponding database write or alert publish is acknowledged. Store telemetry by source, sensor and timestamp; alerts by a stable derived ID; KPIs by source, sensor, name and window.

## Consequences

A replay can repeat processing and metric increments. Unique keys prevent duplicate stored rows for identical identities, but side effects outside the database are not exactly once. Malformed events currently need operator intervention because no durable quarantine exists.
