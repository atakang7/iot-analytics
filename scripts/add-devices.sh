#!/bin/bash
# Add a device simulator
# Usage: ./add-devices.sh [device_id] [device_type] [interval_ms]
#
# Defaults:
#   device_id:   motor-001
#   device_type: motor
#   interval_ms: 5000
#
# Examples:
#   ./add-devices.sh                        # motor-001, motor, 5000ms
#   ./add-devices.sh pump-001 pump          # pump-001, pump, 5000ms
#   ./add-devices.sh hvac-001 hvac 10000    # hvac-001, hvac, 10000ms
#
# Device types: motor, pump, hvac, compressor (each has preset sensors)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="${NAMESPACE:-atakangul-dev}"

# Defaults
DEVICE_ID="${1:-motor-001}"
DEVICE_TYPE="${2:-motor}"
INTERVAL_MS="${3:-5000}"

echo "========================================"
echo "Adding Device Simulator"
echo "========================================"
echo "  Device ID:   $DEVICE_ID"
echo "  Device Type: $DEVICE_TYPE"
echo "  Interval:    ${INTERVAL_MS}ms"
echo "  Namespace:   $NAMESPACE"
echo "========================================"

# Sensor presets by device type (single line JSON)
get_sensors() {
  case "$1" in
    motor)
      echo '[{"id":"temp-1","type":"temperature","unit":"celsius","min":35,"max":95,"pattern":"load_dependent","noise":0.15},{"id":"vib-1","type":"vibration","unit":"mm/s","min":0.5,"max":4.0,"pattern":"spike","spike_probability":0.03,"spike_magnitude":2.5,"noise":0.2},{"id":"current-1","type":"current","unit":"ampere","min":8,"max":45,"pattern":"load_dependent","noise":0.1},{"id":"rpm-1","type":"rpm","unit":"rpm","min":1450,"max":1500,"pattern":"normal","noise":0.03}]'
      ;;
    hvac)
      echo '[{"id":"temp-supply","type":"temperature","unit":"celsius","min":12,"max":28,"pattern":"cyclic","period_seconds":1800,"noise":0.1},{"id":"temp-return","type":"temperature","unit":"celsius","min":18,"max":32,"pattern":"cyclic","period_seconds":1800,"noise":0.1},{"id":"humidity-1","type":"humidity","unit":"percent","min":30,"max":70,"pattern":"normal","noise":0.15},{"id":"pressure-1","type":"pressure","unit":"bar","min":1.5,"max":4.0,"pattern":"normal","noise":0.08}]'
      ;;
    pump)
      echo '[{"id":"temp-1","type":"temperature","unit":"celsius","min":25,"max":75,"pattern":"load_dependent","noise":0.12},{"id":"pressure-in","type":"pressure","unit":"bar","min":0.5,"max":2.0,"pattern":"normal","noise":0.1},{"id":"pressure-out","type":"pressure","unit":"bar","min":4.0,"max":8.0,"pattern":"load_dependent","noise":0.1},{"id":"flow-1","type":"flow","unit":"l/min","min":50,"max":200,"pattern":"load_dependent","noise":0.15},{"id":"vib-1","type":"vibration","unit":"mm/s","min":0.3,"max":3.5,"pattern":"spike","spike_probability":0.02,"spike_magnitude":2.0,"noise":0.18}]'
      ;;
    compressor)
      echo '[{"id":"temp-1","type":"temperature","unit":"celsius","min":40,"max":110,"pattern":"load_dependent","noise":0.15},{"id":"pressure-1","type":"pressure","unit":"bar","min":6.0,"max":12.0,"pattern":"load_dependent","noise":0.1},{"id":"vib-1","type":"vibration","unit":"mm/s","min":0.8,"max":5.0,"pattern":"spike","spike_probability":0.04,"spike_magnitude":3.0,"noise":0.2},{"id":"current-1","type":"current","unit":"ampere","min":15,"max":80,"pattern":"load_dependent","noise":0.12}]'
      ;;
    *)
      echo "Warning: Unknown device type '$1', using generic sensors" >&2
      echo '[{"id":"temp-1","type":"temperature","unit":"celsius","min":20,"max":80,"pattern":"normal","noise":0.15},{"id":"vib-1","type":"vibration","unit":"mm/s","min":0.5,"max":3.0,"pattern":"normal","noise":0.2}]'
      ;;
  esac
}

