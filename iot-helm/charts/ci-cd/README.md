## CD Controller Flow
```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           GitOps Controller                                   │
│                                                                               │
│  Poll GitHub Actions API (30s)                                               │
│       │                                                                       │
│       ▼                                                                       │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │ GET /repos/{owner}/{repo}/actions/runs?status=success&per_page=1       │  │
│  │     → Returns: SHA, branch, run_id of latest successful CI             │  │
│  └────────────────────────────────────────────────────────────────────────┘  │
│       │                                                                       │
│       ▼                                                                       │
│  ┌─────────────────┐                                                         │
│  │ SHA == last_sha │──► Yes ──► sleep, continue                              │
│  └────────┬────────┘                                                         │
│           │ No (new successful CI)                                           │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ GET /repos/{owner}/{repo}/commits/{sha}                                 │ │
│  │     → Returns: list of changed files                                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Detect components from changed files                                    │ │
│  │   services/ingestion/*         → java: ingestion                        │ │
│  │   services/device-registry/*   → java: device-registry                  │ │
│  │   services/workers/common/*    → python: ALL workers                    │ │
│  │   services/workers/<worker>/*  → python: that worker                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Spawn parallel background jobs (one per component)                      │ │
│  │                                                                          │ │
│  │   deploy_component "ingestion" &                                        │ │
│  │   deploy_component "alert-worker" &                                     │ │
│  │   ...                                                                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    PER COMPONENT (parallel)                             │ │
│  │                                                                          │ │
│  │  1. oc start-build $component --from-dir=$path --wait                   │ │
│  │     └─► image built & pushed to internal registry                       │ │
│  │                                                                          │ │
│  │  2. trivy image scan (if enabled)                                       │ │
│  │     └─► critical vuln + failOnCritical? → abort                         │ │
│  │                                                                          │ │
│  │  3. helm upgrade $release $chart --set $component.image.tag=$sha        │ │
│  │     └─► deployment rolled out                                           │ │
│  │                                                                          │ │
│  │  4. smoke test: curl http://$component:8080/health                      │ │
│  │     └─► 5 retries, 3s apart                                             │ │
│  │                                                                          │ │
│  │  5. update GitHub status: deploy/$component → success/failure           │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│           │                                                                   │
│           ▼                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │ Wait for all background jobs                                            │ │
│  │   → collect results                                                     │ │
│  │   → notify slack (success/failure summary)                              │ │
│  │   → save SHA to state file                                              │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└──────────────────────────────────────────────────────────────────────────────┘
```