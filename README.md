# IoT Analytics Platform

A microservices-based IoT analytics platform for device management, telemetry ingestion, and real-time analytics.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  IoT Devices    │────▶│   Ingestion     │────▶│   RabbitMQ      │
│  (Simulator)    │     │   Service       │     │                 │
└─────────────────┘     │   (Java)        │     └────────┬────────┘
                        └────────┬────────┘              │
                                 │                       ▼
┌─────────────────┐              │              ┌─────────────────┐
│ Device Registry │◀─────────────┤              │   Analytics     │
│   (Java)        │              │              │   Service       │
└────────┬────────┘              │              │   (Python)      │
         │                       │              └────────┬────────┘
         ▼                       ▼                       ▼
┌──────────────────────────────────────────────────────────────────┐
│                          PostgreSQL                               │
└──────────────────────────────────────────────────────────────────┘
```

## Services

### Device Registry (Java/Spring Boot)
- **Port**: 8080
- **Responsibilities**:
  - Register and manage IoT devices
  - Track device status and metadata
  - Provide device lookup APIs
- **Endpoints**:
  - `GET /api/v1/devices` - List all devices
  - `POST /api/v1/devices` - Register a new device
  - `GET /api/v1/devices/{id}` - Get device details
  - `PUT /api/v1/devices/{id}` - Update device
  - `DELETE /api/v1/devices/{id}` - Delete device
  - `GET /api/v1/devices/stats` - Get device statistics

### Ingestion Service (Java/Spring Boot)
- **Port**: 8081
- **Responsibilities**:
  - Receive telemetry data from IoT devices
  - Validate and store telemetry
  - Forward data to analytics via RabbitMQ
- **Endpoints**:
  - `POST /api/v1/telemetry` - Ingest single telemetry point
  - `POST /api/v1/telemetry/batch` - Ingest batch telemetry
  - `GET /api/v1/telemetry/device/{deviceId}` - Get device telemetry
  - `GET /api/v1/telemetry/device/{deviceId}/stats` - Get telemetry stats

### Analytics Service (Python/FastAPI)
- **Port**: 8082
- **Responsibilities**:
  - Process telemetry data from RabbitMQ
  - Perform statistical analysis
  - Detect anomalies
  - Provide analytics APIs
- **Endpoints**:
  - `GET /api/v1/analytics/device/{deviceId}` - Get device analytics
  - `GET /api/v1/analytics/aggregations` - Get aggregated stats
  - `GET /api/v1/analytics/trend/{deviceId}` - Get trend analysis
  - `GET /api/v1/anomalies` - List anomaly alerts
  - `PATCH /api/v1/anomalies/{id}/acknowledge` - Acknowledge anomaly

## Infrastructure

- **PostgreSQL**: Primary database for device data and telemetry
- **RabbitMQ**: Message broker for async communication
- **Prometheus**: Metrics collection
- **Grafana**: Visualization and dashboards

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Java 17+ (for local development)
- Python 3.11+ (for local development)
- Maven 3.8+ (for local development)

### Deploy to Kubernetes

```bash
# Build all services
./scripts/build-and-deploy.sh

# Or deploy manually
kubectl apply -f k8s/infrastructure/
kubectl apply -f k8s/services/
```

### Local Development

#### Device Registry
```bash
cd services/device-registry
./mvnw spring-boot:run
```

#### Ingestion Service
```bash
cd services/ingestion
./mvnw spring-boot:run
```

#### Analytics Service
```bash
cd services/analytics
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8082
```

## API Documentation

Each service provides Swagger UI documentation:
- Device Registry: http://localhost:8080/swagger-ui.html
- Ingestion: http://localhost:8081/swagger-ui.html
- Analytics: http://localhost:8082/docs

## Monitoring

### Prometheus Endpoints
- Device Registry: http://localhost:8080/actuator/prometheus
- Ingestion: http://localhost:8081/actuator/prometheus
- Analytics: http://localhost:8082/metrics

### Health Checks
- Device Registry: http://localhost:8080/actuator/health
- Ingestion: http://localhost:8081/actuator/health
- Analytics: http://localhost:8082/health

## Configuration

### Environment Variables

| Service | Variable | Default | Description |
|---------|----------|---------|-------------|
| All | POSTGRES_HOST | localhost | PostgreSQL host |
| All | POSTGRES_PORT | 5432 | PostgreSQL port |
| All | POSTGRES_DB | devices | Database name |
| All | POSTGRES_USER | iot | Database user |
| All | POSTGRES_PASSWORD | iot123 | Database password |
| Ingestion/Analytics | RABBITMQ_HOST | localhost | RabbitMQ host |
| Ingestion/Analytics | RABBITMQ_PORT | 5672 | RabbitMQ port |
| Ingestion/Analytics | RABBITMQ_USER | iot | RabbitMQ user |
| Ingestion/Analytics | RABBITMQ_PASSWORD | iot123 | RabbitMQ password |

## License

MIT
