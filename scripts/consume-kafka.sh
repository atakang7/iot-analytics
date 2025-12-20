#!/bin/bash

# Consume messages from Kafka topics to verify ingestion

TOPIC="${1:-sensor-readings}"
TIMEOUT="${2:-30}"

echo "=== Consuming from topic: $TOPIC ==="
echo "Press Ctrl+C to stop or wait $TIMEOUT seconds"
echo ""

docker exec kafka kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic "$TOPIC" \
    --from-beginning \
    --timeout-ms $((TIMEOUT * 1000)) \
    --property print.key=true \
    --property key.separator=" -> " \
    2>/dev/null || true

echo ""
echo "=== Consumption complete ==="
