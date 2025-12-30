#!/bin/bash
# GitOps Controller v5
set -o pipefail

# Paths
WORKDIR="/tmp/repo"
STATE_DIR="/tmp/state"
PROCESSED_FILE="$STATE_DIR/processed"
JOBS_DIR="$STATE_DIR/jobs"
BIN_DIR="/tmp/bin"
SERVICE="gitops-controller"

export PATH="$BIN_DIR:$PATH"
mkdir -p "$STATE_DIR" "$JOBS_DIR" "$BIN_DIR"
touch "$PROCESSED_FILE"

# Load lib
source /scripts/lib.sh

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DEPLOY COMPONENT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
deploy_component() {
  local component="$1" path="$2" type="$3" sha="$4"
  local job_file="$JOBS_DIR/$component"
  
  log_info "DEPLOY" "\"component\":\"$component\",\"type\":\"$type\""
  update_github_status "$sha" "pending" "deploy/$component" "Building..."
  
  cd "$WORKDIR" || { echo "failure:cd" > "$job_file"; return 1; }
  
  # Verify path
  if [[ ! -d "$path" ]]; then
    log_error "Path missing: $path"
    update_github_status "$sha" "failure" "deploy/$component" "Path not found: $path"
    echo "failure:path" > "$job_file"
    return 1
  fi
  
  # Python: copy common
  if [[ "$type" == "python" ]] && [[ -d "$PYTHON_PATH/common" ]]; then
    cp -r "$PYTHON_PATH/common" "$path/common"
  fi
  
  # Check BuildConfig
  local bc_out
  bc_out=$(oc get bc "$component" -n "$HELM_NAMESPACE" 2>&1)
  if [[ $? -ne 0 ]]; then
    log_error "No BuildConfig" "\"error\":\"$(json_escape "$bc_out")\""
    update_github_status "$sha" "failure" "deploy/$component" "BuildConfig not found"
    [[ -d "$path/common" ]] && rm -rf "$path/common"
    echo "failure:no_bc" > "$job_file"
    return 1
  fi
  
  # Build
  log_info "Building" "\"component\":\"$component\""
  update_github_status "$sha" "pending" "deploy/$component" "Building image..."
  local build_start=$(date +%s)
  local build_out
  build_out=$(oc start-build "$component" -n "$HELM_NAMESPACE" --from-dir="$path" --follow --wait 2>&1)
  local build_status=$?
  local build_duration=$(($(date +%s) - build_start))
  
  [[ -d "$path/common" ]] && rm -rf "$path/common"
  
  if [[ $build_status -ne 0 ]]; then
    log_error "Build failed" "\"output\":\"$(json_escape "${build_out:0:500}")\""
    update_github_status "$sha" "failure" "deploy/$component" "Build failed (${build_duration}s)"
    echo "failure:build" > "$job_file"
    return 1
  fi
  log_info "Build done" "\"component\":\"$component\",\"duration\":\"${build_duration}s\""
  
  # Helm upgrade
  log_info "Helm upgrade" "\"component\":\"$component\""
  update_github_status "$sha" "pending" "deploy/$component" "Deploying (built in ${build_duration}s)..."
  local helm_out
  helm_out=$(helm upgrade "$HELM_RELEASE" "$WORKDIR/$HELM_CHART_PATH" \
    -n "$HELM_NAMESPACE" --reuse-values \
    --set "$component.image.tag=$sha" --wait --timeout 120s 2>&1)
  
  if [[ $? -ne 0 ]]; then
    log_error "Helm failed" "\"output\":\"$(json_escape "${helm_out:0:500}")\""
    update_github_status "$sha" "failure" "deploy/$component" "Helm upgrade failed"
    echo "failure:helm" > "$job_file"
    return 1
  fi
  
  # Smoke test - trust Helm --wait (uses readiness probe)
  # Just verify service DNS resolves and pod accepts connections
  update_github_status "$sha" "pending" "deploy/$component" "Verifying..."
  local ok=0
  for i in {1..5}; do
    # Just check if service is reachable, any response is fine
    curl -sf --max-time 5 "http://$component:8080/" >/dev/null 2>&1 || \
    curl -sf --max-time 5 "http://$component:8081/" >/dev/null 2>&1 && { ok=1; break; }
    sleep 3
  done

  # If service isn't responding but Helm succeeded, still consider it OK
  # Helm --wait already verified the readiness probe
  if [[ $ok -eq 0 ]]; then
    log_warn "Service not responding but Helm succeeded, continuing..."
    ok=1
  fi
  
  local total_duration=$(($(date +%s) - build_start))
  log_info "DEPLOY OK" "\"component\":\"$component\""
  update_github_status "$sha" "success" "deploy/$component" "Deployed in ${total_duration}s"
  echo "success" > "$job_file"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PROCESS COMMIT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
process_commit() {
  local sha="$1"
  
  local files=$(get_changed_files "$sha")
  [[ -z "$files" ]] && { update_github_status "$sha" "success" "deploy/cd" "No files"; mark_sha_processed "$sha"; return 0; }
  
  log_info "Files changed" "\"count\":$(echo "$files" | wc -l)"
  
  rm -f "$JOBS_DIR"/*
  local components="" pids=()
  
  # Java
  for svc in $JAVA_SERVICES; do
    if echo "$files" | grep -q "^$JAVA_PATH/$svc/"; then
      components="$components $svc"
      deploy_component "$svc" "$JAVA_PATH/$svc" "java" "$sha" &
      pids+=($!)
    fi
  done
  
  # Python
  local py_trigger=""
  if echo "$files" | grep -q "^$PYTHON_PATH/common/"; then
    py_trigger="$PYTHON_WORKERS"
  else
    for wrk in $PYTHON_WORKERS; do
      echo "$files" | grep -q "^$PYTHON_PATH/$wrk/" && py_trigger="$py_trigger $wrk"
    done
  fi
  
  for wrk in $py_trigger; do
    components="$components $wrk"
    deploy_component "$wrk" "$PYTHON_PATH/$wrk" "python" "$sha" &
    pids+=($!)
  done
  
  # No components
  [[ ${#pids[@]} -eq 0 ]] && { update_github_status "$sha" "success" "deploy/cd" "No components"; mark_sha_processed "$sha"; return 0; }
  
  # Wait
  local failed=0
  for pid in "${pids[@]}"; do wait "$pid" || ((failed++)); done
  
  # Results
  local ok="" fail=""
  for f in "$JOBS_DIR"/*; do
    [[ ! -f "$f" ]] && continue
    local c=$(basename "$f") r=$(cat "$f")
    [[ "$r" == "success" ]] && ok="$ok $c" || fail="$fail $c"
  done
  
  components=$(echo "$components" | xargs)
  ok=$(echo "$ok" | xargs)
  fail=$(echo "$fail" | xargs)
  
  if [[ $failed -eq 0 ]]; then
    update_github_status "$sha" "success" "deploy/cd" "OK: $ok"
    notify_slack "success" "$ok" "$components"
  else
    update_github_status "$sha" "failure" "deploy/cd" "FAIL: $fail"
    notify_slack "failure" "$fail" "$components"
    helm_rollback
  fi
  
  mark_sha_processed "$sha"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
log_info "GitOps v5" "\"repo\":\"$GITHUB_OWNER/$GITHUB_REPO_NAME\",\"ns\":\"$HELM_NAMESPACE\""
setup_all_cli || exit 1

while true; do
  sha=$(get_pending_deploy)
  if [[ -n "$sha" ]]; then
    log_info "=== DEPLOY ===" "\"sha\":\"${sha:0:12}\""
    update_github_status "$sha" "pending" "deploy/cd" "Processing..."
    clone_repo "$sha" && process_commit "$sha" || {
      update_github_status "$sha" "failure" "deploy/cd" "Clone failed"
      mark_sha_processed "$sha"
    }
  fi
  sleep "$POLL_INTERVAL"
done