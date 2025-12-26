# CI/CD Pipeline

## Architecture

```
.github/
├── actions/
│   └── setup-oc/          # Reusable action: OpenShift CLI setup
│       └── action.yaml
├── config/
│   └── services.yaml      # Service definitions (source of truth)
└── workflows/
    ├── _test-python.yaml  # Reusable: Python test workflow
    ├── _test-java.yaml    # Reusable: Java test workflow
    ├── _build-deploy.yaml # Reusable: Build & deploy to OpenShift
    ├── ci.yaml            # Main CI: runs on PR/push
    └── cd.yaml            # Main CD: deploys on main push
```

## Workflows

### CI (ci.yaml)
- **Trigger**: PR or push to `main`
- **Purpose**: Run tests
- **Behavior**: Only tests components that changed

### CD (cd.yaml)
- **Trigger**: Push to `main` or manual dispatch
- **Purpose**: Build and deploy
- **Behavior**: Only deploys components that changed

## Adding a New Service

1. Add to `.github/config/services.yaml`:
```yaml
java:  # or python:
  - name: my-service
    path: services/my-service
```

2. Add test job to `ci.yaml`:
```yaml
test-my-service:
  needs: changes
  if: needs.changes.outputs.services == 'true'
  uses: ./.github/workflows/_test-java.yaml
  with:
    name: my-service
    path: services/my-service
```

3. Add deploy job to `cd.yaml`:
```yaml
deploy-my-service:
  needs: changes
  if: needs.changes.outputs.my-service == 'true'
  uses: ./.github/workflows/_build-deploy.yaml
  with:
    name: my-service
    path: services/my-service
  secrets: inherit
```

4. Add change detection in `cd.yaml` changes job:
```yaml
echo "$CHANGED" | grep -q "^services/my-service/" && echo "my-service=true" >> $GITHUB_OUTPUT || true
```

## Manual Deployment

1. Go to Actions → CD
2. Click "Run workflow"
3. Select component or "all"
4. Optionally check "Force deploy"

## Local Development

```bash
# Run same tests as CI
make test

# Build specific component
make build-ingestion

# Deploy all via Helm
make deploy

# View status
make status
```

## Required Secrets

| Secret | Description |
|--------|-------------|
| `OPENSHIFT_SERVER` | API server URL |
| `OPENSHIFT_TOKEN` | Service account token |
| `OPENSHIFT_NAMESPACE` | Target namespace |

Generate with: `./scripts/setup-cicd.sh`
