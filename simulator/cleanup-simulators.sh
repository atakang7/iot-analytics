#!/bin/bash
# cleanup-simulators.sh
NS="${NAMESPACE:-atakangul-dev}"
echo "Deleting all simulators..."
oc delete deploy -l app=device-simulator -n "$NS" 2>/dev/null || true
oc delete cm simulator-script -n "$NS" 2>/dev/null || true
echo "Done"
oc get pods -l app=device-simulator -n "$NS" 2>/dev/null || echo "No simulators running"
