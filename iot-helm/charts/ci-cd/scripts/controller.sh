#!/bin/bash
# GitOps Controller v4 - Full observability
set -o pipefail

WORKDIR="/tmp/repo"
STATE_DIR="/tmp/state"
STATE_FILE="$STATE_DIR/last_sha"
PROCESSED_FILE="$STATE_DIR/processed"
JOBS_DIR="$STATE_DIR/jobs"
BIN_DIR="/tmp/bin"
SERVICE="gitops-controller"

export PATH="$BIN_DIR:$PATH"
mkdir -p "$STATE_DIR" "$JOBS_DIR" "$BIN_DIR"
touch "$PROCESSED_FILE"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING - verbose by default
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
log_debug() { log "debug" "$1" "$2"; }

# Escape JSON string
json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  str="${str//$'\r'/}"
  echo "$str"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GITHUB STATUS - Always update, never leave pending
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
update_github_status() {
  local sha="$1" state="$2" context="$3" description="$4"
  
  log_info "Updating GitHub status" "\"sha\":\"${sha:0:12}\",\"state\":\"$state\",\"context\":\"$context\",\"description\":\"$description\""
  
  if [[ -z "$GIT_TOKEN" ]]; then
    log_warn "No GIT_TOKEN, skipping status update"
    return 0
  fi
  
  local response
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/statuses/$sha" \
    -d "{\"state\":\"$state\",\"context\":\"$context\",\"description\":\"$description\"}")
  
  local http_code=$(echo "$response" | tail -1)
  local body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "201" ]]; then
    log_error "Failed to update GitHub status" "\"http_code\":\"$http_code\",\"response\":\"$(json_escape "$body")\""
    return 1
  fi
  
  log_info "GitHub status updated" "\"http_code\":\"$http_code\""
  return 0
}

mark_sha_processed() {
  local sha="$1"
  echo "$sha" >> "$PROCESSED_FILE"
  log_debug "Marked SHA as processed" "\"sha\":\"${sha:0:12}\""
}

