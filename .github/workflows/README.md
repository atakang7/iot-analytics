# CI Pipeline

Validates code on push. Does NOT build images or deploy — that's CD's job (GitOps controller in cluster). Choosen this approach, ideal would be to use multiple repositories for each project.

## Flow
```
push/PR
   │
   ▼
┌──────────────────────────────────────────────────────────┐
│                     detect-changes                       │
│                                                          │
│  Java only?  ─────► java-ci                              │
│  Python only? ────► python-ci                            │
│  Both? ───────────► REJECT (mixed push not allowed)      │
│  Neither? ────────► SKIP (docs, helm, etc)               │
└──────────────────────────────────────────────────────────┘
```

## Rules

| Push contains | Result |
|---------------|--------|
| `services/ingestion/*` | java-ci: test ingestion |
| `services/device-registry/*` | java-ci: test device-registry |
| `services/workers/<worker>/*` | python-ci: test that worker |
| `services/workers/common/*` | python-ci: test ALL workers |
| Java + Python mixed | ❌ rejected |
| Other files only | ✅ skipped |

## Structure
```
.github/workflows/
├── ci.yaml              # orchestrator
├── detect-changes.yaml  # what changed?
├── java-ci.yaml         # mvn verify
└── python-ci.yaml       # pytest
```

## Why this design?

1. **Single responsibility per push** — Forces clean commits. Debug one thing at a time.
2. **No image builds in CI** — Images built in-cluster by GitOps controller. No registry creds in GitHub.
3. **Matrix strategy** — Changed services run in parallel, fail-fast on first error.
4. **Common triggers all** — `workers/common/*` change = all workers tested (shared dependency).