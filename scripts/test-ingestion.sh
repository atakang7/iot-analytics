#!/bin/bash

# Test script for IoT Ingestion Service
# Requires: curl, jq (optional for pretty output)

BASE_URL="${INGESTION_URL:-http://localhost:8081}"
API_URL="$BASE_URL/api/v1/telemetry"

echo "=== IoT Ingestion Service Test ==="
echo "Target: $API_URL"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to test endpoint
test_request() {
    local name="$1"
    local data="$2"
    local endpoint="${3:-$API_URL}"
    
    echo "--- Test: $name ---"
    response=$(curl -s -w "\n%{http_code}" -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -d "$data")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [[ "$http_code" =~ ^2 ]]; then
        echo -e "${GREEN}✓ Status: $http_code${NC}"
    else
        echo -e "${RED}✗ Status: $http_code${NC}"
    fi
    
    if command -v jq &> /dev/null; then
        echo "$body" | jq .
    else
        echo "$body"
    fi
    echo ""
}

# Test 1: Temperature reading (scalar)
test_request "Temperature Reading" '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "scalar", "value": 65.5}
}'

# Test 2: Vibration reading (3-axis)
test_request "Vibration Reading" '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "vib-01",
    "sensorType": "vibration",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "vibration", "x": 0.12, "y": -0.08, "z": 1.02}
}'

# Test 3: Power reading (complex)
test_request "Power Reading" '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "power-01",
    "sensorType": "power",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "power", "voltage": 380.2, "current": 45.8, "power": 17200, "powerFactor": 0.92}
}'

# Test 4: Door contact (boolean)
test_request "Door Contact Reading" '{
    "deviceId": "door-001",
    "deviceType": "access_door",
    "sensorId": "contact-01",
    "sensorType": "contact",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "boolean", "state": false}
}'

# Test 5: HVAC humidity
test_request "HVAC Humidity Reading" '{
    "deviceId": "hvac-001",
    "deviceType": "hvac",
    "sensorId": "humidity-01",
    "sensorType": "humidity",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "scalar", "value": 45.0}
}'

# Test 6: Conveyor speed
test_request "Conveyor Speed Reading" '{
    "deviceId": "conv-001",
    "deviceType": "conveyor",
    "sensorId": "speed-01",
    "sensorType": "speed",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "scalar", "value": 2.5}
}'

# Test 7: Proximity sensor
test_request "Proximity Reading" '{
    "deviceId": "conv-001",
    "deviceType": "conveyor",
    "sensorId": "prox-01",
    "sensorType": "proximity",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "boolean", "state": true}
}'

# Test 8: Batch request
test_request "Batch Request" '{
    "readings": [
        {"deviceId": "cnc-001", "deviceType": "cnc_machine", "sensorId": "temp-01", "sensorType": "temperature", "timestamp": "2024-01-15T10:30:01Z", "value": {"@type": "scalar", "value": 66.0}},
        {"deviceId": "cnc-001", "deviceType": "cnc_machine", "sensorId": "temp-01", "sensorType": "temperature", "timestamp": "2024-01-15T10:30:02Z", "value": {"@type": "scalar", "value": 66.5}},
        {"deviceId": "cnc-002", "deviceType": "cnc_machine", "sensorId": "temp-01", "sensorType": "temperature", "timestamp": "2024-01-15T10:30:01Z", "value": {"@type": "scalar", "value": 58.0}}
    ]
}' "$API_URL/batch"

# Test 9: Invalid device type (should fail)
echo "--- Test: Invalid Device Type (expect 400) ---"
test_request "Invalid Device Type" '{
    "deviceId": "unknown-001",
    "deviceType": "invalid_type",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "scalar", "value": 65.5}
}'

# Test 10: Mismatched value type (should fail)
echo "--- Test: Mismatched Value Type (expect 400) ---"
test_request "Mismatched Value Type" '{
    "deviceId": "cnc-001",
    "deviceType": "cnc_machine",
    "sensorId": "temp-01",
    "sensorType": "temperature",
    "timestamp": "2024-01-15T10:30:00Z",
    "value": {"@type": "vibration", "x": 0.1, "y": 0.2, "z": 0.3}
}'

# Health check
echo "--- Health Check ---"
curl -s "$API_URL/health"
echo ""
echo ""

# Metrics
echo "--- Prometheus Metrics (ingestion.*) ---"
curl -s "$BASE_URL/actuator/prometheus" | grep "^ingestion" || echo "No ingestion metrics yet"
echo ""

echo "=== Tests Complete ==="
