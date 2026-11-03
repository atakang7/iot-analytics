#!/usr/bin/env bash
# Independent proof of Kubernetes foundation: nodes, DNS, CNI, PV and admission.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLUSTER="iot-foundation"
NS="iot-cluster-proof"
[[ "$(kubectl config current-context)" == "kind-$CLUSTER" ]] || {
  echo "Refusing to validate outside the disposable foundation cluster" >&2; exit 1;
}
kubectl get nodes -o json | python3 -c '
import json, sys
nodes = json.load(sys.stdin)["items"]
assert len(nodes) == 3, "expected 1 control-plane and 2 worker nodes"
names = {node["metadata"]["name"] for node in nodes}
assert names == {"iot-foundation-control-plane", "iot-foundation-worker", "iot-foundation-worker2"}, names
for node in nodes:
    states = {c["type"]: c["status"] for c in node["status"]["conditions"]}
    assert states.get("Ready") == "True", node["metadata"]["name"]
print("PASS: control-plane + two Ready worker nodes")
'
kubectl get storageclass standard >/dev/null
kubectl get svc kubernetes -n default >/dev/null

if kubectl get namespace "$NS" >/dev/null 2>&1; then
  echo "Refusing to use existing validation namespace" >&2; exit 1;
fi
kubectl create namespace "$NS"
cleanup() {
  kubectl delete namespace "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

kubectl -n "$NS" apply -f "$ROOT/validation/cluster/fixtures/network.yaml"
kubectl -n "$NS" wait --for=condition=Ready pod/server pod/client --timeout=180s
response="$(kubectl -n "$NS" exec client -- curl -fsS --max-time 10 http://server:5678)"
[[ "$response" == "iot-cross-node-proof" ]] || {
  echo "Cross-node Service/DNS/CNI request failed: $response" >&2; exit 1;
}
echo "PASS: Pod on worker2 resolves Service and reaches Pod on worker1"

kubectl -n "$NS" apply -f "$ROOT/validation/cluster/fixtures/storage-writer.yaml"
kubectl -n "$NS" wait --for=condition=Ready pod/storage-writer --timeout=180s
[[ "$(kubectl -n "$NS" exec storage-writer -- cat /data/marker)" == "durable-cluster-proof" ]]
kubectl -n "$NS" delete pod storage-writer --wait --timeout=120s
kubectl -n "$NS" apply -f "$ROOT/validation/cluster/fixtures/storage-reader.yaml"
kubectl -n "$NS" wait --for=condition=Ready pod/storage-reader --timeout=180s
[[ "$(kubectl -n "$NS" exec storage-reader -- cat /data/marker)" == "durable-cluster-proof" ]]
echo "PASS: dynamic PVC retains data across Pod replacement"

bash "$ROOT/policies/bin/smoke" iot-admission-proof
echo "PASS: foundation networking, storage and native admission policy validated"
