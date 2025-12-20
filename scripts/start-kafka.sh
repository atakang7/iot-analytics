#!/bin/bash

set -e

echo "=== Starting Kafka infrastructure ==="

# Start services
docker-compose -f docker-compose.kafka.yml up -d

echo "Waiting for Kafka to be ready..."
sleep 10

# Wait for topics to be created
for i in {1..30}; do
    if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list | grep -q "sensor-readings"; then
        echo "✓ Topics created successfully"
        break
    fi
    echo "Waiting for topics... ($i/30)"
    sleep 2
done

# Show topics
echo ""
echo "=== Kafka Topics ==="
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

echo ""
echo "=== Kafka UI ==="
echo "Open http://localhost:8090 to view Kafka UI"

echo ""
echo "=== Ready! ==="
echo "Kafka is running on localhost:9092"
