# Verification reference

[ci.yaml](../../.github/workflows/ci.yaml) runs on pull requests and pushes to `main`.

| Job | Checks |
| --- | --- |
| Supply chain | Trivy secret scan and immutable Action refs |
| Python | Worker tests, shell syntax, documentation and load-test checks |
| Java | Maven tests for ingestion and registry |
| Containers | Compose configuration and six Docker images |
| Helm | OpenShift lab render, digest mode and Prometheus config |
| Release state | Manifest validation and promotion history |
| Database | TimescaleDB constraints and isolated restore rehearsal |
| E2E | HTTP, Kafka, telemetry, alerts and KPIs in Compose |
| Kubernetes | Application pipeline, admission, metrics and logs in Kind |
| Foundation | Three-node DNS, network, storage and admission |
| OCI release proof | Trivy scan, SBOM, digest-preserving copy and Cosign |

The OCI proof uses a registry on `127.0.0.1:5001`. It checks the original archive digest against the copied manifest and rejects an unrelated Cosign verification key. The registry and signing keys are removed after the test.

[Publish workflow](../../.github/workflows/publish.yaml) is manual. It requires a passing `main` run and signs published GHCR digests with GitHub OIDC.

Commands for focused checks are in each [component README](../../services/README.md) and the [Kubernetes guide](../how-to/test-kubernetes.md).
