#!/usr/bin/env bash
# Run after: docker compose -f services/docker-compose.yml up -d --build
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE=(docker compose -f "$ROOT/services/docker-compose.yml")
API="${INGESTION_URL:-http://127.0.0.1:8081}"
REGISTRY="${REGISTRY_URL:-http://127.0.0.1:8080}"

echo "Waiting for both Java APIs..."
for _ in $(seq 1 90); do
  if curl -fsS "$API/telemetry/health" >/dev/null 2>&1 &&
     curl -fsS "$REGISTRY/devices" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
curl -fsS "$API/telemetry/health" >/dev/null
curl -fsS "$REGISTRY/devices" >/dev/null

uuid="ci-e2e-$(date +%s)-$$"
registry_status=$(curl -sS -o /tmp/iot-device-response -w '%{http_code}' \
  -H 'Content-Type: application/json' -d '{"name":"Smoke Test","type":"motor"}' \
  "$REGISTRY/devices")
test "$registry_status" = 201 || { cat /tmp/iot-device-response; exit 1; }

# A reading inside the first closed KPI window makes the test independent
# of the wall clock's position within its current 5-minute bucket.
stamp=$("${COMPOSE[@]}" exec -T timescaledb psql -U iot -d iot -Atc \
  "SELECT to_char((last_processed_at + interval '1 minute') AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM job_watermarks WHERE job_name='kpi_5min'")
stamp=$(echo "$stamp" | tr -d '\r\n')
body=$(printf '{"deviceId":"%s","deviceType":"motor","sensorId":"temp-1","sensorType":"temperature","timestamp":"%s","unit":"celsius","value":{"value":99}}' "$uuid" "$stamp")

for _ in 1 2; do
  code=$(curl -sS -o /tmp/iot-ingest-response -w '%{http_code}' \
    -H 'Content-Type: application/json' -d "$body" "$API/telemetry")
  test "$code" = 202 || { cat /tmp/iot-ingest-response; echo "Expected 202, got $code"; exit 1; }
done

# The same logical event is sent twice; the DB must store one sample and one alert.
echo "Waiting for the Kafka -> DB -> alert path..."
for _ in $(seq 1 90); do
  samples=$("${COMPOSE[@]}" exec -T timescaledb psql -U iot -d iot -Atc \
    "SELECT COUNT(*) FROM telemetry WHERE device_id='$uuid'" | tr -d '\r\n')
  alerts=$("${COMPOSE[@]}" exec -T timescaledb psql -U iot -d iot -Atc \
    "SELECT COUNT(*) FROM alerts WHERE device_id='$uuid'" | tr -d '\r\n')
  if [ "$samples" = 1 ] && [ "$alerts" -ge 1 ]; then
    break
  fi
  sleep 2
done

test "$samples" = 1 || { echo "Expected one telemetry row, got $samples"; exit 1; }
test "$alerts" -ge 1 || { echo "Expected threshold alert, got $alerts"; exit 1; }

"${COMPOSE[@]}" build kpi-job
"${COMPOSE[@]}" --profile batch run --rm kpi-job
kpis=$("${COMPOSE[@]}" exec -T timescaledb psql -U iot -d iot -Atc \
  "SELECT COUNT(*) FROM kpis WHERE device_id='$uuid'" | tr -d '\r\n')
test "$kpis" -ge 1 || { echo "Expected KPI rows, got $kpis"; exit 1; }

echo "PASS: APIs, Kafka ack, telemetry dedupe, threshold alerts and KPI job."
