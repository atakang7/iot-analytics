#!/bin/bash
# GitOps Controller - watches repo, builds & deploys on change
set -o pipefail

WORKDIR="/tmp/repo"
STATE="/tmp/last_commit"
OC="/tmp/oc"
SERVICE="gitops-controller"

# JSON log output for Loki
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

setup_oc() {
  [[ -f "$OC" ]] && return 0
  log_info "Downloading oc CLI"
  if curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz 2>/dev/null | tar -xz -C /tmp oc 2>/dev/null; then
    chmod +x "$OC"
    log_info "oc CLI ready"
    return 0
  fi
  log_error "Failed to download oc CLI"
  return 1
}

get_remote_commit() {
  local url="$GIT_REPO"
  [[ -n "$GIT_TOKEN" ]] && url="${url/https:\/\//https://${GIT_TOKEN}@}"
  git ls-remote "$url" "refs/heads/$GIT_BRANCH" 2>/dev/null | cut -c1-12
}

clone_or_pull() {
  local url="$GIT_REPO"
  [[ -n "$GIT_TOKEN" ]] && url="${url/https:\/\//https://${GIT_TOKEN}@}"
  
  if [[ -d "$WORKDIR/.git" ]]; then
    cd "$WORKDIR" && git fetch origin -q && git reset --hard "origin/$GIT_BRANCH" -q
  else
    rm -rf "$WORKDIR"
    git clone --branch "$GIT_BRANCH" --depth 50 -q "$url" "$WORKDIR" 2>/dev/null
  fi
}

test_java() {
  local component=$1 path=$2
  log_info "Running tests" "\"component\":\"$component\",\"type\":\"java\",\"phase\":\"test\""
  
  cd "$WORKDIR/$path"
  
  if [[ ! -f "pom.xml" ]]; then
    log_info "No pom.xml, skipping" "\"component\":\"$component\""
    return 0
  fi
  
  # Run maven tests in a pod
  local pod_name="test-java-$$"
  local result
  
  result=$(tar -cf - . | $OC run "$pod_name" --rm -i --restart=Never \
    --image=maven:3.9-eclipse-temurin-17 \
    -- sh -c 'cd /tmp && tar -xf - && mvn test -B -q 2>&1; echo "EXIT:$?"' 2>&1)
  
  local exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | tail -1 | cut -d: -f2)
  
  if [[ "$exit_code" == "0" ]]; then
    log_info "Tests passed" "\"component\":\"$component\",\"type\":\"java\",\"result\":\"success\""
    return 0
  else
    log_error "Tests failed" "\"component\":\"$component\",\"type\":\"java\",\"result\":\"failure\""
    echo "$result" | grep -iE "failure|error|\[ERROR\]" | head -5 | while read -r line; do
      log_error "  $line"
    done
    return 1
  fi
}

