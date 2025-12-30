#!/bin/bash
# benchmark.sh - Quick throughput measurement
# Usage: ./benchmark.sh [messages] [parallel_workers]

NS="${NAMESPACE:-atakangul-dev}"
MESSAGES="${1:-1000}"
PARALLEL="${2:-10}"

echo "═══════════════════════════════════════════"
echo " BENCHMARK: $MESSAGES messages, $PARALLEL workers"
echo "═══════════════════════════════════════════"

# Count before
BEFORE=$(oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" | tr -d ' ')
echo "DB count before: $BEFORE"

# Start time
START=$(date +%s.%N)

# Send messages
echo "Sending..."
oc run bench-$$ --rm -i --restart=Never -n "$NS" --image=python:3.11-slim -- python3 -c "
import urllib.request, json, time, threading, sys
from datetime import datetime

TOTAL = $MESSAGES
WORKERS = $PARALLEL
URL = 'http://ingestion:8081/telemetry'

sent = 0
errors = 0
lock = threading.Lock()

def send_one(i):
    global sent, errors
    payload = json.dumps({
        'deviceId': f'bench-{i}',
        'deviceType': 'benchmark',
        'sensorId': 'sensor',
        'sensorType': 'temperature',
        'timestamp': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'unit': 'celsius',
        'value': {'value': 150.0}
    }).encode()
    
    try:
        req = urllib.request.Request(URL, data=payload, headers={'Content-Type': 'application/json'})
        urllib.request.urlopen(req, timeout=10)
        with lock:
            sent += 1
    except Exception as e:
        with lock:
            errors += 1

def worker(start, end):
    for i in range(start, end):
        send_one(i)

# Split work
per_worker = TOTAL // WORKERS
threads = []
for w in range(WORKERS):
    start_idx = w * per_worker
    end_idx = start_idx + per_worker if w < WORKERS - 1 else TOTAL
    t = threading.Thread(target=worker, args=(start_idx, end_idx))
    threads.append(t)

start_time = time.time()
for t in threads:
    t.start()
for t in threads:
    t.join()
elapsed = time.time() - start_time

print(f'SENT:{sent}')
print(f'ERRORS:{errors}')
print(f'TIME:{elapsed:.2f}')
print(f'RATE:{sent/elapsed:.2f}')
" 2>&1

END=$(date +%s.%N)

# Wait for pipeline
echo ""
echo "Waiting for pipeline to drain..."
sleep 5

# Check Kafka lag
LAG=$(oc exec deploy/kafka -n "$NS" -- bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --group telemetry-worker --describe 2>/dev/null \
  | awk '/telemetry/{sum+=$5} END{print sum+0}')
echo "Kafka consumer lag: $LAG"

# Wait more if lag
if [[ "$LAG" -gt 100 ]]; then
  echo "Waiting for consumer to catch up..."
  while [[ "$LAG" -gt 10 ]]; do
    sleep 2
    LAG=$(oc exec deploy/kafka -n "$NS" -- bin/kafka-consumer-groups.sh \
      --bootstrap-server localhost:9092 --group telemetry-worker --describe 2>/dev/null \
      | awk '/telemetry/{sum+=$5} END{print sum+0}')
    echo "  Lag: $LAG"
  done
fi

# Count after
AFTER=$(oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" | tr -d ' ')
STORED=$((AFTER - BEFORE))

TOTAL_TIME=$(echo "$END - $START" | bc)
E2E_RATE=$(echo "scale=2; $STORED / $TOTAL_TIME" | bc)

echo ""
echo "═══════════════════════════════════════════"
echo " RESULTS"
echo "═══════════════════════════════════════════"
echo "Messages sent:     $MESSAGES"
echo "Messages stored:   $STORED"
echo "Total time:        ${TOTAL_TIME}s"
echo ""
echo "Ingestion rate:    (see above)"
echo "End-to-end rate:   $E2E_RATE msg/sec"
echo ""
echo "Bottleneck:"
if [[ "$LAG" -gt 100 ]]; then
  echo "  → telemetry-worker (consumer lag was high)"
elif [[ "$STORED" -lt "$MESSAGES" ]]; then
  echo "  → ingestion/kafka (messages lost)"
else
  echo "  → none detected"
fi
