# IoT Analytics Services

Minimal services for IoT telemetry ingestion and device management.

## Services

| Service | Port | Description |
|---------|------|-------------|
| device-registry | 8080 | CRUD for devices |
| ingestion | 8081 | Telemetry → Kafka |
| timescaledb | 5432 | Time-series database |
| kafka | 9092 | Message broker |

## Build

```bash
cd device-registry && mvn clean package -DskipTests && cd ..
cd ingestion && mvn clean package -DskipTests && cd ..
```

## Run

```bash
docker-compose up --build
```

## Test

### Create a device
```bash
curl -X POST http://localhost:8080/devices \
  -H "Content-Type: application/json" \
  -d '{"name": "CNC-001", "type": "cnc_machine", "location": "Floor 1"}'
```

### List devices
```bash
curl http://localhost:8080/devices
```

### Send telemetry
```bash
curl -X POST http://localhost:8081/telemetry \
  -H "Content-Type: application/json" \
  -d '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "2024-01-15T10:30:00Z",
    "unit": "celsius",
    "value": {"type": "scalar", "value": 65.5}
  }'
```

### Check Kafka topic
```bash
docker-compose exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic iot.telemetry \
  --from-beginning
```

### Query TimescaleDB
```bash
docker-compose exec timescaledb psql -U iot -d iot -c "SELECT * FROM devices;"
```

## API

### Device Registry

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /devices | List all devices |
| GET | /devices/{id} | Get device by ID |
| POST | /devices | Create device |
| PUT | /devices/{id} | Update device |
| DELETE | /devices/{id} | Delete device |

### Ingestion

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /telemetry | Ingest telemetry |
| GET | /telemetry/health | Health check |
