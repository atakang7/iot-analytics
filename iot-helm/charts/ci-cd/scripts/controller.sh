#!/bin/bash
# GitOps Controller v5 - Full observability, fixed stdout/stderr
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
# LOGGING - all to stderr so stdout stays clean for return values
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log() {
  local level="$1" msg="$2" extra="${3:-}"
  local ts=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
  if [[ -n "$extra" ]]; then
    echo "{\"timestamp\":\"$ts\",\"level\":\"$level\",\"service\":\"$SERVICE\",\"message\":\"$msg\",$extra}" >&2
  else
    echo "{\"timestamp\":\"$ts\",\"level\":\"$level\",\"service\":\"$SERVICE\",\"message\":\"$msg\"}" >&2
  fi
}

log_info() { log "info" "$1" "$2"; }
log_warn() { log "warn" "$1" "$2"; }
log_error() { log "error" "$1" "$2"; }
log_debug() { log "debug" "$1" "$2"; }

json_escape() {
  local str="$1"
  str="${str//\\/\\\\}"
  str="${str//\"/\\\"}"
  str="${str//$'\n'/\\n}"
  str="${str//$'\r'/}"
  echo "$str"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STATE MANAGEMENT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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
# GITHUB STATUS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
update_github_status() {
  local sha="$1" state="$2" context="$3" description="$4"
  
  log_info "Updating GitHub status" "\"sha\":\"${sha:0:12}\",\"state\":\"$state\",\"context\":\"$context\",\"description\":\"$description\""
  
  if [[ -z "$GIT_TOKEN" ]]; then
    log_warn "No GIT_TOKEN, skipping status update"
    return 0
  fi
  
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/statuses/$sha" \
    -d "{\"state\":\"$state\",\"context\":\"$context\",\"description\":\"$description\"}")
  
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "201" ]]; then
    log_error "Failed to update GitHub status" "\"http_code\":\"$http_code\",\"response\":\"$(json_escape "$body")\""
    return 1
  fi
  
  log_info "GitHub status updated successfully"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# NOTIFICATIONS
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
notify_slack() {
  local status="$1" message="$2" components="${3:-}"
  
  if [[ -z "$SLACK_WEBHOOK" ]] || [[ "$SLACK_WEBHOOK" == "https://hooks.slack.com/xxx" ]]; then
    log_debug "No SLACK_WEBHOOK configured"
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

  local response http_code
  response=$(curl -s -w "\n%{http_code}" -X POST -H 'Content-type: application/json' --data "$payload" "$SLACK_WEBHOOK")
  http_code=$(echo "$response" | tail -1)
  
  if [[ "$http_code" != "200" ]]; then
    log_warn "Slack notification failed" "\"http_code\":\"$http_code\""
  else
    log_info "Slack notification sent"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLI SETUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_cli() {
  local tool="$1" check_cmd="$2" install_cmd="$3"
  
  if eval "$check_cmd" >/dev/null 2>&1; then
    log_info "$tool already available"
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
  
  log_info "$tool installed"
  return 0
}

setup_all_cli() {
  log_info "Setting up CLI tools"
  
  setup_cli "oc" "command -v oc" \
    "curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz | tar -xz -C $BIN_DIR oc" || return 1
  
  setup_cli "helm" "command -v helm" \
    "curl -sL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar -xz -C /tmp && mv /tmp/linux-amd64/helm $BIN_DIR/" || return 1
  
  if [[ "$IMAGE_SCAN_ENABLED" == "true" ]]; then
    setup_cli "trivy" "command -v trivy" \
      "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $BIN_DIR" || return 1
  fi
  
  setup_cli "jq" "command -v jq" \
    "curl -sL https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 -o $BIN_DIR/jq && chmod +x $BIN_DIR/jq" || return 1
  
  log_info "All CLI tools ready"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GITHUB API - returns via stdout, logs via stderr
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
get_pending_deploy() {
  # Returns SHA to stdout, all logs go to stderr
  local response http_code body
  
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits?per_page=10" 2>/dev/null)
  
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "200" ]]; then
    return 1
  fi
  
  local sha
  for sha in $(echo "$body" | jq -r '.[].sha' 2>/dev/null); do
    [[ -z "$sha" ]] && continue
    
    # Skip already processed
    if is_sha_processed "$sha"; then
      continue
    fi
    
    local status_response pending
    status_response=$(curl -s -H "Authorization: token $GIT_TOKEN" \
      "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits/$sha/status" 2>/dev/null)
    
    pending=$(echo "$status_response" | jq -r '.statuses[] | select(.context == "deploy/cd" and .state == "pending") | .state' 2>/dev/null)
    
    if [[ "$pending" == "pending" ]]; then
      echo "$sha"
      return 0
    fi
  done
  
  return 1
}

