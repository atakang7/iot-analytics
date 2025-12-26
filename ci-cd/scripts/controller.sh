#!/bin/bash
# GitOps Controller - watches repo, builds & deploys on change
set -o pipefail

WORKDIR="/tmp/repo"
STATE="/tmp/last_commit"
OC="/tmp/oc"

log() {
  echo "[$(date -u +%H:%M:%S)] $1"
}

setup_oc() {
  [[ -f "$OC" ]] && return 0
  log "Setting up oc CLI..."
  if curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz 2>/dev/null | tar -xz -C /tmp oc 2>/dev/null; then
    chmod +x "$OC"
    log "oc CLI ready"
    return 0
  fi
  log "ERROR: Failed to download oc CLI"
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

build_deploy() {
  local component=$1 path=$2
  local output
  
  log "⏳ Building $component..."
  cd "$WORKDIR"
  
  output=$($OC start-build "$component" --from-dir="$path" --follow --wait 2>&1)
  local build_status=$?
  
  if [[ $build_status -eq 0 ]]; then
    $OC rollout restart "deployment/$component" >/dev/null 2>&1
    log "✅ $component deployed"
    return 0
  else
    log "❌ $component build failed"
    # Extract useful error info
    if echo "$output" | grep -qi "error\|failed\|unable"; then
      echo "$output" | grep -i "error\|failed\|unable" | head -3 | while read -r line; do
        log "   $line"
      done
    elif [[ -z "$output" ]]; then
      log "   No build output - check if BuildConfig '$component' exists"
    else
      echo "$output" | tail -3 | while read -r line; do
        log "   $line"
      done
    fi
    return 1
  fi
}

process_changes() {
  local old=$1 new=$2
  [[ -z "$old" ]] && { log "First run - skipping build"; return; }
  
  cd "$WORKDIR"
  local files=$(git diff --name-only "$old" "$new" 2>/dev/null)
  [[ -z "$files" ]] && return
  
  local found=0
  
  # Java services
  for svc in $JAVA_SERVICES; do
    if echo "$files" | grep -q "^services/$svc/"; then
      found=1
      build_deploy "$svc" "services/$svc"
    fi
  done
  
  # Python workers
  for wrk in $PYTHON_WORKERS; do
    if echo "$files" | grep -q "^workers/$wrk/"; then
      found=1
      build_deploy "$wrk" "workers/$wrk"
    fi
  done
  
  [[ $found -eq 0 ]] && log "No relevant changes detected"
}

# Main
log "GitOps Controller started"
log "Repo: $GIT_REPO"
log "Branch: $GIT_BRANCH"
log "Poll interval: ${POLL_INTERVAL}s"
log "Java: $JAVA_SERVICES"
log "Python: $PYTHON_WORKERS"
log "---"

setup_oc || exit 1

last=""
[[ -f "$STATE" ]] && last=$(cat "$STATE")
[[ -n "$last" ]] && log "Resuming from commit: $last"

while true; do
  commit=$(get_remote_commit)
  
  if [[ -z "$commit" ]]; then
    log "WARN: Could not reach repo"
    sleep "$POLL_INTERVAL"
    continue
  fi
  
  if [[ "$commit" != "$last" ]]; then
    log "New commit: $commit"
    
    if clone_or_pull; then
      process_changes "$last" "$commit"
      last="$commit"
      echo "$last" > "$STATE"
    else
      log "ERROR: Git pull failed"
    fi
  fi
  
  sleep "$POLL_INTERVAL"
done
