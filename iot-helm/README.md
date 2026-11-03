# Helm charts

The parent `iot-helm` chart targets an OpenShift lab. It includes an `infra` chart for Kafka, TimescaleDB and Loki; `apps` for application workloads; and `monitoring` for metrics and dashboards. Its ImageStreams, BuildConfigs and Routes require OpenShift.

Three app image modes are defined: `lab` uses OpenShift binary builds; `kind` uses locally loaded test images; `release` requires the full set of six immutable image digests. The portable `apps` chart is tested in Kind without the parent chart.

~~~bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml
~~~

APIs and Grafana have private Routes by default; Prometheus has no public Route. Existing database volumes need a separate SQL migration.

See [Helm values and modes](../docs/reference/helm.md), [Kind validation](../docs/how-to/test-kubernetes.md), [OpenShift lab checks](../docs/how-to/openshift-lab.md) and [immutable release steps](../docs/how-to/publish-release.md).
