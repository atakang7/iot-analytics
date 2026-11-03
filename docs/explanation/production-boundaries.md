# Production boundaries

GitHub Actions proves the system in disposable Compose and Kind environments. A green build does not establish production reliability.

The following changes need real infrastructure and operator testing before production use:

- Authentication and authorization for both HTTP APIs, with network access controls and abuse limits.
- TLS and broker authentication, external secret delivery and credential rotation.
- A persistent, replicated Kafka deployment with failure testing.
- A managed database migration path. `schema.sql` only initializes fresh volumes.
- Tested backup storage outside the host, recovery objectives and a restoration rehearsal using real business data.
- Resource sizing, load and soak tests against expected traffic.
- Durable logging and alert delivery to an on-call receiver. CI's Loki and Alertmanager have temporary state.
- Verified application release and rollback against the target OpenShift environment, including image-pull credentials, ingress, policy compatibility and storage.

The current registry and telemetry source identities are not linked. That relationship needs an explicit domain decision before it can enforce authorization or device ownership.

See [ADR 0001](../adr/0001-device-identity.md) and [Kubernetes test guide](../how-to/test-kubernetes.md).
