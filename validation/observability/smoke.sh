#!/usr/bin/env bash
# Live Prometheus, Grafana, Alertmanager and Loki checks, read-only.
set -Eeuo pipefail
[[ "$(kubectl config current-context)" == "kind-iot-analytics" ]] || {
  echo "Observability proof restricted to disposable kind" >&2; exit 1;
}
obs="iot-observability"
app="iot-validation"
[[ "$(kubectl -n "$app" get deployment/iot-log-collector -o jsonpath='{.status.readyReplicas}')" == 1 ]] || {
  echo "Log collector is not ready" >&2; exit 1;
}
directory="$(mktemp -d)"
cleanup() {
  for pid in $(jobs -pr); do kill "$pid" >/dev/null 2>&1 || true; done
  rm -rf "$directory"
}
trap cleanup EXIT
kubectl -n "$obs" port-forward svc/prometheus 19092:9090 >"$directory/prometheus.log" 2>&1 &
kubectl -n "$obs" port-forward svc/loki 13100:3100 >"$directory/loki.log" 2>&1 &
kubectl -n "$obs" port-forward svc/grafana 13000:3000 >"$directory/grafana.log" 2>&1 &
kubectl -n "$obs" port-forward svc/alertmanager 19093:9093 >"$directory/alertmanager.log" 2>&1 &
password="$(kubectl -n "$obs" get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d)"
export IOT_GRAFANA_PASSWORD="$password"
python3 validation/observability/verify.py
unset password IOT_GRAFANA_PASSWORD
