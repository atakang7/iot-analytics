#!/usr/bin/env bash
# API smoke only; full Kafka/SQL verification lives in smoke-local.sh.
set -euo pipefail
URL="${INGESTION_URL:-http://127.0.0.1:8081}"
payload='{"deviceId":"sample-1","deviceType":"motor","sensorId":"temp-1","sensorType":"temperature","timestamp":"2026-11-03T10:30:00Z","unit":"celsius","value":{"value":65.5}}'

curl -fsS "$URL/telemetry/health"
echo

code=$(curl -sS -o /tmp/iot-valid-response -w '%{http_code}' \
  -X POST "$URL/telemetry" -H 'Content-Type: application/json' -d "$payload")
test "$code" = 202 || { cat /tmp/iot-valid-response; echo "Expected HTTP 202, got $code"; exit 1; }

code=$(curl -sS -o /tmp/iot-invalid-response -w '%{http_code}' \
  -X POST "$URL/telemetry" -H 'Content-Type: application/json' \
  -d '{"deviceId":"","sensorType":"temperature","value":{}}')
test "$code" = 400 || { cat /tmp/iot-invalid-response; echo "Expected HTTP 400, got $code"; exit 1; }

echo "PASS: health, accepted telemetry, invalid payload rejection"
