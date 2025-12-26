#!/usr/bin/env python3
"""
Simple GitOps Controller
- Polls git repo for changes
- Runs tests
- Triggers OpenShift builds
- Reports status
"""
import os
import subprocess
import time
import json
import hashlib
from datetime import datetime
from pathlib import Path

# Config from env
REPO_URL = os.getenv("GIT_REPO", "")
BRANCH = os.getenv("GIT_BRANCH", "main")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "60"))
NAMESPACE = os.getenv("NAMESPACE", "atakangul-dev")
SLACK_WEBHOOK = os.getenv("SLACK_WEBHOOK", "")  # Optional

# Project config
PROJECTS = {
    "iot-analytics": {
        "path": "iot-analytics",
        "java_services": ["ingestion", "device-registry"],
        "python_workers": ["telemetry-worker", "stream-worker", "alert-worker"],
    }
}

WORKDIR = Path("/tmp/repo")
STATE_FILE = Path("/tmp/state.json")


def log(msg, level="INFO"):
    ts = datetime.utcnow().isoformat()
    print(f"[{ts}] [{level}] {msg}", flush=True)


def run(cmd, cwd=None, check=True):
    """Run command, return (success, output)"""
    try:
        result = subprocess.run(
            cmd, shell=True, cwd=cwd,
            capture_output=True, text=True, timeout=600
        )
        if check and result.returncode != 0:
            return False, result.stderr or result.stdout
        return True, result.stdout
    except subprocess.TimeoutExpired:
        return False, "Command timed out"
    except Exception as e:
        return False, str(e)


def notify(msg, success=True):
    """Send notification (Slack, etc)"""
    icon = "✅" if success else "❌"
    log(f"{icon} {msg}")
    
    if SLACK_WEBHOOK:
        try:
            import urllib.request
            data = json.dumps({"text": f"{icon} {msg}"}).encode()
            req = urllib.request.Request(SLACK_WEBHOOK, data=data, headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=10)
        except:
            pass


def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}


def save_state(state):
    STATE_FILE.write_text(json.dumps(state))


def get_remote_commit():
    """Get latest commit hash from remote"""
    ok, out = run(f"git ls-remote {REPO_URL} refs/heads/{BRANCH}")
    if ok and out:
        return out.split()[0][:12]
    return None


def clone_or_pull():
    """Clone repo or pull latest"""
    if WORKDIR.exists():
        ok, _ = run(f"git fetch origin && git reset --hard origin/{BRANCH}", cwd=WORKDIR)
        return ok
    else:
        WORKDIR.parent.mkdir(parents=True, exist_ok=True)
        ok, _ = run(f"git clone --branch {BRANCH} --depth 1 {REPO_URL} {WORKDIR}")
        return ok


def get_changed_files(old_commit, new_commit):
    """Get list of changed files between commits"""
    if not old_commit:
        return []
    ok, out = run(f"git diff --name-only {old_commit} {new_commit}", cwd=WORKDIR)
    if ok:
        return out.strip().split("\n")
    return []


def detect_changes(changed_files, project_config):
    """Detect which components changed"""
    changes = {"java": [], "python": []}
    project_path = project_config["path"]
    
    for f in changed_files:
        if not f.startswith(project_path):
            continue
        rel = f[len(project_path):].lstrip("/")
        
        if rel.startswith("services/"):
            service = rel.split("/")[1]
            if service in project_config["java_services"] and service not in changes["java"]:
                changes["java"].append(service)
        
        elif rel.startswith("workers/"):
            worker = rel.split("/")[1]
            if worker in project_config["python_workers"] and worker not in changes["python"]:
                changes["python"].append(worker)
    
    return changes