test_python() {
  local component=$1 path=$2
  log_info "Running tests" "\"component\":\"$component\",\"type\":\"python\",\"phase\":\"test\""
  
  cd "$WORKDIR"
  
  # Copy common if exists
  local build_path="$path"
  if [[ -d "${PYTHON_PATH}/common" ]]; then
    cp -r "${PYTHON_PATH}/common" "$path/common"
  fi
  
  cd "$WORKDIR/$path"
  
  # Run pytest in a pod
  local pod_name="test-py-$$"
  local result
  
  result=$(tar -cf - . | $OC run "$pod_name" --rm -i --restart=Never \
    --image=python:3.11-slim \
    -- sh -c '
      cd /tmp && tar -xf -
      pip install -q pytest 2>/dev/null
      [ -f requirements.txt ] && pip install -q -r requirements.txt 2>/dev/null
      python -m pytest -v --tb=line 2>&1
      echo "EXIT:$?"
    ' 2>&1)
  
  # Cleanup common
  [[ -d "$WORKDIR/$path/common" ]] && rm -rf "$WORKDIR/$path/common"
  
  local exit_code=$(echo "$result" | grep -o 'EXIT:[0-9]*' | tail -1 | cut -d: -f2)
  
  # 0 = passed, 5 = no tests found
  if [[ "$exit_code" == "0" ]] || [[ "$exit_code" == "5" ]]; then
    log_info "Tests passed" "\"component\":\"$component\",\"type\":\"python\",\"result\":\"success\""
    return 0
  else
    local failed=$(echo "$result" | grep -c "FAILED" || echo "0")
    log_error "Tests failed" "\"component\":\"$component\",\"type\":\"python\",\"result\":\"failure\",\"failed\":$failed"
    echo "$result" | grep -iE "FAILED|error|Error" | head -5 | while read -r line; do
      log_error "  $line"
    done
    return 1
  fi
}

build_deploy() {
  local component=$1 path=$2
  
  log_info "Build started" "\"component\":\"$component\",\"phase\":\"build\",\"status\":\"running\""
  cd "$WORKDIR"
  
  # For Python workers, copy common/ into build context
  if [[ "$path" == *"workers"* ]] && [[ -d "${PYTHON_PATH}/common" ]]; then
    log_info "Copying common/ to build context" "\"component\":\"$component\""
    cp -r "${PYTHON_PATH}/common" "$path/common"
  fi
  
  local start_time=$(date +%s)
  local output
  output=$($OC start-build "$component" --from-dir="$path" --follow --wait 2>&1)
  local build_status=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Cleanup copied common/
  [[ -d "$path/common" ]] && rm -rf "$path/common"
  
  if [[ $build_status -eq 0 ]]; then
    log_info "Build completed" "\"component\":\"$component\",\"phase\":\"build\",\"status\":\"success\",\"duration_seconds\":$duration"
    
    log_info "Deployment started" "\"component\":\"$component\",\"phase\":\"deploy\",\"status\":\"running\""
    $OC rollout restart "deployment/$component" >/dev/null 2>&1
    
    if $OC rollout status "deployment/$component" --timeout=120s >/dev/null 2>&1; then
      log_info "Deployment completed" "\"component\":\"$component\",\"phase\":\"deploy\",\"status\":\"success\""
    else
      log_warn "Deployment rollout timeout" "\"component\":\"$component\",\"phase\":\"deploy\",\"status\":\"timeout\""
    fi
    return 0
  else
    local error_msg=$(echo "$output" | grep -i "error\|failed" | head -1 | sed 's/"/\\"/g' | cut -c1-100)
    log_error "Build failed" "\"component\":\"$component\",\"phase\":\"build\",\"status\":\"failure\",\"duration_seconds\":$duration,\"error\":\"$error_msg\""
    return 1
  fi
}

process_changes() {
  local old=$1 new=$2
  [[ -z "$old" ]] && { log_info "First run, skipping build" "\"reason\":\"initial_state\""; return; }
  
  cd "$WORKDIR"
  local files=$(git diff --name-only "$old" "$new" 2>/dev/null)
  [[ -z "$files" ]] && return
  
  local file_count=$(echo "$files" | wc -l)
  local file_list=$(echo "$files" | tr '\n' ',' | sed 's/,$//')
  log_info "Processing changes" "\"files_changed\":$file_count,\"commit\":\"$new\",\"files\":\"$file_list\""
  
  local found=0
  local java_path="${JAVA_PATH:-services}"
  local python_path="${PYTHON_PATH:-workers}"
  
  for svc in $JAVA_SERVICES; do
    if echo "$files" | grep -q "^${java_path}/$svc/"; then
      found=1
      local should_deploy=1
      local svc_path="${java_path}/$svc"
      
      if [[ "$RUN_TESTS" == "true" ]]; then
        test_java "$svc" "$svc_path" || should_deploy=0
      fi
      
      if [[ $should_deploy -eq 1 ]]; then
        build_deploy "$svc" "$svc_path"
      else
        log_warn "Deploy skipped due to test failure" "\"component\":\"$svc\""
      fi
    fi
  done
  
  for wrk in $PYTHON_WORKERS; do
    if echo "$files" | grep -q "^${python_path}/$wrk/"; then
      found=1
      local should_deploy=1
      local wrk_path="${python_path}/$wrk"
      
      if [[ "$RUN_TESTS" == "true" ]]; then
        test_python "$wrk" "$wrk_path" || should_deploy=0
      fi
      
      if [[ $should_deploy -eq 1 ]]; then
        build_deploy "$wrk" "$wrk_path"
      else
        log_warn "Deploy skipped due to test failure" "\"component\":\"$wrk\""
      fi
    fi
  done
  
  [[ $found -eq 0 ]] && log_info "No matching components" "\"java_path\":\"$java_path\",\"python_path\":\"$python_path\""
}

# Main
log_info "Controller starting" "\"repo\":\"$GIT_REPO\",\"branch\":\"$GIT_BRANCH\",\"poll_interval\":$POLL_INTERVAL,\"run_tests\":\"${RUN_TESTS:-false}\""
log_info "Watching Java" "\"path\":\"${JAVA_PATH:-services}\",\"services\":\"$JAVA_SERVICES\""
log_info "Watching Python" "\"path\":\"${PYTHON_PATH:-workers}\",\"workers\":\"$PYTHON_WORKERS\""

setup_oc || exit 1

last=""
[[ -f "$STATE" ]] && last=$(cat "$STATE")
[[ -n "$last" ]] && log_info "Resuming from previous state" "\"last_commit\":\"$last\""

while true; do
  commit=$(get_remote_commit)
  
  if [[ -z "$commit" ]]; then
    log_warn "Could not fetch remote commit"
    sleep "$POLL_INTERVAL"
    continue
  fi
  
  if [[ "$commit" != "$last" ]]; then
    log_info "New commit detected" "\"commit\":\"$commit\",\"previous\":\"${last:-none}\""
    
    if clone_or_pull; then
      process_changes "$last" "$commit"
      last="$commit"
      echo "$last" > "$STATE"
    else
      log_error "Git pull failed"
    fi
  fi
  
  sleep "$POLL_INTERVAL"
done