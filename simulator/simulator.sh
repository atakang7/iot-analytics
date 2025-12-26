#!/bin/sh
# simulator.sh - Runs in busybox, sends telemetry via wget

# Generate UUID for device ID
generate_uuid() {
  awk 'BEGIN {
    srand();
    printf "%08x-%04x-%04x-%04x-%012x\n",
      rand()*0xffffffff, rand()*0xffff, 0x4000|rand()*0x0fff, 0x8000|rand()*0x3fff, rand()*0xffffffffffff
  }'
}

# Always generate unique device ID
DEVICE_ID=$(generate_uuid)

rand() {
  awk -v min="$1" -v max="$2" 'BEGIN{srand(); printf "%.2f", min+rand()*(max-min)}'
}

send() {
  local sensor="$1" type="$2" unit="$3" min="$4" max="$5"
  local val=$(rand "$min" "$max")
  local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local json="{\"deviceId\":\"$DEVICE_ID\",\"deviceType\":\"$DEVICE_TYPE\",\"sensorId\":\"$sensor\",\"sensorType\":\"$type\",\"timestamp\":\"$ts\",\"unit\":\"$unit\",\"value\":{\"reading\":$val}}"
  
  if wget -q -O- --post-data="$json" --header="Content-Type: application/json" "$INGESTION_URL" >/dev/null 2>&1; then
    echo "[$(date +%H:%M:%S)] $sensor=$val $unit"
  else
    echo "[$(date +%H:%M:%S)] FAIL $sensor - check ingestion service"
  fi
}

echo "=== Device Simulator ==="
echo "Device:   $DEVICE_ID"
echo "Type:     $DEVICE_TYPE"
echo "Interval: ${INTERVAL}s"
echo "URL:      $INGESTION_URL"
echo "========================"

while true; do
  case "$DEVICE_TYPE" in
    motor)
      send "temp-1" "temperature" "celsius" 35 95
      send "vibration-1" "vibration" "mm/s" 0.5 4.0
      send "current-1" "current" "ampere" 8 45
      ;;
    pump)
      send "temp-1" "temperature" "celsius" 25 75
      send "pressure-in" "pressure" "bar" 0.5 2.0
      send "pressure-out" "pressure" "bar" 4.0 8.0
      send "flow-1" "flow" "l/min" 50 200
      ;;
    hvac)
      send "temp-supply" "temperature" "celsius" 12 28
      send "temp-return" "temperature" "celsius" 18 32
      send "humidity-1" "humidity" "percent" 30 70
      ;;
    compressor)
      send "temp-1" "temperature" "celsius" 40 110
      send "pressure-1" "pressure" "bar" 6.0 12.0
      send "vibration-1" "vibration" "mm/s" 0.8 5.0
      ;;
    *)
      send "temp-1" "temperature" "celsius" 20 80
      send "sensor-1" "generic" "unit" 0 100
      ;;
  esac
  sleep "$INTERVAL"
done
