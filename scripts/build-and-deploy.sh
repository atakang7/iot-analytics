#!/bin/bash

# Build and deploy all services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building IoT Analytics Services ==="

# Build Device Registry
echo "Building Device Registry..."
cd "$PROJECT_ROOT/services/device-registry"
docker build -t device-registry:latest .

# Build Ingestion Service
echo "Building Ingestion Service..."
cd "$PROJECT_ROOT/services/ingestion"
docker build -t ingestion:latest .

# Build Analytics Service
echo "Building Analytics Service..."
cd "$PROJECT_ROOT/services/analytics"
docker build -t analytics:latest .

echo "=== All services built successfully ==="

# Deploy to Kubernetes
echo "=== Deploying to Kubernetes ==="

cd "$PROJECT_ROOT/k8s"

# Deploy infrastructure firstfailed to compute cache key: failed to calculate checksum of ref 9d0c5845-8188-4a9d-9546-7e3d29bd4d7f::quytqijnipe8tewe7dz8eqmt4: "/mvnw": not found
echo "Deploying infrastructure..."
kubectl apply -f infrastructure/

# Wait for infrastructure to be ready
echo "Waiting for infrastructure to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/postgres
kubectl wait --for=condition=available --timeout=120s deployment/rabbitmq

# Deploy services
echo "Deploying services..."
kubectl apply -f services/

echo "=== Deployment complete ==="

# Show status
echo ""
echo "=== Deployment Status ==="
kubectl get pods
echo ""
echo "=== Services ==="
kubectl get services