get_changed_files() {
  local sha="$1"
  # Returns files to stdout, logs via stderr
  
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits/$sha" 2>/dev/null)
  
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  if [[ "$http_code" != "200" ]]; then
    return 1
  fi
  
  echo "$body" | jq -r '.files[].filename // empty' 2>/dev/null
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GIT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
clone_repo() {
  local sha="$1"
  local url="$GIT_REPO"
  [[ -n "$GIT_TOKEN" ]] && url="${url/https:\/\//https://${GIT_TOKEN}@}"
  
  log_info "Cloning repo" "\"sha\":\"${sha:0:12}\""
  
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  cd "$WORKDIR" || return 1
  
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
  
  log_info "Clone successful" "\"sha\":\"${sha:0:12}\""
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELM
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
helm_rollback() {
  log_info "Attempting helm rollback" "\"release\":\"$HELM_RELEASE\""
  
  local history_output
  history_output=$(helm history "$HELM_RELEASE" -n "$HELM_NAMESPACE" -o json 2>&1)
  
  if [[ $? -ne 0 ]]; then
    log_warn "No helm history found, skipping rollback" "\"output\":\"$(json_escape "$history_output")\""
    return 1
  fi
  
  local current_revision
  current_revision=$(echo "$history_output" | jq -r '.[-1].revision' 2>/dev/null)
  
  if [[ -z "$current_revision" ]] || [[ "$current_revision" == "null" ]] || [[ "$current_revision" -le 1 ]]; then
    log_warn "No previous revision to rollback to" "\"current_revision\":\"$current_revision\""
    return 1
  fi
  
  local prev_revision=$((current_revision - 1))
  log_info "Rolling back" "\"from\":$current_revision,\"to\":$prev_revision"
  
  local rollback_output
  rollback_output=$(helm rollback "$HELM_RELEASE" "$prev_revision" -n "$HELM_NAMESPACE" --wait --timeout 120s 2>&1)
  
  if [[ $? -ne 0 ]]; then
    log_error "Rollback failed" "\"error\":\"$(json_escape "$rollback_output")\""
    return 1
  fi
  
  log_info "Rollback successful" "\"revision\":$prev_revision"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPLOY COMPONENT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
deploy_component() {
  local component="$1" path="$2" type="$3" sha="$4"
  local job_file="$JOBS_DIR/$component"
  
  log_info ">>> DEPLOY START" "\"component\":\"$component\",\"type\":\"$type\",\"sha\":\"${sha:0:12}\",\"path\":\"$path\""
  
  cd "$WORKDIR" || { echo "failure:cd_failed" > "$job_file"; return 1; }
  
  #── VERIFY PATH ────────────────────────────────────────────────────────────
  if [[ ! -d "$path" ]]; then
    log_error "Path not found" "\"component\":\"$component\",\"path\":\"$path\""
    echo "failure:path_not_found:$path" > "$job_file"
    return 1
  fi
  log_info "Path verified" "\"component\":\"$component\""
  
  #── COPY COMMON FOR PYTHON ─────────────────────────────────────────────────
  if [[ "$type" == "python" ]]; then
    if [[ -d "$PYTHON_PATH/common" ]]; then
      log_info "Copying common module" "\"component\":\"$component\""
      cp -r "$PYTHON_PATH/common" "$path/common"
    else
      log_warn "Common module not found" "\"component\":\"$component\",\"expected\":\"$PYTHON_PATH/common\""
    fi
  fi
  
  #── VERIFY BUILDCONFIG ─────────────────────────────────────────────────────
  log_info "Checking BuildConfig" "\"component\":\"$component\""
  local bc_output
  bc_output=$(oc get bc "$component" -n "$HELM_NAMESPACE" -o name 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "BuildConfig not found" "\"component\":\"$component\",\"error\":\"$(json_escape "$bc_output")\""
    [[ -d "$path/common" ]] && rm -rf "$path/common"
    echo "failure:no_buildconfig" > "$job_file"
    return 1
  fi
  log_info "BuildConfig exists" "\"component\":\"$component\""
  
  #── BUILD ──────────────────────────────────────────────────────────────────
  log_info "Starting build" "\"component\":\"$component\""
  local build_start=$(date +%s)
  local build_output
  build_output=$(oc start-build "$component" -n "$HELM_NAMESPACE" --from-dir="$path" --follow --wait 2>&1)
  local build_status=$?
  local build_duration=$(($(date +%s) - build_start))
  
  # Cleanup common
  [[ -d "$path/common" ]] && rm -rf "$path/common"
  
  if [[ $build_status -ne 0 ]]; then
    log_error "Build failed" "\"component\":\"$component\",\"duration\":$build_duration,\"exit_code\":$build_status"
    log_error "Build output" "\"output\":\"$(json_escape "${build_output:0:1000}")\""
    echo "failure:build:exit_code_$build_status" > "$job_file"
    return 1
  fi
  log_info "Build successful" "\"component\":\"$component\",\"duration\":\"${build_duration}s\""
  
  #── GET IMAGE REF ──────────────────────────────────────────────────────────
  local image_ref
  image_ref=$(oc get bc "$component" -n "$HELM_NAMESPACE" -o jsonpath='{.spec.output.to.name}' 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "Failed to get image ref" "\"component\":\"$component\",\"error\":\"$(json_escape "$image_ref")\""
    echo "failure:image_ref" > "$job_file"
    return 1
  fi
  image_ref="image-registry.openshift-image-registry.svc:5000/$HELM_NAMESPACE/$image_ref"
  log_info "Image built" "\"component\":\"$component\",\"image\":\"$image_ref\""
  
  #── IMAGE SCAN ─────────────────────────────────────────────────────────────
  if [[ "$IMAGE_SCAN_ENABLED" == "true" ]]; then
    log_info "Scanning image" "\"component\":\"$component\""
    
    local scan_output
    scan_output=$(trivy image --severity CRITICAL --exit-code 1 --quiet "$image_ref" 2>&1)
    local scan_status=$?
    
    if [[ $scan_status -ne 0 ]]; then
      log_warn "Scan found issues" "\"component\":\"$component\",\"output\":\"$(json_escape "${scan_output:0:500}")\""
      if [[ "$IMAGE_SCAN_FAIL_CRITICAL" == "true" ]]; then
        log_error "Failing due to critical vulnerabilities"
        echo "failure:scan:critical_vulnerabilities" > "$job_file"
        return 1
      fi
    else
      log_info "Scan passed" "\"component\":\"$component\""
    fi
  fi
  
  #── HELM UPGRADE ───────────────────────────────────────────────────────────
  log_info "Helm upgrade" "\"component\":\"$component\",\"release\":\"$HELM_RELEASE\""
  
  local helm_output
  helm_output=$(helm upgrade "$HELM_RELEASE" "$WORKDIR/$HELM_CHART_PATH" \
    --namespace "$HELM_NAMESPACE" \
    --reuse-values \
    --set "$component.image.tag=$sha" \
    --wait --timeout 120s 2>&1)
  local helm_status=$?
  
  if [[ $helm_status -ne 0 ]]; then
    log_error "Helm upgrade failed" "\"component\":\"$component\",\"exit_code\":$helm_status"
    log_error "Helm output" "\"output\":\"$(json_escape "${helm_output:0:500}")\""
    echo "failure:helm:exit_code_$helm_status" > "$job_file"
    return 1
  fi
  log_info "Helm upgrade successful" "\"component\":\"$component\""
  
  #── SMOKE TEST ─────────────────────────────────────────────────────────────
  local health_path="/health"
  [[ "$type" == "java" ]] && health_path="/actuator/health"
  local health_url="http://$component:8080$health_path"
  
  log_info "Smoke test" "\"component\":\"$component\",\"url\":\"$health_url\""
  
  local smoke_ok=0
  for i in {1..5}; do
    if curl -sf "$health_url" >/dev/null 2>&1; then
      smoke_ok=1
      break
    fi
    log_debug "Smoke attempt $i failed, retrying..."
    sleep 3
  done
  
  if [[ $smoke_ok -eq 0 ]]; then
    log_error "Smoke test failed" "\"component\":\"$component\",\"url\":\"$health_url\""
    echo "failure:smoke:health_check_failed" > "$job_file"
    return 1
  fi
  log_info "Smoke test passed" "\"component\":\"$component\""
  
  #── SUCCESS ────────────────────────────────────────────────────────────────
  log_info ">>> DEPLOY SUCCESS" "\"component\":\"$component\",\"sha\":\"${sha:0:12}\""
  echo "success" > "$job_file"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROCESS COMMIT
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
  
  local file_count=$(echo "$files" | wc -l)
  log_info "Found changed files" "\"count\":$file_count"
  log_debug "Files" "\"files\":\"$(echo "$files" | tr '\n' ',' | sed 's/,$//')\""
  
  # Clear previous jobs
  rm -f "$JOBS_DIR"/*
  
  local components=""
  local pids=()
  
  #── DETECT JAVA ────────────────────────────────────────────────────────────
  for svc in $JAVA_SERVICES; do
    if echo "$files" | grep -q "^$JAVA_PATH/$svc/"; then
      log_info "Detected Java change" "\"component\":\"$svc\""
      components="$components $svc"
      deploy_component "$svc" "$JAVA_PATH/$svc" "java" "$sha" &
      pids+=($!)
    fi
  done
  
  #── DETECT PYTHON ──────────────────────────────────────────────────────────
  local python_triggered=""
  if echo "$files" | grep -q "^$PYTHON_PATH/common/"; then
    python_triggered="$PYTHON_WORKERS"
    log_info "Common changed - triggering all workers"
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
  
  #── NO COMPONENTS ──────────────────────────────────────────────────────────
  if [[ ${#pids[@]} -eq 0 ]]; then
    log_info "No deployable components in this commit"
    update_github_status "$sha" "success" "deploy/cd" "No components to deploy"
    mark_sha_processed "$sha"
    return 0
  fi
  
  #── WAIT FOR JOBS ──────────────────────────────────────────────────────────
  components=$(echo "$components" | xargs)
  log_info "Waiting for jobs" "\"count\":${#pids[@]},\"components\":\"$components\""
  
  local failed=0
  for pid in "${pids[@]}"; do
    wait "$pid" || ((failed++))
  done
  
  #── COLLECT RESULTS ────────────────────────────────────────────────────────
  local success_list="" fail_list="" fail_details=""
  for f in "$JOBS_DIR"/*; do
    [[ ! -f "$f" ]] && continue
    local comp=$(basename "$f")
    local result=$(cat "$f")
    if [[ "$result" == "success" ]]; then
      success_list="$success_list $comp"
    else
      fail_list="$fail_list $comp"
      fail_details="$fail_details [$comp:$result]"
    fi
  done
  
  success_list=$(echo "$success_list" | xargs)
  fail_list=$(echo "$fail_list" | xargs)
  fail_details=$(echo "$fail_details" | xargs)
  
  #── FINAL STATUS ───────────────────────────────────────────────────────────
  if [[ $failed -eq 0 ]]; then
    log_info "All deployments successful" "\"components\":\"$success_list\""
    update_github_status "$sha" "success" "deploy/cd" "Deployed: $success_list"
    notify_slack "success" "Deployed: $success_list" "$components"
  else
    log_error "Some deployments failed" "\"failed\":\"$fail_list\",\"success\":\"$success_list\",\"details\":\"$fail_details\""
    update_github_status "$sha" "failure" "deploy/cd" "Failed: $fail_list"
    notify_slack "failure" "Failed: $fail_list ($fail_details)" "$components"
    helm_rollback
  fi
  
  mark_sha_processed "$sha"
  return $failed
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
main() {
  log_info "============================================"
  log_info "GitOps Controller v5"
  log_info "============================================"
  log_info "Config" "\"repo\":\"$GITHUB_OWNER/$GITHUB_REPO_NAME\",\"poll\":\"$POLL_INTERVAL\",\"namespace\":\"$HELM_NAMESPACE\",\"release\":\"$HELM_RELEASE\""
  log_info "Java" "\"path\":\"$JAVA_PATH\",\"services\":\"$JAVA_SERVICES\""
  log_info "Python" "\"path\":\"$PYTHON_PATH\",\"workers\":\"$PYTHON_WORKERS\""
  log_info "Scan" "\"enabled\":\"$IMAGE_SCAN_ENABLED\",\"fail_critical\":\"$IMAGE_SCAN_FAIL_CRITICAL\""
  
  setup_all_cli || { log_error "CLI setup failed"; exit 1; }
  
  log_info "Entering main loop"
  
  while true; do
    local sha
    sha=$(get_pending_deploy)
    
    if [[ -n "$sha" ]]; then
      log_info "========== NEW DEPLOY ==========" "\"sha\":\"${sha:0:12}\""
      update_github_status "$sha" "pending" "deploy/cd" "CD processing..."
      
      if clone_repo "$sha"; then
        process_commit "$sha"
      else
        log_error "Clone failed" "\"sha\":\"${sha:0:12}\""
        update_github_status "$sha" "failure" "deploy/cd" "Clone failed"
        mark_sha_processed "$sha"
      fi
      
      log_info "========== DONE ==========" "\"sha\":\"${sha:0:12}\""
    fi
    
    sleep "$POLL_INTERVAL"
  done
}

main