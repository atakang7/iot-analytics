#!/bin/bash
# scripts/setup-cicd.sh
# Creates service account and outputs GitHub Actions secrets
set -e

NAMESPACE="${NAMESPACE:-atakangul-dev}"
SA_NAME="github-actions"

echo "════════════════════════════════════════════"
echo " CI/CD Setup for GitHub Actions"
echo "════════════════════════════════════════════"
echo ""

# Check oc login
if ! oc whoami &>/dev/null; then
  echo "Error: Not logged into OpenShift. Run 'oc login' first."
  exit 1
fi

echo "[1/4] Creating service account: $SA_NAME"
oc create serviceaccount $SA_NAME -n $NAMESPACE 2>/dev/null && echo "Created" || echo "Already exists"

echo ""
echo "[2/4] Granting permissions"
oc policy add-role-to-user edit -z $SA_NAME -n $NAMESPACE 2>/dev/null || true

echo ""
echo "[3/4] Creating long-lived token"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${SA_NAME}-token
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF

sleep 2

echo ""
echo "[4/4] Extracting credentials"

TOKEN=$(oc get secret ${SA_NAME}-token -n $NAMESPACE -o jsonpath='{.data.token}' | base64 -d)
SERVER=$(oc whoami --show-server)

echo ""
echo "════════════════════════════════════════════"
echo " GitHub Repository Secrets"
echo "════════════════════════════════════════════"
echo ""
echo "Go to: GitHub Repo → Settings → Secrets → Actions"
echo "Add these three secrets:"
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ OPENSHIFT_SERVER                                           │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│ $SERVER"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ OPENSHIFT_NAMESPACE                                        │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│ $NAMESPACE"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│ OPENSHIFT_TOKEN                                            │"
echo "├─────────────────────────────────────────────────────────────┤"
echo "│ ${TOKEN:0:50}..."
echo "│ (Full token saved to: .github-token)"
echo "└─────────────────────────────────────────────────────────────┘"

# Save full token to file
echo "$TOKEN" > .github-token
chmod 600 .github-token

echo ""
echo "════════════════════════════════════════════"
echo " Verification"
echo "════════════════════════════════════════════"
echo ""
echo "Test the token works:"
echo "  oc login --token=\$(cat .github-token) --server=$SERVER"
echo ""
echo "Delete token file after adding to GitHub:"
echo "  rm .github-token"
echo ""
echo "Done!"
