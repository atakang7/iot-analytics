# CI/CD - GitOps Controller

Lightweight GitOps controller that runs in your namespace. Polls git repo, detects changes, triggers OpenShift builds.

## Structure

```
ci-cd/
├── Chart.yaml
├── values.yaml           # Configuration
├── scripts/
│   └── controller.sh     # Main script (loaded into ConfigMap)
└── templates/
    └── gitops.yaml       # K8s resources
```

## Install

```bash
# From repo root
helm install ci-cd ./ci-cd -n atakangul-dev

# Or with custom values
helm install ci-cd ./ci-cd -n atakangul-dev \
  --set gitops.repo=https://github.com/user/repo.git \
  --set gitops.token=ghp_xxxxx
```

## Configure

Edit `values.yaml`:

```yaml
gitops:
  repo: "https://github.com/user/repo.git"
  branch: "main"
  token: ""  # For private repos
  
  java:
    services:
      - ingestion
      - device-registry
  
  python:
    workers:
      - telemetry-worker
```

## Logs

```bash
oc logs -f deploy/gitops-controller
```

## How it works

1. Polls repo every 60s
2. Detects changed files via `git diff`
3. Maps changes to components:
   - `services/ingestion/*` → builds `ingestion`
   - `workers/alert-worker/*` → builds `alert-worker`
4. Runs `oc start-build <component> --from-dir=<path>`
5. Restarts deployment on success

## Disable

```bash
helm upgrade ci-cd ./ci-cd --set gitops.enabled=false
```
