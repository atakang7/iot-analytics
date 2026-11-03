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

The obsolete, highly privileged OpenShift polling controller has been
removed entirely. There is no cluster deployment or implicit promotion from CI.

For failures, inspect the named job, logs and any failing test. Never treat
a skipped job or manually emitted status as application proof.

The Kubernetes runner also deploys an isolated monitoring stack
(Prometheus, Alertmanager, Loki, Grafana, namespace-scoped log forwarder)
and validates five live scrapes, two alert rules, data sources and actual
worker log delivery to Loki.

A separate foundation runner creates a disposable three-node Kind cluster
(1 control plane + 2 workers) and proves DNS, cross-node Service traffic,
PVC data persistence across Pod replacement, and native admission decisions.
This check is independent of application integration tests.
