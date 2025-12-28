#!/bin/bash
# GitOps Controller v2 - CI-aware, parallel builds, helm deploy
set -o pipefail

WORKDIR="/tmp/repo"
STATE_DIR="/tmp/state"
STATE_FILE="$STATE_DIR/last_sha"
JOBS_DIR="$STATE_DIR/jobs"
BIN_DIR="/tmp/bin"
SERVICE="gitops-controller"

export PATH="$BIN_DIR:$PATH"
mkdir -p "$STATE_DIR" "$JOBS_DIR" "$BIN_DIR"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log() {
  local level="$1" msg="$2" extra="${3:-}"
  local ts=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  if [[ -n "$extra" ]]; then
    echo "{\"timestamp\":\"$ts\",\"level\":\"$level\",\"service\":\"$SERVICE\",\"message\":\"$msg\",$extra}"
  else
    echo "{\"timestamp\":\"$ts\",\"level\":\"$level\",\"service\":\"$SERVICE\",\"message\":\"$msg\"}"
  fi
}

log_info() { log "info" "$1" "$2"; }
log_warn() { log "warn" "$1" "$2"; }
log_error() { log "error" "$1" "$2"; }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NOTIFICATIONS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
notify_slack() {
  local status="$1" message="$2" components="${3:-}"
  [[ -z "$SLACK_WEBHOOK" ]] && return 0
  
  local color="good"
  [[ "$status" == "failure" ]] && color="danger"
  [[ "$status" == "warning" ]] && color="warning"
  
  local payload=$(cat <<EOF
{
  "attachments": [{
    "color": "$color",
    "title": "GitOps Deploy: $status",
    "text": "$message",
    "fields": [
      {"title": "Components", "value": "$components", "short": true}
    ],
    "footer": "$GITHUB_OWNER/$GITHUB_REPO_NAME"
  }]
}
EOF
)
  curl -s -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK" >/dev/null 2>&1
}

