#!/bin/bash
# performance-test.sh - Find bottlenecks and optimal scaling
# Usage: ./performance-test.sh [duration_seconds] [target_msg_per_sec]

set -e

NS="${NAMESPACE:-atakangul-dev}"
DURATION="${1:-60}"
TARGET_RATE="${2:-1000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} $1"; }
ok() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }

header() {
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Get current counts
get_db_count() {
  oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" 2>/dev/null | tr -d ' '
}

get_kafka_lag() {
  oc exec deploy/kafka -n "$NS" -- bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --group telemetry-worker \
    --describe 2>/dev/null | grep -v "^$\|GROUP\|Consumer" | awk '{sum+=$5} END {print sum+0}'
}

get_pod_cpu() {
  local deploy=$1
  oc adm top pod -l app="$deploy" -n "$NS" --no-headers 2>/dev/null | awk '{print $2}' | sed 's/m//' | head -1
}

get_pod_mem() {
  local deploy=$1
  oc adm top pod -l app="$deploy" -n "$NS" --no-headers 2>/dev/null | awk '{print $3}' | head -1
}

get_replicas() {
  local deploy=$1
  oc get deploy "$deploy" -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null
}

# Test ingestion endpoint directly
test_ingestion_throughput() {
  local count=$1
  local parallel=$2
  
  log "Testing ingestion endpoint (${count} requests, ${parallel} parallel)..."
  
  local start=$(date +%s.%N)
  
  # Generate test payloads and send
  seq 1 "$count" | xargs -P "$parallel" -I {} \
    oc exec deploy/ingestion -n "$NS" -- sh -c "
      curl -s -X POST http://localhost:8081/telemetry \
        -H 'Content-Type: application/json' \
        -d '{\"deviceId\":\"perf-test\",\"deviceType\":\"test\",\"sensorId\":\"s{}\",\"sensorType\":\"temp\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"unit\":\"c\",\"value\":{\"reading\":42}}' \
        -o /dev/null -w '%{http_code}\n'
    " 2>/dev/null | grep -c "200" || echo "0"
  
  local end=$(date +%s.%N)
  local duration=$(echo "$end - $start" | bc)
  local rate=$(echo "scale=2; $count / $duration" | bc)
  
  echo "$rate"
}

# Run load test from inside cluster
run_load_test() {
  local rate=$1
  local duration=$2
  
  log "Starting load test: ${rate} msg/sec for ${duration}s..."
  
  # Delete old test pod
  oc delete pod perf-load-test -n "$NS" 2>/dev/null || true
  
  # Run load generator
  oc run perf-load-test --rm -i --restart=Never -n "$NS" \
    --image=python:3.11-slim \
    -- python3 -c "
import urllib.request
import json
import time
import threading
import sys
from datetime import datetime

URL = 'http://ingestion:8081/telemetry'
RATE = $rate
DURATION = $duration

sent = 0
errors = 0
lock = threading.Lock()

def send():
    global sent, errors
    payload = json.dumps({
        'deviceId': 'perf-test',
        'deviceType': 'test',
        'sensorId': f's-{threading.current_thread().name}',
        'sensorType': 'temperature',
        'timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'unit': 'celsius',
        'value': {'reading': 42.5}
    }).encode()
    
    try:
        req = urllib.request.Request(URL, data=payload, headers={'Content-Type': 'application/json'})
        urllib.request.urlopen(req, timeout=5)
        with lock:
            sent += 1
    except Exception as e:
        with lock:
            errors += 1

def worker():
    interval = 1.0 / (RATE / 10)  # 10 workers
    end_time = time.time() + DURATION
    while time.time() < end_time:
        send()
        time.sleep(interval)

threads = [threading.Thread(target=worker, name=f'w{i}') for i in range(10)]
start = time.time()

for t in threads:
    t.start()
for t in threads:
    t.join()

elapsed = time.time() - start
actual_rate = sent / elapsed

print(f'RESULT:sent={sent},errors={errors},rate={actual_rate:.2f},duration={elapsed:.2f}')
" 2>&1 | grep "RESULT:" | sed 's/RESULT://'
}

header "PERFORMANCE TEST - IoT Pipeline"
echo "Duration: ${DURATION}s | Target: ${TARGET_RATE} msg/sec"
echo "Namespace: $NS"

header "1. BASELINE METRICS"

# Current state
log "Collecting baseline..."

INGESTION_REPLICAS=$(get_replicas ingestion)
WORKER_REPLICAS=$(get_replicas telemetry-worker)
KAFKA_REPLICAS=$(get_replicas kafka)

echo "Current replicas:"
echo "  Ingestion:        $INGESTION_REPLICAS"
echo "  Telemetry-worker: $WORKER_REPLICAS"
echo "  Kafka:            $KAFKA_REPLICAS"

DB_COUNT_BEFORE=$(get_db_count)
KAFKA_LAG_BEFORE=$(get_kafka_lag)

echo ""
echo "Current state:"
echo "  DB records:  $DB_COUNT_BEFORE"
echo "  Kafka lag:   $KAFKA_LAG_BEFORE"

header "2. COMPONENT TESTS"

# Test each component individually
log "Testing ingestion HTTP throughput..."
INGESTION_DIRECT=$(oc run ingestion-test --rm -i --restart=Never -n "$NS" \
  --image=busybox \
  -- sh -c '
    START=$(date +%s)
    COUNT=0
    for i in $(seq 1 100); do
      wget -q -O- --post-data="{\"deviceId\":\"t\",\"deviceType\":\"t\",\"sensorId\":\"s\",\"sensorType\":\"t\",\"timestamp\":\"2025-01-01T00:00:00Z\",\"unit\":\"c\",\"value\":{\"reading\":1}}" \
        --header="Content-Type: application/json" \
        http://ingestion:8081/telemetry >/dev/null 2>&1 && COUNT=$((COUNT+1))
    done
    END=$(date +%s)
    ELAPSED=$((END-START))
    [ $ELAPSED -eq 0 ] && ELAPSED=1
    echo "RATE:$((COUNT/ELAPSED))"
  ' 2>&1 | grep "RATE:" | cut -d: -f2)

echo "  Ingestion HTTP:   ~${INGESTION_DIRECT:-?} req/sec (single thread)"

log "Testing DB insert throughput..."
DB_DIRECT=$(oc exec deploy/timescaledb -n "$NS" -- sh -c "
  psql -U iot -d iot -t -c \"
    DO \\\$\\\$
    DECLARE
      start_ts TIMESTAMP;
      end_ts TIMESTAMP;
      i INT;
    BEGIN
      start_ts := clock_timestamp();
      FOR i IN 1..1000 LOOP
        INSERT INTO telemetry (time, device_id, device_type, sensor_id, sensor_type, value, unit)
        VALUES (NOW(), 'perf', 'test', 'sensor', 'temp', 42, 'c');
      END LOOP;
      end_ts := clock_timestamp();
      RAISE NOTICE 'RATE:%', 1000 / EXTRACT(EPOCH FROM (end_ts - start_ts));
    END \\\$\\\$;
  \" 2>&1 | grep RATE | cut -d: -f2 | cut -d. -f1
")
echo "  TimescaleDB:      ~${DB_DIRECT:-?} inserts/sec (single connection)"

header "3. END-TO-END LOAD TEST"

# Run actual load test
LOAD_RESULT=$(run_load_test "$TARGET_RATE" "$DURATION")

SENT=$(echo "$LOAD_RESULT" | tr ',' '\n' | grep "sent=" | cut -d= -f2)
ERRORS=$(echo "$LOAD_RESULT" | tr ',' '\n' | grep "errors=" | cut -d= -f2)
ACTUAL_RATE=$(echo "$LOAD_RESULT" | tr ',' '\n' | grep "rate=" | cut -d= -f2)

echo ""
echo "Load test results:"
echo "  Sent:        $SENT messages"
echo "  Errors:      $ERRORS"
echo "  Actual rate: $ACTUAL_RATE msg/sec"

# Wait for pipeline to drain
log "Waiting 10s for pipeline to process..."
sleep 10

header "4. PIPELINE ANALYSIS"

DB_COUNT_AFTER=$(get_db_count)
KAFKA_LAG_AFTER=$(get_kafka_lag)

PROCESSED=$((DB_COUNT_AFTER - DB_COUNT_BEFORE))
PROCESSING_RATE=$(echo "scale=2; $PROCESSED / ($DURATION + 10)" | bc)

echo "Pipeline metrics:"
echo "  Messages sent:      $SENT"
echo "  Messages stored:    $PROCESSED"
echo "  Final Kafka lag:    $KAFKA_LAG_AFTER"
echo "  Effective rate:     $PROCESSING_RATE msg/sec"

# Identify bottleneck
header "5. BOTTLENECK ANALYSIS"

INGESTION_CPU=$(get_pod_cpu ingestion)
WORKER_CPU=$(get_pod_cpu telemetry-worker)
KAFKA_CPU=$(get_pod_cpu kafka)
DB_CPU=$(get_pod_cpu timescaledb)

echo "CPU usage (millicores):"
echo "  Ingestion:        ${INGESTION_CPU:-?}m"
echo "  Telemetry-worker: ${WORKER_CPU:-?}m"
echo "  Kafka:            ${KAFKA_CPU:-?}m"
echo "  TimescaleDB:      ${DB_CPU:-?}m"

echo ""

# Determine bottleneck
BOTTLENECK=""
RECOMMENDATION=""

if [[ -n "$KAFKA_LAG_AFTER" ]] && [[ "$KAFKA_LAG_AFTER" -gt 1000 ]]; then
  BOTTLENECK="telemetry-worker"
  RECOMMENDATION="Scale telemetry-worker: oc scale deploy/telemetry-worker --replicas=$((WORKER_REPLICAS + 1))"
  err "BOTTLENECK: Kafka consumer lag is high ($KAFKA_LAG_AFTER)"
  echo "  → Telemetry worker can't keep up with Kafka"
fi

if [[ -n "$ERRORS" ]] && [[ "$ERRORS" -gt $((SENT / 10)) ]]; then
  BOTTLENECK="ingestion"
  RECOMMENDATION="Scale ingestion: oc scale deploy/ingestion --replicas=$((INGESTION_REPLICAS + 1))"
  err "BOTTLENECK: High error rate at ingestion ($ERRORS errors)"
  echo "  → Ingestion service is overloaded"
fi

if [[ -n "$INGESTION_CPU" ]] && [[ "$INGESTION_CPU" -gt 800 ]]; then
  BOTTLENECK="ingestion"
  RECOMMENDATION="Scale ingestion: oc scale deploy/ingestion --replicas=$((INGESTION_REPLICAS + 1))"
  warn "Ingestion CPU is high (${INGESTION_CPU}m)"
fi

if [[ -n "$WORKER_CPU" ]] && [[ "$WORKER_CPU" -gt 800 ]]; then
  BOTTLENECK="telemetry-worker"
  RECOMMENDATION="Scale telemetry-worker: oc scale deploy/telemetry-worker --replicas=$((WORKER_REPLICAS + 1))"
  warn "Telemetry worker CPU is high (${WORKER_CPU}m)"
fi

if [[ -n "$DB_CPU" ]] && [[ "$DB_CPU" -gt 800 ]]; then
  BOTTLENECK="timescaledb"
  RECOMMENDATION="Optimize DB: Enable batching, add indexes, or upgrade resources"
  warn "TimescaleDB CPU is high (${DB_CPU}m)"
fi

if [[ -z "$BOTTLENECK" ]]; then
  ok "No obvious bottleneck detected"
  echo "  Pipeline is handling $PROCESSING_RATE msg/sec"
fi

header "6. RECOMMENDATIONS"

if [[ -n "$RECOMMENDATION" ]]; then
  echo ""
  echo "Primary issue: $BOTTLENECK"
  echo ""
  echo "Fix:"
  echo "  $RECOMMENDATION"
  echo ""
fi

# General recommendations based on rate
echo "Scaling guide for target throughput:"
echo ""
echo "┌─────────────┬─────────────┬──────────────────┬─────────────┐"
echo "│ Target Rate │ Ingestion   │ Telemetry-worker │ Notes       │"
echo "├─────────────┼─────────────┼──────────────────┼─────────────┤"
echo "│ 100/sec     │ 1 replica   │ 1 replica        │ Default     │"
echo "│ 500/sec     │ 1 replica   │ 2 replicas       │ Scale worker│"
echo "│ 1000/sec    │ 2 replicas  │ 3 replicas       │ Scale both  │"
echo "│ 5000/sec    │ 3 replicas  │ 5 replicas       │ + batch=500 │"
echo "└─────────────┴─────────────┴──────────────────┴─────────────┘"
echo ""

# Quick commands
echo "Quick commands:"
echo "  # Scale workers"
echo "  oc scale deploy/telemetry-worker --replicas=3"
echo ""
echo "  # Check Kafka lag"
echo "  oc exec deploy/kafka -- bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group telemetry-worker --describe"
echo ""
echo "  # Monitor pipeline"
echo "  watch -n1 'oc exec deploy/timescaledb -- psql -U iot -d iot -c \"SELECT COUNT(*) FROM telemetry;\"'"
echo ""

header "SUMMARY"

echo "Current:  $PROCESSING_RATE msg/sec"
echo "Target:   $TARGET_RATE msg/sec"

if (( $(echo "$PROCESSING_RATE >= $TARGET_RATE" | bc -l) )); then
  ok "Pipeline meets target throughput!"
else
  NEEDED_SCALE=$(echo "scale=0; $TARGET_RATE / $PROCESSING_RATE" | bc)
  warn "Pipeline below target. Consider ${NEEDED_SCALE}x scaling."
fi

echo ""
