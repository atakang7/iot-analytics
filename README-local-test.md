# IoT Analytics - Local Testing

## Prerequisites

- Docker & Docker Compose
- Java 17
- Maven 3.8+
- curl (for testing)
- jq (optional, for pretty JSON output)

## Quick Start

### 1. Start Kafka

```bash
# From project root
chmod +x scripts/*.sh
./scripts/start-kafka.sh
```

This will:
- Start Zookeeper
- Start Kafka broker
- Create topics: `sensor-readings`, `kpi-results`, `alerts`
- Start Kafka UI on http://localhost:8090

### 2. Build & Run Ingestion Service

```bash
# Build common module first
cd services/common
mvn clean install

# Run ingestion service
cd ../ingestion
mvn spring-boot:run
```

Service will start on http://localhost:8080

### 3. Test the API

```bash
./scripts/test-ingestion.sh
```

Or manual test:

```bash
curl -X POST http://localhost:8080/api/v1/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "scalar", "value": 65.5}
  }'
```

### 4. Verify Messages in Kafka

```bash
# Consume messages from sensor-readings topic
./scripts/consume-kafka.sh sensor-readings

# Or use Kafka UI
open http://localhost:8090
```

### 5. Stop Everything

```bash
./scripts/stop-kafka.sh
```

## Kafka Topics

| Topic | Partitions | Purpose |
|-------|------------|---------|
| sensor-readings | 6 | Raw telemetry from devices |
| kpi-results | 3 | Computed KPIs from Flink |
| alerts | 3 | Anomaly alerts from Flink |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/telemetry` | Single telemetry reading |
| POST | `/api/v1/telemetry/batch` | Batch readings (max 1000) |
| GET | `/api/v1/telemetry/health` | Health check |
| GET | `/actuator/health` | K8s health probes |
| GET | `/actuator/prometheus` | Prometheus metrics |

## Supported Sensor Types

| Sensor Type | Value Type | Example |
|-------------|------------|---------|
| temperature | scalar | `{"@type": "scalar", "value": 65.5}` |
| humidity | scalar | `{"@type": "scalar", "value": 45.0}` |
| pressure | scalar | `{"@type": "scalar", "value": 8.5}` |
| speed | scalar | `{"@type": "scalar", "value": 2.5}` |
| spindle_rpm | scalar | `{"@type": "scalar", "value": 18500}` |
| fan_rpm | scalar | `{"@type": "scalar", "value": 2400}` |
| vibration | vibration | `{"@type": "vibration", "x": 0.1, "y": 0.2, "z": 1.0}` |
| power | power | `{"@type": "power", "voltage": 380, "current": 45, "power": 17000, "powerFactor": 0.92}` |
| proximity | boolean | `{"@type": "boolean", "state": true}` |
| contact | boolean | `{"@type": "boolean", "state": false}` |

## Device Types

- `cnc_machine`
- `hvac`
- `conveyor`
- `compressor`
- `access_door`

## Troubleshooting

### Kafka not starting
```bash
docker-compose -f docker-compose.kafka.yml logs kafka
```

### Ingestion service can't connect to Kafka
Make sure Kafka is running and the `KAFKA_BOOTSTRAP_SERVERS` env var is correct:
```bash
KAFKA_BOOTSTRAP_SERVERS=localhost:9092 mvn spring-boot:run
```

### Check topic messages
```bash
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic sensor-readings \
  --from-beginning
```
