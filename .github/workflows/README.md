┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    CI                                            │
│                                                                                  │
│  push ──► lint ──► test ──► pass ──► set status "pending" context="deploy/cd"   │
│                              │                                                   │
│                              └──► "Waiting for CD controller..."                 │
└──────────────────────────────────────┬──────────────────────────────────────────┘
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    CD                                            │
│                                                                                  │
│  poll ──► find commits with status "pending" + context="deploy/cd"              │
│                │                                                                 │
│                ▼                                                                 │
│         clone @ SHA                                                              │
│                │                                                                 │
│                ▼                                                                 │
│         parallel: build ──► scan ──► helm upgrade ──► smoke test                │
│                │                                                                 │
│                ├── all success ──► set status "success" ✓                       │
│                │                                                                 │
│                └── any failure ──► set status "failure" ✗                       │
│                                    │                                             │
│                                    └──► helm rollback to previous revision      │
└─────────────────────────────────────────────────────────────────────────────────┘