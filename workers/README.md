# IoT Analytics Workers

## Architecture

```
[Kafka: iot.telemetry]
         │
         ├──→ [telemetry-worker] ──→ [TimescaleDB: telemetry]
         │
         └──→ [stream-worker] ──→ [Kafka: iot.alerts]
                                          │
                                          └──→ [alert-worker] ──→ [TimescaleDB: alerts]
                                                               ──→ [Prometheus]

[TimescaleDB: telemetry] ──→ [kpi-job] ──→ [TimescaleDB: kpis]
```

## Workers

| Worker | Type | Input | Output | Port |
|--------|------|-------|--------|------|
| telemetry-worker | Deployment | Kafka | TimescaleDB | 8100 |
| stream-worker | Deployment | Kafka | Kafka | 8101 |
| alert-worker | Deployment | Kafka | TimescaleDB + Prometheus | 8102 |
| kpi-job | CronJob | TimescaleDB | TimescaleDB | - |

## Stream Worker Alerts

| Alert Type | Trigger |
|------------|---------|
| threshold_breach | Value exceeds configured limit |
| rapid_change | Value changed > 10 units in one reading |
| stuck_sensor | Same value for 5 consecutive readings |

## KPIs Computed

| KPI | Sensors | Description |
|-----|---------|-------------|
| avg, min, max | All | Basic statistics |
| std_dev, range | All | Variability |
| rms | Vibration | Root mean square |
| crest_factor | Vibration | Peak / RMS ratio |
| rate_of_change | Temperature | First to last delta |
| energy | Power | Sum of readings |

## Run

```bash
# Full stack
docker-compose up --build

# Just workers (if infra already running)
docker-compose up telemetry-worker stream-worker alert-worker
```

## Test

```bash
# Create device
curl -X POST http://localhost:8080/devices \
  -H "Content-Type: application/json" \
  -d '{"name": "CNC-001", "type": "cnc_machine", "location": "Floor 1"}'

# Send normal telemetry
curl -X POST http://localhost:8081/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "unit": "celsius",
    "value": {"type": "scalar", "value": 65.5}
  }'

# Send high temp (should trigger alert)
curl -X POST http://localhost:8081/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "unit": "celsius",
    "value": {"type": "scalar", "value": 95.0}
  }'

# Check telemetry stored
docker exec workers-timescaledb-1 psql -U iot -d iot \
  -c "SELECT * FROM telemetry ORDER BY time DESC LIMIT 5;"

# Check alerts
docker exec workers-timescaledb-1 psql -U iot -d iot \
  -c "SELECT * FROM alerts ORDER BY created_at DESC LIMIT 5;"

# Run KPI job manually
docker-compose run --rm kpi-job

# Check KPIs
docker exec workers-timescaledb-1 psql -U iot -d iot \
  -c "SELECT * FROM kpis ORDER BY created_at DESC LIMIT 10;"
```

## Metrics

| Worker | Endpoint | Key Metrics |
|--------|----------|-------------|
| telemetry-worker | :8100/metrics | iot_telemetry_received_total, iot_telemetry_stored_total |
| stream-worker | :8101/metrics | iot_alerts_generated_total, iot_threshold_checks_total |
| alert-worker | :8102/metrics | iot_alerts_stored_total, iot_alerts_active |

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| KAFKA_BOOTSTRAP | localhost:9092 | Kafka broker |
| DB_HOST | localhost | TimescaleDB host |
| DB_PORT | 5432 | TimescaleDB port |
| DB_NAME | iot | Database name |
| DB_USER | iot | Database user |
| DB_PASSWORD | iot | Database password |
| METRICS_PORT | 8000 | Prometheus metrics port |
