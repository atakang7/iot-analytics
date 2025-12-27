#!/bin/bash
# monitor.sh - Live pipeline monitoring
# Usage: ./monitor.sh

NS="${NAMESPACE:-atakangul-dev}"

clear
echo "Pipeline Monitor - Press Ctrl+C to exit"
echo ""

PREV_COUNT=0

while true; do
  # Get metrics
  COUNT=$(oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" 2>/dev/null | tr -d ' ')
  LAG=$(oc exec deploy/kafka -n "$NS" -- bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 --group telemetry-worker --describe 2>/dev/null \
    | awk '/iot.telemetry/{sum+=$5} END{print sum+0}')
  
  # Calculate rate
  RATE=$((COUNT - PREV_COUNT))
  PREV_COUNT=$COUNT
  
  # Get replicas
  ING_REP=$(oc get deploy ingestion -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  WRK_REP=$(oc get deploy telemetry-worker -n "$NS" -o jsonpath='{.spec.replicas}' 2>/dev/null)
  
  # Display
  tput cup 2 0  # Move cursor
  echo "┌────────────────────────────────────────────────┐"
  echo "│ $(date +%H:%M:%S)                                        │"
  echo "├────────────────────────────────────────────────┤"
  printf "│ DB Records:      %-28s │\n" "$COUNT"
  printf "│ Rate:            %-28s │\n" "$RATE msg/sec"
  printf "│ Kafka Lag:       %-28s │\n" "$LAG"
  echo "├────────────────────────────────────────────────┤"
  printf "│ Ingestion:       %-28s │\n" "$ING_REP replicas"
  printf "│ Worker:          %-28s │\n" "$WRK_REP replicas"
  echo "├────────────────────────────────────────────────┤"
  
  # Status
  if [[ "$LAG" -gt 1000 ]]; then
    echo "│ Status: ⚠️  HIGH LAG - scale worker            │"
  elif [[ "$LAG" -gt 100 ]]; then
    echo "│ Status: ⚡ Processing...                       │"
  else
    echo "│ Status: ✓ Healthy                             │"
  fi
  echo "└────────────────────────────────────────────────┘"
  echo ""
  echo "Commands:"
  echo "  oc scale deploy/telemetry-worker --replicas=N"
  echo "  oc scale deploy/ingestion --replicas=N"
  
  sleep 1
done