def run_tests(project_path, changes):
    """Run tests for changed components"""
    results = {"passed": [], "failed": []}
    base = WORKDIR / project_path
    
    # Java tests
    for service in changes["java"]:
        log(f"Testing {service}...")
        ok, out = run("mvn clean test -B -q", cwd=base / "services" / service)
        if ok:
            results["passed"].append(service)
        else:
            results["failed"].append((service, out))
    
    # Python tests
    for worker in changes["python"]:
        log(f"Testing {worker}...")
        worker_path = base / "workers" / worker
        run(f"pip install -q -r requirements.txt pytest", cwd=worker_path)
        ok, out = run("python -m pytest -v --tb=short", cwd=worker_path)
        # Allow no tests
        if ok or "no tests ran" in out.lower():
            results["passed"].append(worker)
        else:
            results["failed"].append((worker, out))
    
    return results


def build_and_deploy(changes):
    """Trigger OpenShift builds and deploy"""
    results = {"success": [], "failed": []}
    
    for service in changes["java"]:
        log(f"Building {service}...")
        ok, out = run(f"oc start-build {service} --from-dir=services/{service} --follow --wait", cwd=WORKDIR / "iot-analytics")
        if ok:
            run(f"oc rollout restart deployment/{service}")
            results["success"].append(service)
        else:
            results["failed"].append((service, out))
    
    for worker in changes["python"]:
        log(f"Building {worker}...")
        ok, out = run(f"oc start-build {worker} --from-dir=workers/{worker} --follow --wait", cwd=WORKDIR / "iot-analytics")
        if ok:
            run(f"oc rollout restart deployment/{worker}")
            results["success"].append(worker)
        else:
            results["failed"].append((worker, out))
    
    return results


def process_changes(project_name, project_config, old_commit, new_commit):
    """Full pipeline: detect → test → build → deploy"""
    changed_files = get_changed_files(old_commit, new_commit)
    if not changed_files:
        return
    
    changes = detect_changes(changed_files, project_config)
    if not changes["java"] and not changes["python"]:
        log(f"No relevant changes in {project_name}")
        return
    
    components = changes["java"] + changes["python"]
    log(f"Changes detected in: {components}")
    notify(f"[{project_name}] Changes detected: {components}")
    
    # Test
    log("Running tests...")
    test_results = run_tests(project_config["path"], changes)
    
    if test_results["failed"]:
        failed = [f[0] for f in test_results["failed"]]
        notify(f"[{project_name}] Tests FAILED: {failed}", success=False)
        for name, output in test_results["failed"]:
            log(f"FAILED {name}: {output[:500]}", level="ERROR")
        return  # Stop pipeline
    
    log(f"Tests passed: {test_results['passed']}")
    
    # Build & Deploy
    log("Building and deploying...")
    deploy_results = build_and_deploy(changes)
    
    if deploy_results["failed"]:
        failed = [f[0] for f in deploy_results["failed"]]
        notify(f"[{project_name}] Deploy FAILED: {failed}", success=False)
    
    if deploy_results["success"]:
        notify(f"[{project_name}] Deployed: {deploy_results['success']}")


def main():
    log("GitOps Controller starting")
    log(f"Repo: {REPO_URL}")
    log(f"Branch: {BRANCH}")
    log(f"Poll interval: {POLL_INTERVAL}s")
    
    if not REPO_URL:
        log("GIT_REPO not set!", level="ERROR")
        return
    
    state = load_state()
    last_commit = state.get("last_commit")
    
    while True:
        try:
            # Check for new commits
            remote_commit = get_remote_commit()
            if not remote_commit:
                log("Could not fetch remote commit", level="WARN")
                time.sleep(POLL_INTERVAL)
                continue
            
            if remote_commit == last_commit:
                time.sleep(POLL_INTERVAL)
                continue
            
            log(f"New commit: {remote_commit} (was: {last_commit})")
            
            # Pull changes
            if not clone_or_pull():
                log("Git pull failed", level="ERROR")
                time.sleep(POLL_INTERVAL)
                continue
            
            # Process each project
            for project_name, config in PROJECTS.items():
                process_changes(project_name, config, last_commit, remote_commit)
            
            # Update state
            last_commit = remote_commit
            save_state({"last_commit": last_commit})
            
        except Exception as e:
            log(f"Error: {e}", level="ERROR")
        
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()