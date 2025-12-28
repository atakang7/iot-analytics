#!/bin/bash
# lib.sh - Stable utilities for GitOps controller

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING
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
# STATE
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
mark_sha_processed() {
  echo "$1" >> "$PROCESSED_FILE"
}

is_sha_processed() {
  grep -q "^$1$" "$PROCESSED_FILE" 2>/dev/null
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GITHUB
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
update_github_status() {
  local sha="$1" state="$2" context="$3" description="$4"
  
  [[ -z "$GIT_TOKEN" ]] && { log_warn "No GIT_TOKEN"; return 0; }
  
  local response http_code
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/statuses/$sha" \
    -d "{\"state\":\"$state\",\"context\":\"$context\",\"description\":\"$description\"}")
  
  http_code=$(echo "$response" | tail -1)
  
  if [[ "$http_code" != "201" ]]; then
    log_error "GitHub status failed" "\"http_code\":\"$http_code\""
    return 1
  fi
  return 0
}

get_pending_deploy() {
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits?per_page=10" 2>/dev/null)
  
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  [[ "$http_code" != "200" ]] && return 1
  
  local sha
  for sha in $(echo "$body" | jq -r '.[].sha' 2>/dev/null); do
    [[ -z "$sha" ]] && continue
    is_sha_processed "$sha" && continue
    
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
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/commits/$sha" 2>/dev/null)
  
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  
  [[ "$http_code" != "200" ]] && return 1
  echo "$body" | jq -r '.files[].filename // empty' 2>/dev/null
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SLACK
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
notify_slack() {
  local status="$1" message="$2" components="${3:-}"
  
  [[ -z "$SLACK_WEBHOOK" ]] || [[ "$SLACK_WEBHOOK" == *"xxx"* ]] && return 0
  
  local color="good"
  [[ "$status" == "failure" ]] && color="danger"
  [[ "$status" == "warning" ]] && color="warning"
  
  curl -s -X POST -H 'Content-type: application/json' --data "{
    \"attachments\": [{
      \"color\": \"$color\",
      \"title\": \"GitOps: $status\",
      \"text\": \"$message\",
      \"footer\": \"$GITHUB_OWNER/$GITHUB_REPO_NAME\"
    }]
  }" "$SLACK_WEBHOOK" >/dev/null 2>&1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GIT
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
clone_repo() {
  local sha="$1"
  
  log_info "Downloading" "\"sha\":\"${sha:0:12}\""
  
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR"
  
  # Download tarball via GitHub API
  curl -sL -H "Authorization: token $GIT_TOKEN" \
    "$GITHUB_API/repos/$GITHUB_OWNER/$GITHUB_REPO_NAME/tarball/$sha" | \
    tar -xz -C "$WORKDIR" --strip-components=1
  
  [[ $? -ne 0 ]] && { log_error "Download failed"; return 1; }
  
  log_info "Download done"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HELM
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
helm_rollback() {
  log_info "Rollback" "\"release\":\"$HELM_RELEASE\""
  
  local history
  history=$(helm history "$HELM_RELEASE" -n "$HELM_NAMESPACE" -o json 2>&1)
  [[ $? -ne 0 ]] && { log_warn "No history"; return 1; }
  
  local rev=$(echo "$history" | jq -r '.[-1].revision' 2>/dev/null)
  [[ -z "$rev" ]] || [[ "$rev" == "null" ]] || [[ "$rev" -le 1 ]] && { log_warn "No prev revision"; return 1; }
  
  local prev=$((rev - 1))
  helm rollback "$HELM_RELEASE" "$prev" -n "$HELM_NAMESPACE" --wait --timeout 120s 2>&1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CLI SETUP
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
setup_cli() {
  local tool="$1" check="$2" install="$3"
  if eval "$check" >/dev/null 2>&1; then
    log_info "$tool ready"
    return 0
  fi
  log_info "Installing $tool"
  eval "$install" >/dev/null 2>&1 || { log_error "$tool install failed"; return 1; }
  log_info "$tool installed"
}

setup_all_cli() {
  setup_cli "oc" "oc version --client" \
    "curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz | tar -xz -C $BIN_DIR oc" || return 1
  
  setup_cli "helm" "helm version --short" \
    "curl -sL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar -xz -C /tmp && mv /tmp/linux-amd64/helm $BIN_DIR/" || return 1
  
  setup_cli "jq" "jq --version" \
    "curl -sL https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 -o $BIN_DIR/jq && chmod +x $BIN_DIR/jq" || return 1
  
  [[ "$IMAGE_SCAN_ENABLED" == "true" ]] && setup_cli "trivy" "trivy --version" \
    "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $BIN_DIR"
  
  return 0
}