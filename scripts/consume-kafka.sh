#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPIC="${1:-iot.telemetry}"
docker compose -f "$ROOT/services/docker-compose.yml" exec kafka \
  /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server kafka:9092 --topic "$TOPIC" --from-beginning \
  --timeout-ms 15000