SENSORS=$(get_sensors "$DEVICE_TYPE")

# Step 1: Ensure simulator script ConfigMap exists
echo ""
echo "[1/4] Ensuring simulator script ConfigMap..."
if ! oc get configmap simulator-script -n "$NAMESPACE" &>/dev/null; then
  echo "Creating simulator-script ConfigMap..."
  oc create configmap simulator-script \
    --from-file=simulator.py="${SCRIPT_DIR}/simulator-script.py" \
    -n "$NAMESPACE"
  echo "Created simulator-script ConfigMap"
else
  echo "simulator-script ConfigMap already exists"
fi

# Step 2: Register device with device-registry (ID is auto-generated UUID)
echo ""
echo "[2/4] Registering device with device-registry..."
REGISTER_RESULT=$(oc exec deploy/device-registry -n "$NAMESPACE" -- \
  curl -s -X POST "http://localhost:8080/devices" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${DEVICE_ID}\",\"type\":\"${DEVICE_TYPE}\",\"status\":\"active\",\"location\":\"simulated\"}" 2>/dev/null || echo '{"error":"exec failed"}')

if echo "$REGISTER_RESULT" | grep -q '"id"'; then
  REGISTERED_UUID=$(echo "$REGISTER_RESULT" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
  echo "Device registered: $REGISTERED_UUID"
elif echo "$REGISTER_RESULT" | grep -qi 'exists\|duplicate\|conflict'; then
  echo "Device already registered (OK)"
else
  echo "Warning: Could not register device (continuing anyway): $REGISTER_RESULT"
fi

# Step 3: Create device config ConfigMap using oc create
echo ""
echo "[3/4] Creating device config ConfigMap..."

# Delete if exists
oc delete configmap "simulator-${DEVICE_ID}-config" -n "$NAMESPACE" 2>/dev/null || true

# Create ConfigMap with literal values
oc create configmap "simulator-${DEVICE_ID}-config" \
  --from-literal=DEVICE_ID="${DEVICE_ID}" \
  --from-literal=DEVICE_TYPE="${DEVICE_TYPE}" \
  --from-literal=INTERVAL_MS="${INTERVAL_MS}" \
  --from-literal=INGESTION_URL="http://ingestion:8081/telemetry" \
  --from-literal=SENSORS="${SENSORS}" \
  -n "$NAMESPACE"

# Add labels
oc label configmap "simulator-${DEVICE_ID}-config" \
  app=device-simulator \
  device="${DEVICE_ID}" \
  device-type="${DEVICE_TYPE}" \
  -n "$NAMESPACE"

echo "ConfigMap simulator-${DEVICE_ID}-config created"

# Step 4: Create Deployment
echo ""
echo "[4/4] Creating deployment..."
cat <<EOF | oc apply -n "$NAMESPACE" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simulator-${DEVICE_ID}
  labels:
    app: device-simulator
    device: "${DEVICE_ID}"
    device-type: "${DEVICE_TYPE}"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: device-simulator
      device: "${DEVICE_ID}"
  template:
    metadata:
      labels:
        app: device-simulator
        device: "${DEVICE_ID}"
        device-type: "${DEVICE_TYPE}"
    spec:
      containers:
        - name: simulator
          image: python:3.11-slim
          command: ["sh", "-c", "pip install --user -q requests && python /scripts/simulator.py"]
          env:
            - name: HOME
              value: /tmp
            - name: PYTHONUSERBASE
              value: /tmp/.local
          envFrom:
            - configMapRef:
                name: simulator-${DEVICE_ID}-config
          volumeMounts:
            - name: script
              mountPath: /scripts
          resources:
            requests:
              cpu: 10m
              memory: 48Mi
            limits:
              cpu: 50m
              memory: 96Mi
      volumes:
        - name: script
          configMap:
            name: simulator-script
EOF

echo "Waiting for deployment..."
oc rollout status deployment/simulator-${DEVICE_ID} -n "$NAMESPACE" --timeout=120s

echo ""
echo "========================================"
echo "Device simulator deployed!"
echo "========================================"
echo ""
echo "Commands:"
echo "  Logs:    oc logs -l device=${DEVICE_ID} -f"
echo "  Delete:  oc delete deploy/simulator-${DEVICE_ID} cm/simulator-${DEVICE_ID}-config"
echo ""
echo "All simulators:"
oc get pods -l app=device-simulator -n "$NAMESPACE"