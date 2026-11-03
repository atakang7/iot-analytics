# Verification

The [Verify workflow](../../.github/workflows/ci.yaml) runs on pull requests and pushes to `main`.

| Job | What runs |
| --- | --- |
| Java | Maven verification of the ingestion and registry services |
| Python | Unit tests for all four workers, shell syntax and local load-test code |
| Database | A live TimescaleDB schema test, replay invariants and isolated restore rehearsal |
| Compose end-to-end | HTTP, broker acknowledgment, telemetry persistence, alerts and KPIs |
| Containers | All six service Docker builds and Compose validation |
| Helm | Chart renders, resource policies, release digests and Prometheus configuration |
| Kubernetes | Live HTTP, Kafka, SQL and KPIs, admission decisions and observability |
| Foundation | Three-node network, DNS, dynamic storage and admission tests |
| OCI release proof | One local image scan, SBOM, digest-preserving copy and Cosign signature |
| Supply chain | Secret scan and immutable GitHub Action references |
| Release state | Six-image manifest and Git promotion-history invariants |

Run a focused local subset:

```bash
mvn -B -ntp -f services/ingestion/pom.xml verify
mvn -B -ntp -f services/device-registry/pom.xml verify
(cd services/workers && for worker in telemetry-worker stream-worker alert-worker kpi-job; do
  (cd "$worker" && PYTHONPATH=.. python -m pytest -q) || exit 1
done)
make up
make smoke
```

The OCI registry in CI listens only on loopback. Production GHCR publication and live OpenShift deployment require separate authorized execution. Runner success does not prove cluster availability or a production recovery objective.