update_github_status() {
  local sha="$1" state="$2" context="$3" description="$4"
  [[ -z "$GIT_TOKEN" ]] && return 0
  
  curl -s -X POST \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/statuses/$sha" \
    -d "{\"state\":\"$state\",\"context\":\"$context\",\"description\":\"$description\"}" >/dev/null 2>&1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLI SETUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_cli() {
  local tool="$1" check_cmd="$2" install_cmd="$3"
  
  if eval "$check_cmd" >/dev/null 2>&1; then
    log_info "$tool already installed"
    return 0
  fi
  
  log_info "Installing $tool"
  if eval "$install_cmd"; then
    log_info "$tool installed"
    return 0
  else
    log_error "Failed to install $tool"
    return 1
  fi
}

setup_all_cli() {
  # oc
  setup_cli "oc" "command -v oc" \
    "curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz | tar -xz -C $BIN_DIR oc" || return 1
  
  # helm
  setup_cli "helm" "command -v helm" \
    "curl -sL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar -xz -C /tmp && mv /tmp/linux-amd64/helm $BIN_DIR/" || return 1
  
  # trivy
  if [[ "$IMAGE_SCAN_ENABLED" == "true" ]]; then
    setup_cli "trivy" "command -v trivy" \
      "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $BIN_DIR" || return 1
  fi
  
  # jq
  setup_cli "jq" "command -v jq" \
    "curl -sL https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 -o $BIN_DIR/jq && chmod +x $BIN_DIR/jq" || return 1
  
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GITHUB API
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
get_latest_successful_run() {
  local response
  response=$(curl -s -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/actions/runs?status=success&per_page=1")
  
  local sha branch run_id
  sha=$(echo "$response" | jq -r '.workflow_runs[0].head_sha // empty')
  branch=$(echo "$response" | jq -r '.workflow_runs[0].head_branch // empty')
  run_id=$(echo "$response" | jq -r '.workflow_runs[0].id // empty')
  
  if [[ -z "$sha" ]]; then
    return 1
  fi
  
  echo "$sha $branch $run_id"
}

get_changed_files() {
  local sha="$1"
  curl -s -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits/$sha" | jq -r '.files[].filename // empty'
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GIT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
clone_repo() {
  local sha="$1"
  local url="$GIT_REPO"
  [[ -n "$GIT_TOKEN" ]] && url="${url/https:\/\//https://${GIT_TOKEN}@}"
  
  rm -rf "$WORKDIR"
  git clone --depth 1 -q "$url" "$WORKDIR" 2>/dev/null || return 1
  cd "$WORKDIR" && git fetch --depth 1 origin "$sha" -q && git checkout "$sha" -q 2>/dev/null
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUILD & DEPLOY (per component)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
deploy_component() {
  local component="$1" path="$2" type="$3" sha="$4"
  local job_file="$JOBS_DIR/$component"
  local image_ref=""
  
  log_info "Starting deploy" "\"component\":\"$component\",\"type\":\"$type\",\"sha\":\"${sha:0:12}\""
  update_github_status "$sha" "pending" "deploy/$component" "Building..."
  
  cd "$WORKDIR"
  
  # Copy common for Python workers
  if [[ "$type" == "python" ]] && [[ -d "$PYTHON_PATH/common" ]]; then
    cp -r "$PYTHON_PATH/common" "$path/common"
  fi
  
  #── BUILD ──────────────────────────────────────────────────────────────────
  local build_start=$(date +%s)
  local build_output
  build_output=$(oc start-build "$component" --from-dir="$path" --follow --wait 2>&1)
  local build_status=$?
  local build_duration=$(($(date +%s) - build_start))
  
  # Cleanup common
  [[ -d "$path/common" ]] && rm -rf "$path/common"
  
  if [[ $build_status -ne 0 ]]; then
    log_error "Build failed" "\"component\":\"$component\",\"duration\":$build_duration"
    update_github_status "$sha" "failure" "deploy/$component" "Build failed"
    echo "failure" > "$job_file"
    return 1
  fi
  
  log_info "Build success" "\"component\":\"$component\",\"duration\":$build_duration"
  
  # Get image reference
  image_ref=$(oc get buildconfig "$component" -o jsonpath='{.spec.output.to.name}' 2>/dev/null)
  image_ref="image-registry.openshift-image-registry.svc:5000/$HELM_NAMESPACE/$image_ref"
  
  #── IMAGE SCAN ─────────────────────────────────────────────────────────────
  if [[ "$IMAGE_SCAN_ENABLED" == "true" ]]; then
    log_info "Scanning image" "\"component\":\"$component\",\"image\":\"$image_ref\""
    update_github_status "$sha" "pending" "deploy/$component" "Scanning..."
    
    local scan_result
    scan_result=$(trivy image --severity CRITICAL --exit-code 1 --quiet "$image_ref" 2>&1)
    local scan_status=$?
    
    if [[ $scan_status -ne 0 ]] && [[ "$IMAGE_SCAN_FAIL_CRITICAL" == "true" ]]; then
      log_error "Critical vulnerabilities found" "\"component\":\"$component\""
      update_github_status "$sha" "failure" "deploy/$component" "Security scan failed"
      echo "failure" > "$job_file"
      return 1
    fi
    
    log_info "Scan passed" "\"component\":\"$component\""
  fi
  
  #── HELM DEPLOY ────────────────────────────────────────────────────────────
  log_info "Helm upgrade" "\"component\":\"$component\""
  update_github_status "$sha" "pending" "deploy/$component" "Deploying..."
  
  local helm_output
  helm_output=$(helm upgrade "$HELM_RELEASE" "$WORKDIR/$HELM_CHART_PATH" \
    --namespace "$HELM_NAMESPACE" \
    --reuse-values \
    --set "$component.image.tag=$sha" \
    --wait --timeout 120s 2>&1)
  local helm_status=$?
  
  if [[ $helm_status -ne 0 ]]; then
    log_error "Helm upgrade failed" "\"component\":\"$component\",\"error\":\"${helm_output:0:200}\""
    update_github_status "$sha" "failure" "deploy/$component" "Deploy failed"
    echo "failure" > "$job_file"
    return 1
  fi
  
  log_info "Helm upgrade success" "\"component\":\"$component\""
  
  #── SMOKE TEST ─────────────────────────────────────────────────────────────
  log_info "Smoke test" "\"component\":\"$component\""
  
  local health_path="/health"
  [[ "$type" == "java" ]] && health_path="/actuator/health"
  
  local smoke_ok=0
  for i in {1..5}; do
    if curl -sf "http://$component:8080$health_path" >/dev/null 2>&1; then
      smoke_ok=1
      break
    fi
    sleep 3
  done
  
  if [[ $smoke_ok -eq 0 ]]; then
    log_warn "Smoke test failed" "\"component\":\"$component\""
    update_github_status "$sha" "failure" "deploy/$component" "Smoke test failed"
    echo "failure" > "$job_file"
    return 1
  fi
  
  log_info "Smoke test passed" "\"component\":\"$component\""
  update_github_status "$sha" "success" "deploy/$component" "Deployed"
  echo "success" > "$job_file"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DETECT & DISPATCH
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
process_commit() {
  local sha="$1"
  local files
  files=$(get_changed_files "$sha")
  
  [[ -z "$files" ]] && { log_info "No files changed"; return 0; }
  
  log_info "Processing commit" "\"sha\":\"${sha:0:12}\",\"files\":$(echo "$files" | wc -l)"
  
  # Clear previous job results
  rm -f "$JOBS_DIR"/*
  
  local components=""
  local pids=()
  
  # Detect Java services
  for svc in $JAVA_SERVICES; do
    if echo "$files" | grep -q "^$JAVA_PATH/$svc/"; then
      log_info "Detected Java change" "\"component\":\"$svc\""
      components="$components $svc"
      deploy_component "$svc" "$JAVA_PATH/$svc" "java" "$sha" &
      pids+=($!)
    fi
  done
  
  # Detect Python workers (including common/ trigger)
  local python_triggered=""
  if echo "$files" | grep -q "^$PYTHON_PATH/common/"; then
    python_triggered="$PYTHON_WORKERS"
    log_info "Common changed, triggering all workers"
  else
    for wrk in $PYTHON_WORKERS; do
      if echo "$files" | grep -q "^$PYTHON_PATH/$wrk/"; then
        python_triggered="$python_triggered $wrk"
      fi
    done
  fi
  
  for wrk in $python_triggered; do
    log_info "Detected Python change" "\"component\":\"$wrk\""
    components="$components $wrk"
    deploy_component "$wrk" "$PYTHON_PATH/$wrk" "python" "$sha" &
    pids+=($!)
  done
  
  # Nothing to deploy
  if [[ ${#pids[@]} -eq 0 ]]; then
    log_info "No components to deploy"
    return 0
  fi
  
  # Wait for all jobs
  log_info "Waiting for ${#pids[@]} jobs"
  local failed=0
  for pid in "${pids[@]}"; do
    wait "$pid" || ((failed++))
  done
  
  # Collect results
  local success_list="" fail_list=""
  for f in "$JOBS_DIR"/*; do
    [[ ! -f "$f" ]] && continue
    local comp=$(basename "$f")
    local result=$(cat "$f")
    if [[ "$result" == "success" ]]; then
      success_list="$success_list $comp"
    else
      fail_list="$fail_list $comp"
    fi
  done
  
  # Notify
  components=$(echo "$components" | xargs)
  if [[ $failed -eq 0 ]]; then
    log_info "All deployments succeeded" "\"components\":\"$components\""
    notify_slack "success" "Deployed: $success_list" "$components"
  else
    log_error "Some deployments failed" "\"failed\":\"$fail_list\",\"succeeded\":\"$success_list\""
    notify_slack "failure" "Failed: $fail_list | Succeeded: $success_list" "$components"
  fi
  
  return $failed
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN LOOP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
  log_info "Controller starting" "\"repo\":\"$GITHUB_OWNER/$GITHUB_REPO_NAME\",\"poll\":\"$POLL_INTERVAL\""
  log_info "Watching" "\"java\":\"$JAVA_SERVICES\",\"python\":\"$PYTHON_WORKERS\""
  
  setup_all_cli || { log_error "CLI setup failed"; exit 1; }
  
  local last_sha=""
  [[ -f "$STATE_FILE" ]] && last_sha=$(cat "$STATE_FILE")
  [[ -n "$last_sha" ]] && log_info "Resuming" "\"last_sha\":\"${last_sha:0:12}\""
  
  while true; do
    local run_info sha branch run_id
    run_info=$(get_latest_successful_run)
    
    if [[ -z "$run_info" ]]; then
      log_warn "No successful CI runs found"
      sleep "$POLL_INTERVAL"
      continue
    fi
    
    read sha branch run_id <<< "$run_info"
    
    # Already processed?
    if [[ "$sha" == "$last_sha" ]]; then
      sleep "$POLL_INTERVAL"
      continue
    fi
    
    log_info "New CI success" "\"sha\":\"${sha:0:12}\",\"branch\":\"$branch\",\"run_id\":\"$run_id\""
    
    # Clone and deploy
    if clone_repo "$sha"; then
      process_commit "$sha"
      last_sha="$sha"
      echo "$last_sha" > "$STATE_FILE"
    else
      log_error "Clone failed"
    fi
    
    sleep "$POLL_INTERVAL"
  done
}

main