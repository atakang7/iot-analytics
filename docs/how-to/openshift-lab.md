# Validate an OpenShift lab deployment

The parent Helm chart contains OpenShift ImageStreams, BuildConfigs and Routes. GitHub Actions checks its rendered configuration; it does not provision a real OpenShift cluster.

## Check the chart without a cluster

~~~bash
helm dependency build iot-helm
helm lint iot-helm -f iot-helm/values-dev.yaml
helm template iot-analytics iot-helm -f iot-helm/values-dev.yaml > /tmp/iot-rendered.yaml
~~~

## Inspect an existing authorized lab namespace

Set your Kubernetes context and namespace through your own cluster access. These commands are read-only.

~~~bash
oc get bc,is,deployment,cronjob -n "$NAMESPACE"
oc get routes,services,pvc -n "$NAMESPACE"
~~~

Before running [scripts/build-and-deploy.sh](../../scripts/build-and-deploy.sh), verify image registry access, storage classes, Secrets, pull permissions and network policies. The script builds OpenShift binary images and assumes BuildConfigs already exist. It is not a production release method.

Check each worker rollout, then use a real telemetry reading to verify Kafka, TimescaleDB, alerts and KPIs. Prometheus is private; access it with:

~~~bash
oc -n "$NAMESPACE" port-forward svc/prometheus 9090:9090
~~~

APIs and Grafana have no Routes by default. Enabling them requires an authentication and ingress design. Refer to [production gaps](../explanation/production-boundaries.md) before exposing anything externally.