is_sha_processed() {
  local sha="$1"
  grep -q "^$sha$" "$PROCESSED_FILE" 2>/dev/null
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NOTIFICATIONS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
notify_slack() {
  local status="$1" message="$2" components="${3:-}"
  
  if [[ -z "$SLACK_WEBHOOK" ]]; then
    log_debug "No SLACK_WEBHOOK, skipping notification"
    return 0
  fi
  
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

  local response
  response=$(curl -s -w "\n%{http_code}" -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK")
  local http_code=$(echo "$response" | tail -1)
  
  if [[ "$http_code" != "200" ]]; then
    log_warn "Slack notification failed" "\"http_code\":\"$http_code\""
  else
    log_info "Slack notification sent" "\"status\":\"$status\""
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLI SETUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_cli() {
  local tool="$1" check_cmd="$2" install_cmd="$3"
  
  log_debug "Checking $tool"
  
  if eval "$check_cmd" >/dev/null 2>&1; then
    local version=$(eval "$check_cmd --version 2>/dev/null | head -1" || echo "unknown")
    log_info "$tool already installed" "\"version\":\"$version\""
    return 0
  fi
  
  log_info "Installing $tool"
  local output
  output=$(eval "$install_cmd" 2>&1)
  local status=$?
  
  if [[ $status -ne 0 ]]; then
    log_error "Failed to install $tool" "\"exit_code\":$status,\"output\":\"$(json_escape "$output")\""
    return 1
  fi
  
  log_info "$tool installed successfully"
  return 0
}

setup_all_cli() {
  log_info "Setting up CLI tools"
  
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
  
  log_info "All CLI tools ready"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GITHUB API
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
get_pending_deploy() {
  log_debug "Checking for pending deploys"
  
  local response
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits?per_page=10")
  
  local http_code=$(echo "$response" | tail -1)
  local body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "200" ]]; then
    log_error "Failed to fetch commits" "\"http_code\":\"$http_code\",\"response\":\"$(json_escape "$body")\""
    return 1
  fi
  
  local sha
  for sha in $(echo "$body" | jq -r '.[].sha'); do
    # Skip already processed
    if is_sha_processed "$sha"; then
      log_debug "SHA already processed, skipping" "\"sha\":\"${sha:0:12}\""
      continue
    fi
    
    local status_response
    status_response=$(curl -s -H "Authorization: token $GIT_TOKEN" \
      "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits/$sha/status")
    
    local pending
    pending=$(echo "$status_response" | jq -r '.statuses[] | select(.context == "deploy/cd" and .state == "pending") | .state')
    
    if [[ "$pending" == "pending" ]]; then
      log_info "Found pending deploy" "\"sha\":\"${sha:0:12}\""
      echo "$sha"
      return 0
    fi
  done
  
  log_debug "No pending deploys found"
  return 1
}

get_changed_files() {
  local sha="$1"
  
  log_debug "Fetching changed files" "\"sha\":\"${sha:0:12}\""
  
  local response
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits/$sha")
  
  local http_code=$(echo "$response" | tail -1)
  local body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "200" ]]; then
    log_error "Failed to fetch commit details" "\"http_code\":\"$http_code\""
    return 1
  fi
  
  local files
  files=$(echo "$body" | jq -r '.files[].filename // empty')
  
  local count=$(echo "$files" | grep -c . || echo 0)
  log_info "Found changed files" "\"sha\":\"${sha:0:12}\",\"count\":$count"
  
  echo "$files"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GIT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
clone_repo() {
  local sha="$1"
  local url="$GIT_REPO"
  [[ -n "$GIT_TOKEN" ]] && url="${url/https:\/\//https://${GIT_TOKEN}@}"
  
  log_info "Cloning repo" "\"sha\":\"${sha:0:12}\",\"repo\":\"$GIT_REPO\""
  
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR"
  
  local output
  
  output=$(git init -q 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "git init failed" "\"error\":\"$(json_escape "$output")\""
    return 1
  fi
  
  output=$(git remote add origin "$url" 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "git remote add failed" "\"error\":\"$(json_escape "$output")\""
    return 1
  fi
  
  output=$(git fetch --depth 1 origin "$sha" 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "git fetch failed" "\"sha\":\"${sha:0:12}\",\"error\":\"$(json_escape "$output")\""
    return 1
  fi
  
  output=$(git checkout FETCH_HEAD -q 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "git checkout failed" "\"sha\":\"${sha:0:12}\",\"error\":\"$(json_escape "$output")\""
    return 1
  fi
  
  log_info "Clone success" "\"sha\":\"${sha:0:12}\""
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELM
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
helm_rollback() {
  log_info "Attempting helm rollback" "\"release\":\"$HELM_RELEASE\",\"namespace\":\"$HELM_NAMESPACE\""
  
  local history_output
  history_output=$(helm history "$HELM_RELEASE" -n "$HELM_NAMESPACE" -o json 2>&1)
  local history_status=$?
  
  if [[ $history_status -ne 0 ]]; then
    log_error "Failed to get helm history" "\"error\":\"$(json_escape "$history_output")\""
    return 1
  fi
  
  local current_revision
  current_revision=$(echo "$history_output" | jq -r '.[-1].revision' 2>/dev/null)
  
  if [[ -z "$current_revision" ]] || [[ "$current_revision" == "null" ]]; then
    log_error "Could not determine current revision"
    return 1
  fi
  
  if [[ "$current_revision" -le 1 ]]; then
    log_warn "No previous revision to rollback to" "\"current_revision\":$current_revision"
    return 1
  fi
  
  local prev_revision=$((current_revision - 1))
  log_info "Rolling back" "\"from_revision\":$current_revision,\"to_revision\":$prev_revision"
  
  local rollback_output
  rollback_output=$(helm rollback "$HELM_RELEASE" "$prev_revision" -n "$HELM_NAMESPACE" --wait --timeout 120s 2>&1)
  local rollback_status=$?
  
  if [[ $rollback_status -ne 0 ]]; then
    log_error "Rollback failed" "\"error\":\"$(json_escape "$rollback_output")\""
    return 1
  fi
  
  log_info "Rollback success" "\"revision\":$prev_revision"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BUILD & DEPLOY (per component)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
deploy_component() {
  local component="$1" path="$2" type="$3" sha="$4"
  local job_file="$JOBS_DIR/$component"
  
  log_info "=== DEPLOY START ===" "\"component\":\"$component\",\"type\":\"$type\",\"sha\":\"${sha:0:12}\",\"path\":\"$path\""
  
  cd "$WORKDIR"
  
  #── VERIFY PATH EXISTS ─────────────────────────────────────────────────────
  if [[ ! -d "$path" ]]; then
    log_error "Component path does not exist" "\"component\":\"$component\",\"path\":\"$path\""
    echo "failure:path_not_found" > "$job_file"
    return 1
  fi
  
  #── COPY COMMON FOR PYTHON ─────────────────────────────────────────────────
  if [[ "$type" == "python" ]]; then
    if [[ -d "$PYTHON_PATH/common" ]]; then
      log_info "Copying common module" "\"component\":\"$component\""
      cp -r "$PYTHON_PATH/common" "$path/common"
    else
      log_warn "Common module not found" "\"expected\":\"$PYTHON_PATH/common\""
    fi
  fi
  
  #── VERIFY BUILDCONFIG EXISTS ──────────────────────────────────────────────
  log_info "Checking BuildConfig" "\"component\":\"$component\""
  local bc_check
  bc_check=$(oc get bc "$component" -o name 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "BuildConfig not found" "\"component\":\"$component\",\"error\":\"$(json_escape "$bc_check")\""
    [[ -d "$path/common" ]] && rm -rf "$path/common"
    echo "failure:no_buildconfig" > "$job_file"
    return 1
  fi
  log_info "BuildConfig exists" "\"component\":\"$component\""
  
  #── BUILD ──────────────────────────────────────────────────────────────────
  log_info "Starting build" "\"component\":\"$component\",\"from_dir\":\"$path\""
  local build_start=$(date +%s)
  local build_output
  build_output=$(oc start-build "$component" --from-dir="$path" --follow --wait 2>&1)
  local build_status=$?
  local build_duration=$(($(date +%s) - build_start))
  
  # Cleanup common
  [[ -d "$path/common" ]] && rm -rf "$path/common"
  
  if [[ $build_status -ne 0 ]]; then
    log_error "Build failed" "\"component\":\"$component\",\"duration\":$build_duration,\"exit_code\":$build_status,\"output\":\"$(json_escape "${build_output:0:1000}")\""
    echo "failure:build:$(json_escape "${build_output:0:200}")" > "$job_file"
    return 1
  fi
  
  log_info "Build success" "\"component\":\"$component\",\"duration\":$build_duration"
  
  #── GET IMAGE REF ──────────────────────────────────────────────────────────
  local image_ref
  image_ref=$(oc get bc "$component" -o jsonpath='{.spec.output.to.name}' 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "Failed to get image ref" "\"component\":\"$component\",\"error\":\"$(json_escape "$image_ref")\""
    echo "failure:image_ref" > "$job_file"
    return 1
  fi
  image_ref="image-registry.openshift-image-registry.svc:5000/$HELM_NAMESPACE/$image_ref"
  log_info "Image built" "\"component\":\"$component\",\"image\":\"$image_ref\""
  
  #── IMAGE SCAN ─────────────────────────────────────────────────────────────
  if [[ "$IMAGE_SCAN_ENABLED" == "true" ]]; then
    log_info "Starting image scan" "\"component\":\"$component\",\"image\":\"$image_ref\""
    
    local scan_output
    scan_output=$(trivy image --severity CRITICAL --exit-code 1 --quiet "$image_ref" 2>&1)
    local scan_status=$?
    
    if [[ $scan_status -ne 0 ]]; then
      log_warn "Image scan found issues" "\"component\":\"$component\",\"output\":\"$(json_escape "${scan_output:0:500}")\""
      
      if [[ "$IMAGE_SCAN_FAIL_CRITICAL" == "true" ]]; then
        log_error "Failing due to critical vulnerabilities" "\"component\":\"$component\""
        echo "failure:scan:critical_vulnerabilities" > "$job_file"
        return 1
      fi
    else
      log_info "Image scan passed" "\"component\":\"$component\""
    fi
  else
    log_debug "Image scan disabled"
  fi
  
  #── HELM DEPLOY ────────────────────────────────────────────────────────────
  log_info "Starting helm upgrade" "\"component\":\"$component\",\"release\":\"$HELM_RELEASE\""
  
  local helm_output
  helm_output=$(helm upgrade "$HELM_RELEASE" "$WORKDIR/$HELM_CHART_PATH" \
    --namespace "$HELM_NAMESPACE" \
    --reuse-values \
    --set "$component.image.tag=$sha" \
    --wait --timeout 120s 2>&1)
  local helm_status=$?
  
  if [[ $helm_status -ne 0 ]]; then
    log_error "Helm upgrade failed" "\"component\":\"$component\",\"exit_code\":$helm_status,\"output\":\"$(json_escape "${helm_output:0:500}")\""
    echo "failure:helm:$(json_escape "${helm_output:0:200}")" > "$job_file"
    return 1
  fi
  
  log_info "Helm upgrade success" "\"component\":\"$component\""
  
  #── SMOKE TEST ─────────────────────────────────────────────────────────────
  local health_path="/health"
  [[ "$type" == "java" ]] && health_path="/actuator/health"
  local health_url="http://$component:8080$health_path"
  
  log_info "Starting smoke test" "\"component\":\"$component\",\"url\":\"$health_url\""
  
  local smoke_ok=0
  for i in {1..5}; do
    log_debug "Smoke test attempt $i/5" "\"component\":\"$component\""
    local curl_output
    curl_output=$(curl -sf "$health_url" 2>&1)
    if [[ $? -eq 0 ]]; then
      smoke_ok=1
      break
    fi
    log_debug "Smoke test attempt failed" "\"component\":\"$component\",\"attempt\":$i,\"error\":\"$(json_escape "$curl_output")\""
    sleep 3
  done
  
  if [[ $smoke_ok -eq 0 ]]; then
    log_error "Smoke test failed after 5 attempts" "\"component\":\"$component\",\"url\":\"$health_url\""
    echo "failure:smoke:health_check_failed" > "$job_file"
    return 1
  fi
  
  log_info "Smoke test passed" "\"component\":\"$component\""
  
  #── SUCCESS ────────────────────────────────────────────────────────────────
  log_info "=== DEPLOY SUCCESS ===" "\"component\":\"$component\",\"sha\":\"${sha:0:12}\""
  echo "success" > "$job_file"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DETECT & DISPATCH
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
process_commit() {
  local sha="$1"
  
  log_info "Processing commit" "\"sha\":\"${sha:0:12}\""
  
  local files
  files=$(get_changed_files "$sha")
  
  if [[ -z "$files" ]]; then
    log_info "No files in commit"
    update_github_status "$sha" "success" "deploy/cd" "No files changed"
    mark_sha_processed "$sha"
    return 0
  fi
  
  log_info "Changed files" "\"files\":\"$(echo "$files" | tr '\n' ',' | sed 's/,$//')\""
  
  # Clear previous job results
  rm -f "$JOBS_DIR"/*
  
  local components=""
  local pids=()
  
  #── DETECT JAVA ────────────────────────────────────────────────────────────
  for svc in $JAVA_SERVICES; do
    if echo "$files" | grep -q "^$JAVA_PATH/$svc/"; then
      log_info "Detected Java service change" "\"component\":\"$svc\",\"path\":\"$JAVA_PATH/$svc\""
      components="$components $svc"
      deploy_component "$svc" "$JAVA_PATH/$svc" "java" "$sha" &
      pids+=($!)
    fi
  done
  
  #── DETECT PYTHON ──────────────────────────────────────────────────────────
  local python_triggered=""
  if echo "$files" | grep -q "^$PYTHON_PATH/common/"; then
    python_triggered="$PYTHON_WORKERS"
    log_info "Common module changed - triggering all workers" "\"workers\":\"$PYTHON_WORKERS\""
  else
    for wrk in $PYTHON_WORKERS; do
      if echo "$files" | grep -q "^$PYTHON_PATH/$wrk/"; then
        python_triggered="$python_triggered $wrk"
      fi
    done
  fi
  
  for wrk in $python_triggered; do
    log_info "Detected Python worker change" "\"component\":\"$wrk\",\"path\":\"$PYTHON_PATH/$wrk\""
    components="$components $wrk"
    deploy_component "$wrk" "$PYTHON_PATH/$wrk" "python" "$sha" &
    pids+=($!)
  done
  
  #── NO COMPONENTS ──────────────────────────────────────────────────────────
  if [[ ${#pids[@]} -eq 0 ]]; then
    log_info "No deployable components changed"
    update_github_status "$sha" "success" "deploy/cd" "No components to deploy"
    mark_sha_processed "$sha"
    return 0
  fi
  
  #── WAIT FOR JOBS ──────────────────────────────────────────────────────────
  components=$(echo "$components" | xargs)
  log_info "Waiting for ${#pids[@]} deploy jobs" "\"components\":\"$components\""
  
  local failed=0
  for pid in "${pids[@]}"; do
    wait "$pid" || ((failed++))
  done
  
  #── COLLECT RESULTS ────────────────────────────────────────────────────────
  local success_list="" fail_list="" fail_reasons=""
  for f in "$JOBS_DIR"/*; do
    [[ ! -f "$f" ]] && continue
    local comp=$(basename "$f")
    local result=$(cat "$f")
    if [[ "$result" == "success" ]]; then
      success_list="$success_list $comp"
    else
      fail_list="$fail_list $comp"
      fail_reasons="$fail_reasons [$comp: $result]"
    fi
  done
  
  success_list=$(echo "$success_list" | xargs)
  fail_list=$(echo "$fail_list" | xargs)
  fail_reasons=$(echo "$fail_reasons" | xargs)
  
  #── FINAL STATUS ───────────────────────────────────────────────────────────
  if [[ $failed -eq 0 ]]; then
    log_info "All deployments succeeded" "\"components\":\"$components\",\"success\":\"$success_list\""
    update_github_status "$sha" "success" "deploy/cd" "Deployed: $success_list"
    notify_slack "success" "Deployed: $success_list" "$components"
  else
    log_error "Deployments failed" "\"failed\":\"$fail_list\",\"succeeded\":\"$success_list\",\"reasons\":\"$fail_reasons\""
    update_github_status "$sha" "failure" "deploy/cd" "Failed: $fail_list"
    notify_slack "failure" "Failed: $fail_list ($fail_reasons)" "$components"
    
    # Rollback
    helm_rollback
  fi
  
  mark_sha_processed "$sha"
  return $failed
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN LOOP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
  log_info "============================================"
  log_info "GitOps Controller v4 Starting"
  log_info "============================================"
  log_info "Configuration" "\"repo\":\"$GITHUB_OWNER/$GITHUB_REPO_NAME\",\"poll_interval\":\"$POLL_INTERVAL\",\"namespace\":\"$HELM_NAMESPACE\",\"release\":\"$HELM_RELEASE\""
  log_info "Java services" "\"path\":\"$JAVA_PATH\",\"services\":\"$JAVA_SERVICES\""
  log_info "Python workers" "\"path\":\"$PYTHON_PATH\",\"workers\":\"$PYTHON_WORKERS\""
  log_info "Image scan" "\"enabled\":\"$IMAGE_SCAN_ENABLED\",\"fail_on_critical\":\"$IMAGE_SCAN_FAIL_CRITICAL\""
  
  setup_all_cli || { 
    log_error "CLI setup failed - exiting"
    exit 1
  }
  
  log_info "Entering main loop"
  
  while true; do
    local sha
    sha=$(get_pending_deploy)
    
    if [[ -n "$sha" ]]; then
      log_info "========== PROCESSING SHA ==========" "\"sha\":\"${sha:0:12}\""
      update_github_status "$sha" "pending" "deploy/cd" "CD controller processing..."
      
      if clone_repo "$sha"; then
        process_commit "$sha"
      else
        log_error "Clone failed - marking as failure" "\"sha\":\"${sha:0:12}\""
        update_github_status "$sha" "failure" "deploy/cd" "Clone failed"
        mark_sha_processed "$sha"
      fi
      
      log_info "========== DONE ==========" "\"sha\":\"${sha:0:12}\""
    fi
    
    sleep "$POLL_INTERVAL"
  done
}

main