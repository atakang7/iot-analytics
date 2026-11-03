#!/bin/sh
# BusyBox-only simulator for the OpenShift lab.
set -eu

DEVICE_ID="${DEVICE_ID:-sim-$(date +%s)-$$}"
DEVICE_TYPE="${DEVICE_TYPE:-motor}"
INTERVAL="${INTERVAL:-5}"
INGESTION_URL="${INGESTION_URL:-http://ingestion:8081/telemetry}"

# Seed each reading independently instead of reseeding awk from the same second.
random_between() {
  seed="$(od -An -N4 -tu4 /dev/urandom | tr -d '[:space:]')"
  awk -v seed="$seed" -v minimum="$1" -v maximum="$2" 'BEGIN {
    srand(seed)
    printf "%.3f", minimum + rand() * (maximum - minimum)
  }'
}

send() {
  sensor="$1"
  type="$2"
  unit="$3"
  minimum="$4"
  maximum="$5"
  reading="$(random_between "$minimum" "$maximum")"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [ "$type" = vibration ]; then
    value="{\"x\":$reading,\"y\":0.0,\"z\":0.0}"
  else
    value="{\"value\":$reading}"
  fi
  payload="{\"deviceId\":\"$DEVICE_ID\",\"deviceType\":\"$DEVICE_TYPE\",\"sensorId\":\"$sensor\",\"sensorType\":\"$type\",\"timestamp\":\"$timestamp\",\"unit\":\"$unit\",\"value\":$value}"

  if wget -q -O /dev/null --post-data="$payload" \
      --header="Content-Type: application/json" "$INGESTION_URL"; then
    echo "[$(date -u +%H:%M:%S)] accepted: $sensor=$reading $unit"
  else
    echo "[$(date -u +%H:%M:%S)] failed: $sensor" >&2
  fi
}

echo "Simulator: $DEVICE_ID ($DEVICE_TYPE) → $INGESTION_URL"

while :; do
  case "$DEVICE_TYPE" in
    motor)
      send temp-1 temperature celsius 35 95
      send vibration-1 vibration mm/s 0.5 4.0
      send current-1 current ampere 8 45
      ;;
    pump)
      send temp-1 temperature celsius 25 75
      send pressure-in pressure bar 0.5 2.0
      send pressure-out pressure bar 4.0 8.0
      send flow-1 flow l/min 50 200
      ;;
    hvac)
      send temp-supply temperature celsius 12 28
      send temp-return temperature celsius 18 32
      send humidity-1 humidity percent 30 70
      ;;
    compressor)
      send temp-1 temperature celsius 40 110
      send pressure-1 pressure bar 6.0 12.0
      send vibration-1 vibration mm/s 0.8 5.0
      ;;
    *)
      send temp-1 temperature celsius 20 80
      send sensor-1 generic unit 0 100
      ;;
  esac
  sleep "$INTERVAL"
done
