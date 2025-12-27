# Performance Tools

Scripts to test, monitor, and optimize the IoT pipeline:

```
ingestion → kafka → telemetry-worker → timescaledb
```

## Quick Start

```bash
# Check current status
./status.sh

# Run benchmark (1000 messages)
./benchmark.sh 1000 10

# Live monitoring
./monitor.sh

# Full performance test
./performance-test.sh 60 1000

# Auto-tune to target rate
./auto-tune.sh 500
```

## Scripts

| Script | Purpose |
|--------|---------|
| `status.sh` | One-shot status check |
| `benchmark.sh` | Send N messages, measure throughput |
| `monitor.sh` | Live dashboard |
| `performance-test.sh` | Full analysis with recommendations |
| `auto-tune.sh` | Automatically scale to meet target |

## Bottleneck Guide

| Symptom | Bottleneck | Fix |
|---------|------------|-----|
| High Kafka lag | telemetry-worker | Scale worker |
| HTTP errors | ingestion | Scale ingestion |
| Slow inserts | timescaledb | Batch size, indexes |
| Low throughput | Multiple | Scale both + batch |

## Scaling Commands

```bash
# Scale telemetry worker (most common)
oc scale deploy/telemetry-worker --replicas=3

# Scale ingestion
oc scale deploy/ingestion --replicas=2

# Check lag
oc exec deploy/kafka -- bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group telemetry-worker --describe

# Watch DB count
watch -n1 'oc exec deploy/timescaledb -- psql -U iot -d iot -c "SELECT COUNT(*) FROM telemetry;"'
```

## Expected Performance

| Config | Throughput |
|--------|------------|
| 1 ingestion, 1 worker | ~100 msg/sec |
| 1 ingestion, 2 workers | ~200 msg/sec |
| 2 ingestion, 3 workers | ~500 msg/sec |
| 2 ingestion, 5 workers + batching | ~1000+ msg/sec |

## Tuning Tips

1. **Worker batching** - Ensure telemetry-worker batches inserts (100 per commit)
2. **DB indexes** - TimescaleDB hypertable with time index
3. **Kafka partitions** - More partitions = more parallel consumers
4. **Connection pooling** - Reuse DB connections
