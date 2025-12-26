#!/bin/bash
# test-ingestion.sh - Quick test if ingestion works
set -e

NS="${NAMESPACE:-atakangul-dev}"

echo "Testing ingestion endpoint..."

# Test from inside cluster
oc run test-curl --rm -i --restart=Never --image=busybox -- sh -c '
  JSON="{\"deviceId\":\"test-001\",\"deviceType\":\"test\",\"sensorId\":\"temp\",\"sensorType\":\"temperature\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"unit\":\"celsius\",\"value\":{\"reading\":42.5}}"
  echo "Sending: $JSON"
  wget -q -O- --post-data="$JSON" --header="Content-Type: application/json" http://ingestion:8081/telemetry
  echo ""
  echo "Exit code: $?"
' 2>/dev/null

echo ""
echo "Check DB:"
oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -c "SELECT device_id, sensor_type, value, time FROM telemetry ORDER BY time DESC LIMIT 5;"
