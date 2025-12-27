# CI/CD - GitOps Controller

In-cluster GitOps controller. All builds happen inside OpenShift - no external credentials needed.

## Architecture
```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            GITHUB                                             │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    GitHub Actions (CI)                                  │ │
│  │   ┌──────┐    ┌───────────┐    ┌─────────────────┐                      │ │
│  │   │ Lint │───►│ Unit Test │───►│ Build (verify)  │──► ✓ Status          │ │
│  │   └──────┘    └───────────┘    └─────────────────┘                      │ │
│  │                                                                         │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│   ┌────────────┐      ┌────────────┐      ┌────────────┐                     │
│   │ dev branch │      │ staging    │      │ main       │◄── deploy status    │
│   └─────┬──────┘      └─────┬──────┘      └─────┬──────┘                     │
└─────────┼───────────────────┼───────────────────┼────────────────────────────┘
          │                   │                   │
          │ poll              │ poll              │ poll
          ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          OPENSHIFT CLUSTER                                    │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    GitOps Controller (CD)                                │ │
│  │                                                                          │ │
│  │  ┌──────────┐   ┌─────────────┐   ┌────────┐   ┌───────┐   ┌─────────┐ │ │
│  │  │ Pull Src │──►│ oc start-   │──►│ Deploy │──►│ Smoke │──►│ Update  │ │ │
│  │  │          │   │ build       │   │        │   │ Test  │   │ GitHub  │ │ │
│  │  └──────────┘   └─────────────┘   └────────┘   └───────┘   └─────────┘ │ │
│  │                        │                                                 │ │
│  │                        ▼                                                 │ │
│  │               ┌─────────────────┐                                        │ │
│  │               │ Internal        │                                        │ │
│  │               │ Registry        │                                        │ │
│  │               │ (no ext creds)  │                                        │ │
│  │               └─────────────────┘                                        │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## CI vs CD Responsibilities
```
┌────────────────────────────────┐    ┌────────────────────────────────────────┐
│     CI (GitHub Actions)        │    │       CD (GitOps Controller)           │
│                                │    │                                        │
│  • Lint (flake8, checkstyle)   │    │  • Build image (oc start-build)        │
│  • Unit tests pytest, JUnit   │    │  • Push to internal registry           │
│  • Build verification          │    │  • Deploy to namespace                 │
│  • Fast feedback (<2 min)      │    │  • Smoke tests (health checks)         │
│                                │    │  • Integration tests                   │
│                                │    │  • Update GitHub commit status         │
│           │    │                │
│                                │    │  Only needs: GitHub token (repo:status)│
└────────────────────────────────┘    └────────────────────────────────────────┘
```

## Secrets

| Secret | Location | Scope |
|--------|----------|-------|
| GitHub token | OpenShift Secret | `repo:status` only |
| OpenShift creds | Never exported | Stays in cluster |
| Registry | Internal | Auto-managed by OpenShift |

## Install
```bash
helm install ci-cd ./ci-cd -n project-dev \
  --set gitops.branch=dev \
  --set gitops.repo=https://github.com/atakang7/iot-analytics.git \
  --set gitops.token=$GITHUB_TOKEN
```

## Configure
```yaml
gitops:
  repo: "https://github.com/user/repo.git"
  branch: "dev"
  token: ""                    # GitHub token for status updates
  pollInterval: 3
  
  smokeTest:
    enabled: true
    endpoints:
      - name: ingestion
        path: /health
      - name: device-registry
        path: /actuator/health
  
  statusReporting:
    enabled: true
    context: "deploy/openshift-dev"
  
  java:
    path: "services"
    services: [ingestion, device-registry]
  
  python:
    path: "services/workers"
    workers: [telemetry-worker, alert-worker, stream-worker, kpi-job]
```

## Logs
```bash
oc logs -f deploy/gitops-controller
```