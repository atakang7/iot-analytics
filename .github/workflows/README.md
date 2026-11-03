# CI and deployment boundary

The active workflow is [ci.yaml](ci.yaml).

```text
Pull request / main push
       │
       ├── Java unit tests + builds
       ├── Python unit tests + syntax checks
       ├── Build all six OCI images + validate Compose
       ├── Helm lint and template
       ├── Fresh TimescaleDB schema + dedup replay tests
       └── Real HTTP → Kafka → telemetry → alerts → KPI smoke
                    │
                    ▼
                green / red
```

The workflow verifies the **local** stack. It never publishes images, sets a
`deploy/cd` status, runs OpenShift deployments or promotes across environments.

The legacy self-polling OpenShift controller has been turned off by default
in `iot-helm/values.yaml`. It is retained as lab reference only; it is
not a supported CI handoff or release path.

For failures, inspect the named job, logs and any failing test. Never treat
a skipped job or manually emitted status as application proof.
