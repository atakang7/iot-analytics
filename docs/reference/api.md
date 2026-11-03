# HTTP API

The local Compose stack binds its HTTP services to loopback. The endpoints have no built-in user authentication.

## Device registry

Base URL: `http://127.0.0.1:8080`

| Request | Response | Behavior |
| --- | --- | --- |
| `POST /devices` | `201` | Creates a device and returns `Location: /devices/{id}` |
| `GET /devices` | `200` | Lists registered devices |
| `GET /devices/{id}` | `200` or `404` | Finds a device by registry UUID |
| `PUT /devices/{id}` | `200` or `404` | Updates client-owned fields |
| `DELETE /devices/{id}` | `204` or `404` | Deletes a registry record |

Device request:

```json
{"name":"Motor A","type":"motor","status":"active","location":"Lab 1"}
```

`name` and `type` are required; `status` and `location` are optional. The registry generates `id` and `createdAt`. Field length bounds are 255 characters for `name` and `location`, 100 for `type` and 40 for `status`. The default status is `inactive`.

## Telemetry ingestion

Base URL: `http://127.0.0.1:8081`

| Request | Response | Behavior |
| --- | --- | --- |
| `POST /telemetry` | `202` | Kafka acknowledged the event |
| `POST /telemetry` | `400` | HTTP payload failed validation |
| `POST /telemetry` | `503` | Kafka publication failed |
| `GET /telemetry/health` | `200` | Ingestion process responds; not a broker-health check |

```bash
curl -i http://127.0.0.1:8081/telemetry \
  -H 'Content-Type: application/json' \
  -d '{"deviceId":"motor-1","deviceType":"motor","sensorId":"temp-1","sensorType":"temperature","timestamp":"2026-11-03T10:00:00Z","unit":"celsius","value":{"value":72.5}}'
```

Current ingestion validation checks required string fields, timestamp parsing and a nonempty measurement object. It does not enforce every numeric sensor shape. Workers can reject a payload after Kafka accepted it.

## Internal management endpoints

In Compose, ingestion exposes Actuator on `127.0.0.1:9090`; registry uses `127.0.0.1:9091`. Their `/actuator/health/readiness` and `/actuator/prometheus` paths serve health and metrics. OpenShift routes do not publish those management ports.
