# OpenShift deployment laboratory

This chart is **OpenShift-specific**. It contains ImageStreams,
BuildConfigs and Routes alongside ordinary Kubernetes resources. It is not
supported as a vanilla Kubernetes Helm install.

Subcharts:

- `infra`: single-instance TimescaleDB, Kafka and Loki.
- `apps`: Spring REST services and Python consumers.
- `monitoring`: Prometheus, Grafana, logs.
- `ci-cd`: experimental self-polling GitOps controller, **disabled by default**.

```bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml
```

CI validates chart syntax and verifies that Prometheus scrapes exactly the two
Spring Boot management endpoints (port 9090) and the three worker metrics
Services (port 8000). An offline rendered-manifest validator checks metrics
Services, non-root worker settings and private-by-default Routes.

APIs and Grafana have **no public OpenShift Routes by default**. If access is
needed in a trusted lab, set `apps.routes.enabled=true` and
`monitoring.routes.grafana=true`; add authentication and ingress policy
before using these options in an untrusted environment. Prometheus never
receives a public Route; use `oc port-forward svc/prometheus 9090:9090`.

CI performs syntax and configuration validation only. These checks **do not**
prove that the manifests work in an OpenShift cluster. The chart references
a laboratory namespace, image registry, storage class, and an external
`iot-central-secret`; configure all dependencies deliberately before
deployment.

The CD controller is legacy and not connected to the current GitHub Actions
verification workflow. It is opt-in, not a trustworthy promotion mechanism:
do not enable `ci-cd.enabled` for production or treat a green CI run as a
deployed release. BuildImages for workers must use `services/workers` as
Docker context because they depend on the shared `common/` package.

Existing TimescaleDB volumes need a migration; Helm does not run
`schema.sql` as an upgrade migration.

For the tested local environment, use
[Docker Compose](../README.md) and the [runbook](../RUNBOOK.md).
