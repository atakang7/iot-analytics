#!/bin/bash
# deploy-simulator.sh - Deploy device simulator
# Usage: ./deploy-simulator.sh [device_id] [device_type] [interval_seconds]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NS="${NAMESPACE:-atakangul-dev}"

DEVICE_ID="${1:-motor-001}"
DEVICE_TYPE="${2:-motor}"
INTERVAL="${3:-5}"

echo "=== Deploying Simulator ==="
echo "Device:   $DEVICE_ID"
echo "Type:     $DEVICE_TYPE"
echo "Interval: ${INTERVAL}s"
echo ""

# Create script ConfigMap (once)
if ! oc get cm simulator-script -n "$NS" &>/dev/null; then
  echo "[1/2] Creating script ConfigMap..."
  oc create configmap simulator-script \
    --from-file=simulator.sh="$SCRIPT_DIR/simulator.sh" \
    -n "$NS"
else
  echo "[1/2] Script ConfigMap exists"
fi

# Create deployment
echo "[2/2] Creating deployment..."
cat <<EOF | oc apply -n "$NS" -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sim-${DEVICE_ID}
  labels:
    app: device-simulator
    device: "${DEVICE_ID}"
spec:
  replicas: 1
  selector:
    matchLabels:
      device: "${DEVICE_ID}"
  template:
    metadata:
      labels:
        app: device-simulator
        device: "${DEVICE_ID}"
        type: "${DEVICE_TYPE}"
    spec:
      containers:
        - name: sim
          image: busybox:1.36
          command: ["sh", "/scripts/simulator.sh"]
          env:
            - name: DEVICE_ID
              value: "${DEVICE_ID}"
            - name: DEVICE_TYPE
              value: "${DEVICE_TYPE}"
            - name: INTERVAL
              value: "${INTERVAL}"
            - name: INGESTION_URL
              value: "http://ingestion:8081/telemetry"
          volumeMounts:
            - name: scripts
              mountPath: /scripts
          resources:
            requests:
              cpu: 5m
              memory: 16Mi
            limits:
              cpu: 20m
              memory: 32Mi
      volumes:
        - name: scripts
          configMap:
            name: simulator-script
            defaultMode: 0755
EOF

oc rollout status deployment/sim-${DEVICE_ID} -n "$NS" --timeout=60s

echo ""
echo "=== Done ==="
echo "Logs: oc logs -l device=${DEVICE_ID} -f"
