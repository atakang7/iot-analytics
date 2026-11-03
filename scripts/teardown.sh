#!/usr/bin/env bash
# Explicit, scope-limited OpenShift Helm removal; never deletes --all workloads.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash scripts/teardown.sh --namespace NAME [--release NAME] [--execute --confirm RELEASE/NAMESPACE]
By default this is a DRY RUN. Execution removes only the named Helm release,
which may delete Helm-managed PVCs. Back up persistent data first.
EOF
}

NAMESPACE=""
RELEASE="iot-analytics"
EXECUTE=false
CONFIRM=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --release) RELEASE="${2:-}"; shift 2 ;;
    --execute) EXECUTE=true; shift ;;
    --confirm) CONFIRM="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

if [ -z "$NAMESPACE" ] || [ -z "$RELEASE" ]; then
  usage >&2
  exit 2
fi

case "$NAMESPACE" in
  default|kube-system|kube-public|kube-node-lease|openshift|openshift-*)
    echo "Refusing to uninstall in a system/default namespace." >&2
    exit 2 ;;
esac

if [ "$EXECUTE" = false ]; then
  echo "DRY RUN: would uninstall Helm release '$RELEASE' in namespace '$NAMESPACE'."
  echo "Helm-managed PVCs and other data may be deleted by uninstall."
  echo "To execute: --execute --confirm '$RELEASE/$NAMESPACE'"
  exit 0
fi

if [ "$CONFIRM" != "$RELEASE/$NAMESPACE" ]; then
  echo "Confirmation mismatch: expected --confirm '$RELEASE/$NAMESPACE'." >&2
  exit 2
fi

# Scope remains explicit: no oc delete --all and no cluster-wide wildcard.
helm status "$RELEASE" --namespace "$NAMESPACE" >/dev/null
helm uninstall "$RELEASE" --namespace "$NAMESPACE"
