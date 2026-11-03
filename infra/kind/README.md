# Ephemeral Kubernetes runtime

This is the **real cluster integration layer** for IoT Analytics, mirroring
the golden platform's distinction between infrastructure and validation.
It provisions an isolated, single-node kind cluster (pinned Kubernetes node
image) with TimescaleDB and KRaft Kafka, loads six application images, and
deploys the **portable application-only Helm chart**.

```bash
bash infra/kind/bin/up
bash validation/kind/e2e.sh
bash infra/kind/bin/down
```

`up` refuses an existing cluster with the same name. Scripts check the
expected `kind-iot-analytics` context before operating. `down` deletes
only the named disposable cluster. The database uses `emptyDir`: destroying
the Pod or cluster **destroys its data**. Generated secrets exist only in the
ephemeral namespace, never in Git. No OpenShift CRDs, registry credentials,
public ingress or production cluster access are required.

`apps.imageMode=kind` is test-only and uses `iot/*:kind` images with
`imagePullPolicy=Never`; it is **never** a deployable/promotable release.
Real release mode still requires signed GHCR image digests and omits the
in-cluster BuildConfigs. Dependencies here are disposable test infrastructure,
not HA/secure production dependencies.
