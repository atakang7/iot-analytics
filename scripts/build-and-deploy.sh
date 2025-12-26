
#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
WORKERS=(alert-worker stream-worker telemetry-worker kpi-job)
SERVICES=(device-registry ingestion)

echo "=== Building and Deploying All Workers and Services ==="

for worker in "${WORKERS[@]}"; do
    echo "Preparing build context for $worker..."
    rm -rf "$PROJECT_ROOT/services/workers/$worker/common"
    unlink "$PROJECT_ROOT/services/workers/$worker/common" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/services/workers/common" "$PROJECT_ROOT/services/workers/$worker/common"
    echo "Starting OpenShift build for $worker..."
    oc start-build "$worker" --from-dir="$PROJECT_ROOT/services/workers/$worker" || true
    rm -rf "$PROJECT_ROOT/services/workers/$worker/common"
    unlink "$PROJECT_ROOT/services/workers/$worker/common" 2>/dev/null || true
done

# Build and start OpenShift builds for services
for service in "${SERVICES[@]}"; do
	echo "Starting OpenShift build for $service..."
	oc start-build "$service" --from-dir="$PROJECT_ROOT/services/$service" || true
done

echo "=== All builds triggered ==="