# OpenShift Helm chart

`iot-helm/` packages the `infra`, `apps` and `monitoring` subcharts for OpenShift; it is not a portable Kubernetes install.

## Validate

```bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml > /tmp/iot-rendered.yaml
```

## Config

| value | default | what |
| --- | --- | --- |
| `apps.imageMode` | `lab` | Binary BuildConfigs and ImageStreams |
| `apps.imageMode=release` | manual | Six digest-pinned images from a release manifest |
| `apps.routes.enabled` | `false` | API Routes |
| `monitoring.routes.grafana` | `false` | Grafana Route |

A signed release can be rendered using values from `delivery/release.py`:

```bash
python3 delivery/release.py validate path/to/release.json
python3 delivery/release.py helm-values path/to/release.json --output /tmp/release-values.json
helm template iot-analytics iot-helm -f /tmp/release-values.json > /tmp/release.yaml
```

## Limits

- BuildConfigs require `services/workers` as the shared context for Python workers.
- Lab namespaces, storage classes, `iot-central-secret` and registry access must be configured before installing.
- Exposing a Route requires authentication and ingress policy.
- A Helm render does not verify a live OpenShift deployment.
- Existing database volumes need SQL migrations; Helm does not run schema upgrades.

For cluster checks, see [OpenShift notes](../docs/OPENSHIFT.md).
