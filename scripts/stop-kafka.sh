#!/bin/bash

echo "=== Stopping Kafka infrastructure ==="

docker-compose -f docker-compose.kafka.yml down -v

echo "=== Stopped ==="
