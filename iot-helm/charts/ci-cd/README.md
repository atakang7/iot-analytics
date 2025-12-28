**CD Controller flow (parallel):**
```
┌─────────────────────────────────────────────────────────────────┐
│                    GitOps Controller                             │
│                                                                  │
│  Poll GitHub API (30s)                                          │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────┐                                            │
│  │ Check CI status │ GET /repos/{owner}/{repo}/commits/{sha}/status
│  └────────┬────────┘                                            │
│           │                                                      │
│           ▼                                                      │
│  CI passed + new commit?                                        │
│       │                                                          │
│       ├──► Java detected ──► spawn background job ──┐           │
│       │                                              │           │
│       └──► Python detected ─► spawn background job ──┤           │
│                                                      │           │
│                                              ┌───────▼────────┐  │
│                                              │  Per component │  │
│                                              │  1. git clone  │  │
│                                              │  2. oc build   │  │
│                                              │  3. trivy scan │  │
│                                              │  4. helm upgrade│  │
│                                              │  5. smoke test │  │
│                                              └────────────────┘  │
└─────────────────────────────────────────────────────────────────┘