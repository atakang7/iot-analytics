# Architecture

The ingestion API and registry serve different identities. Registry records have internal UUIDs; telemetry identifies a source with a caller-supplied `deviceId`. Ingestion does not resolve this ID against the registry.

```text
+--------+   HTTP   +-----------+  Kafka   +------------------+  SQL   +-----------+
| client | -------> | ingestion | -------> | telemetry-worker | -----> | telemetry |
+--------+          +-----------+          +------------------+        +-----------+
                                           
                 +---------------+  Kafka   +--------------+   SQL   +--------+
telemetry Kafka >| stream-worker | -------> | alert-worker | ------> | alerts |
                 +---------------+          +--------------+         +--------+
                 
+-----------+  closed window   +---------+  SQL   +------+
| telemetry | ----------------> | kpi-job | -----> | kpis |
+-----------+                   +---------+        +------+
```

The ingestion API returns `202` after the broker acknowledges a publish. The telemetry worker persists the record independently. The stream worker checks thresholds and sends alert events to a second topic. An alert worker stores each alert by deterministic identity. The batch job reads a completed five-minute interval and updates KPI rows and the watermark in one database transaction.

Python consumers commit source offsets after a durable database operation or downstream Kafka acknowledgment. Consumers can replay a successful side effect after a crash. Unique record identities limit duplication; they do not provide exactly-once execution.

## Deployment surfaces

Docker Compose is the local integration environment. The portable application Helm subchart is exercised against disposable Kind clusters; the parent chart also contains OpenShift ImageStreams, BuildConfigs and Routes. CI does not deploy the OpenShift parent chart to a real OpenShift cluster.

The observability test installs Prometheus, Alertmanager, Loki and Grafana in a separate private namespace and checks actual scrapes and log arrivals. These backends use temporary storage in the runner.

See [delivery behavior](consistency.md) and [production limitations](production-boundaries.md).
