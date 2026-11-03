#!/usr/bin/env bash
# OpenShift binary-image builds. Requires BuildConfigs from iot-helm.
# This script neither edits the checkout nor masks build failures.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${NAMESPACE:-atakangul-dev}"
WORKERS=(telemetry-worker stream-worker alert-worker kpi-job)
SERVICES=(ingestion device-registry)

for component in "${WORKERS[@]}"; do
  echo "Building $component from shared worker Docker context"
  oc get buildconfig "$component" -n "$NAMESPACE" >/dev/null
  oc start-build "$component" -n "$NAMESPACE" \
    --from-dir="$ROOT/services/workers" --follow --wait
done

for component in "${SERVICES[@]}"; do
  echo "Building $component"
  oc get buildconfig "$component" -n "$NAMESPACE" >/dev/null
  oc start-build "$component" -n "$NAMESPACE" \
    --from-dir="$ROOT/services/$component" --follow --wait
done

echo "All OpenShift binary builds completed successfully."
