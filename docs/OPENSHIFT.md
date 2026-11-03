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
