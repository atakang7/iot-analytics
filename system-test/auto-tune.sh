#!/bin/bash
# auto-tune.sh - Automatically scale to meet target throughput
# Usage: ./auto-tune.sh [target_msg_per_sec]

set -e

NS="${NAMESPACE:-atakangul-dev}"
TARGET="${1:-500}"
MAX_ITERATIONS=5

log() { echo "[$(date +%H:%M:%S)] $1"; }

get_kafka_lag() {
  oc exec deploy/kafka -n "$NS" -- bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 --group telemetry-worker --describe 2>/dev/null \
    | awk '/telemetry/{sum+=$5} END{print sum+0}'
}

get_throughput() {
  local before=$(oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" | tr -d ' ')
  sleep 10
  local after=$(oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" | tr -d ' ')
  echo $(( (after - before) / 10 ))
}

send_load() {
  local rate=$1
  log "Sending $rate msg/sec..."
  
  oc run load-$$ --rm -i --restart=Never -n "$NS" --image=python:3.11-slim -- python3 -c "
import urllib.request, json, time, threading
from datetime import datetime

sent = 0
def worker():
    global sent
    for _ in range(int($rate * 10 / 5)):  # 10 sec, 5 threads
        try:
            req = urllib.request.Request('http://ingestion:8081/telemetry',
                data=json.dumps({'deviceId':'tune','deviceType':'t','sensorId':'s','sensorType':'t',
                    'timestamp':datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),'unit':'c','value':{'reading':1}}).encode(),
                headers={'Content-Type':'application/json'})
            urllib.request.urlopen(req, timeout=5)
            sent += 1
        except: pass
        time.sleep(5/$rate)

threads = [threading.Thread(target=worker) for _ in range(5)]
for t in threads: t.start()
for t in threads: t.join()
print(f'Sent {sent}')
" 2>/dev/null &
}

scale_component() {
  local deploy=$1
  local current=$(oc get deploy "$deploy" -n "$NS" -o jsonpath='{.spec.replicas}')
  local new=$((current + 1))
  log "Scaling $deploy: $current → $new"
  oc scale deploy/"$deploy" --replicas="$new" -n "$NS"
  sleep 20  # Wait for pod
}

echo "═══════════════════════════════════════════"
echo " AUTO-TUNE - Target: $TARGET msg/sec"
echo "═══════════════════════════════════════════"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  log "=== Iteration $i/$MAX_ITERATIONS ==="
  
  # Send load
  send_load "$TARGET"
  sleep 5
  
  # Measure throughput
  THROUGHPUT=$(get_throughput)
  LAG=$(get_kafka_lag)
  
  log "Throughput: $THROUGHPUT msg/sec | Kafka lag: $LAG"
  
  # Check if we're good
  if [[ "$THROUGHPUT" -ge "$TARGET" ]] && [[ "$LAG" -lt 100 ]]; then
    echo ""
    echo "✓ Target achieved! ($THROUGHPUT >= $TARGET msg/sec)"
    break
  fi
  
  # Identify bottleneck and scale
  if [[ "$LAG" -gt 500 ]]; then
    log "Bottleneck: telemetry-worker (lag=$LAG)"
    scale_component telemetry-worker
  elif [[ "$THROUGHPUT" -lt $((TARGET / 2)) ]]; then
    log "Bottleneck: ingestion (low throughput)"
    scale_component ingestion
  else
    log "Bottleneck: telemetry-worker (throughput limited)"
    scale_component telemetry-worker
  fi
  
  sleep 10
done

echo ""
echo "═══════════════════════════════════════════"
echo " FINAL STATE"
echo "═══════════════════════════════════════════"
echo "Ingestion replicas:        $(oc get deploy ingestion -n "$NS" -o jsonpath='{.spec.replicas}')"
echo "Telemetry-worker replicas: $(oc get deploy telemetry-worker -n "$NS" -o jsonpath='{.spec.replicas}')"
echo "Throughput:                ~$THROUGHPUT msg/sec"
echo "Kafka lag:                 $LAG"
