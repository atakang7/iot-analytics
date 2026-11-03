# OpenShift

`iot-helm/` uses OpenShift ImageStreams, BuildConfigs and Routes; CI renders the chart but does not deploy it.

```text
+---------+ gate +--------------+ artifact +--------------+ manual +-----------+
| ci.yaml | ----> | publish.yaml | -------> | release.json | ------> | OpenShift |
+---------+      +--------------+          +--------------+         +-----------+
```

The publication workflow is manually dispatched from green `main`; OpenShift installation and rollback are operator actions.

## Validate

Run from the repository root:

```bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml > /tmp/iot-rendered.yaml
```

A release manifest produces immutable image values:

```bash
python3 delivery/release.py validate release.json
python3 delivery/release.py helm-values release.json --output /tmp/release-values.json
helm template iot-analytics iot-helm -f /tmp/release-values.json > /tmp/release.yaml
```

`release.json` comes from the manually dispatched publish workflow, not from the checked-in test fixture.

## Cluster checks

- Lab-mode image builds use `NAMESPACE=<your-namespace> bash scripts/build-and-deploy.sh` after the chart creates BuildConfigs.
- Check workloads with `oc -n "$NAMESPACE" get deployment,cronjob` and `oc -n "$NAMESPACE" get pods`.
- APIs and Grafana have no public Routes by default; Prometheus is available by port-forward.
- Configure registry access, `iot-central-secret`, storage classes and ingress controls before deployment.
- Existing TimescaleDB volumes need SQL migrations; Helm does not migrate them.

A green CI job does not prove live OpenShift readiness.
