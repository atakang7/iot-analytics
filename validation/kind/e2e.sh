#!/usr/bin/env bash
# Cross the real Kubernetes boundary: API -> Kafka -> TimescaleDB + alerts -> KPI.
set -Eeuo pipefail
CLUSTER="${IOT_KIND_CLUSTER:-iot-analytics}"
NAMESPACE="${IOT_KIND_NAMESPACE:-iot-validation}"
DEPS_NAMESPACE="iot-dependencies"
[[ "$(kubectl config current-context)" == "kind-$CLUSTER" ]] || {
  echo "Refusing to run on a non-kind cluster" >&2; exit 1;
}

temp="$(mktemp -d)"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" >/dev/null 2>&1 || true; done
  rm -rf "$temp"
}
trap cleanup EXIT

kubectl -n "$NAMESPACE" port-forward svc/ingestion 18081:8081 19090:9090 >"$temp/ingestion.log" 2>&1 &
pids+=("$!")
kubectl -n "$NAMESPACE" port-forward svc/device-registry 18080:8080 19091:9090 >"$temp/registry.log" 2>&1 &
pids+=("$!")

for _ in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:18081/telemetry/health >/dev/null 2>&1 &&
     curl -fsS http://127.0.0.1:18080/devices >/dev/null 2>&1; then break; fi
  sleep 2
done
curl -fsS http://127.0.0.1:18081/telemetry/health >/dev/null
curl -fsS http://127.0.0.1:18080/devices >/dev/null

for port in 19090 19091; do
  curl -fsS "http://127.0.0.1:$port/actuator/health/readiness" >"$temp/health"
  grep -q '"status":"UP"' "$temp/health"
  curl -fsS "http://127.0.0.1:$port/actuator/prometheus" >"$temp/metrics"
  grep -q '^jvm_memory_used_bytes' "$temp/metrics"
done

status="$(curl -sS -o "$temp/device" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"name":"Kubernetes Smoke","type":"motor"}' \
  http://127.0.0.1:18080/devices)"
[[ "$status" == 201 ]] || { cat "$temp/device"; exit 1; }

db() {
  kubectl -n "$DEPS_NAMESPACE" exec deploy/timescaledb -- \
    psql -U iot -d iot -Atc "$1" | tr -d '\r\n'
}
device="kind-smoke-$(date +%s)-$$"
stamp="$(db "SELECT to_char((last_processed_at + interval '1 minute') AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM job_watermarks WHERE job_name='kpi_5min'")"
[[ -n "$stamp" ]] || { echo "Missing KPI watermark" >&2; exit 1; }
payload="$(printf '{"deviceId":"%s","deviceType":"motor","sensorId":"temp-1","sensorType":"temperature","timestamp":"%s","unit":"celsius","value":{"value":99}}' "$device" "$stamp")"
for _ in 1 2; do
  code="$(curl -sS -o "$temp/telemetry" -w '%{http_code}' \
    -H 'Content-Type: application/json' -d "$payload" \
    http://127.0.0.1:18081/telemetry)"
  [[ "$code" == 202 ]] || { cat "$temp/telemetry"; exit 1; }
done

samples=0
alerts=0
for _ in $(seq 1 90); do
  samples="$(db "SELECT count(*) FROM telemetry WHERE device_id='$device'")"
  alerts="$(db "SELECT count(*) FROM alerts WHERE device_id='$device'")"
  if [[ "$samples" == 1 && "$alerts" -ge 1 ]]; then break; fi
  sleep 2
done
[[ "$samples" == 1 && "$alerts" -ge 1 ]] || {
  echo "Kubernetes data path broken: samples=$samples alerts=$alerts" >&2; exit 1;
}

job="kind-kpi-$(date +%s)"
kubectl -n "$NAMESPACE" create job "$job" --from=cronjob/kpi-job
kubectl -n "$NAMESPACE" wait --for=condition=complete "job/$job" --timeout=240s
kpis="$(db "SELECT count(*) FROM kpis WHERE device_id='$device'")"
[[ "$kpis" -ge 1 ]] || { echo "Kubernetes KPI path produced no rows" >&2; exit 1; }

echo "PASS: Kubernetes APIs, management metrics, broker acknowledgments, dedupe, alerts and KPI"
