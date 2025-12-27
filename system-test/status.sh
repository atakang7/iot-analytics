#!/bin/bash
# status.sh - Quick pipeline status check
NS="${NAMESPACE:-atakangul-dev}"

echo "═══════════════════════════════════════════"
echo " PIPELINE STATUS"
echo "═══════════════════════════════════════════"

echo ""
echo "COMPONENTS:"
printf "  %-20s %s replicas\n" "ingestion" "$(oc get deploy ingestion -n $NS -o jsonpath='{.spec.replicas}' 2>/dev/null)"
printf "  %-20s %s replicas\n" "telemetry-worker" "$(oc get deploy telemetry-worker -n $NS -o jsonpath='{.spec.replicas}' 2>/dev/null)"
printf "  %-20s %s replicas\n" "kafka" "$(oc get deploy kafka -n $NS -o jsonpath='{.spec.replicas}' 2>/dev/null)"
printf "  %-20s %s replicas\n" "timescaledb" "$(oc get deploy timescaledb -n $NS -o jsonpath='{.spec.replicas}' 2>/dev/null)"

echo ""
echo "METRICS:"
COUNT=$(oc exec deploy/timescaledb -n "$NS" -- psql -U iot -d iot -t -c "SELECT COUNT(*) FROM telemetry;" 2>/dev/null | tr -d ' ')
printf "  %-20s %s\n" "DB records:" "$COUNT"

LAG=$(oc exec deploy/kafka -n "$NS" -- bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --group telemetry-worker --describe 2>/dev/null \
  | awk '/iot.telemetry/{sum+=$5} END{print sum+0}')
printf "  %-20s %s\n" "Kafka consumer lag:" "$LAG"

echo ""
echo "HEALTH:"
if [[ "$LAG" -gt 1000 ]]; then
  echo "  ⚠️  HIGH LAG - telemetry-worker can't keep up"
  echo "     Fix: oc scale deploy/telemetry-worker --replicas=\$((current+1))"
elif [[ "$LAG" -gt 100 ]]; then
  echo "  ⚡ Some lag - processing"
else
  echo "  ✓ Healthy"
fi
echo ""
