# Verified observability path

The application and observability namespaces are separate:

```text
Spring Actuator + Python /metrics  -> Prometheus -> alert rules -> Alertmanager
application container stdout       -> scoped Pod-log collector -> Loki
                                                       |
                                                   Grafana
```

`bin/up` provisions private Prometheus, Loki, Alertmanager and Grafana
inside `iot-observability` and runs a small log collector inside
`iot-validation`. Only the collector has namespace-local Pod/log read
permissions; it has **no cluster role, hostPath mount or secret permissions**.
All dashboards use the repository's existing IoT Grafana JSON.

The observation chain is exercised in CI against real Kubernetes pods:
Prometheus must scrape all five application targets, load the alert
rules and reach Alertmanager; Grafana must serve both provisioned data
sources; Loki must contain actual streamed worker logs.

```bash
make kind-up
bash validation/kind/e2e.sh
bash platform/observability/bin/up
bash validation/observability/smoke.sh
make kind-down
```

Every component runs only on the named disposable kind cluster, is private
to the cluster, and has bounded resources. Grafana has a random generated
admin password; it is not in Git. The Loki log collector polls the
namespaced Pod API and is best-effort, **not an audit-grade log archive**.
Backends use ephemeral disks, Alertmanager has a lab sink (no real pager),
and this is not a production monitoring installation.
