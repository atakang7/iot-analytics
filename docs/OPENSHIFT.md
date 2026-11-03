# OpenShift smoke and validation

These checks do not require an OpenShift cluster; they only verify that
the chart renders and that its BuildConfigs refer to the worker Dockerfiles
within the common build context.

```bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml > /tmp/iot-rendered.yaml
```

For a *real* OpenShift environment, verify separately:

1. `oc get bc,is,deployment,cronjob -n "$NAMESPACE"`
2. The correct registry permissions, secrets, storage classes and routes.
3. `bash scripts/build-and-deploy.sh` (builds from shared worker context).
4. `oc rollout status deployment/telemetry-worker -n "$NAMESPACE"` and others.
5. The Kafka → TimescaleDB → alert pipeline with a real telemetry event.

Do not use the legacy `ci-cd` controller as a production release gate.

## Visibility and metrics

The chart keeps user-facing APIs and Grafana private by default.
Enable their Routes only after adding ingress authentication and access policy.
Prometheus has no public Route; access it through port-forward:

```bash
oc -n "$NAMESPACE" port-forward svc/prometheus 9090:9090
```

Prometheus scrapes the ingestion and registry management endpoints on port
9090, plus each Python worker's metrics Service on port 8000. A GitHub-hosted
Helm validation job checks these rendered targets and that no public Route
appears by default; this does not replace a live OpenShift smoke test.
