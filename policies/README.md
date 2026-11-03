# Enforced Kubernetes security boundary

Native Kubernetes `ValidatingAdmissionPolicy` and `Binding` enforce, for
**every container and init container** in an opted-in namespace:

- CPU and memory requests and limits
- non-root UID, no privilege escalation
- read-only root filesystem and all capabilities dropped

`failurePolicy: Fail` and `validationActions: [Deny]` make this an actual
API admission rule, not a linter. Its binding is **namespace-scoped**:
`iot-policy=enforce`. A developer cannot bypass the rule by removing a Pod
label. No bespoke webhook, privileged controller, or secrets are required.

The runner creates distinct `iot-dependencies` (Kafka/TimescaleDB) and
`iot-validation` (application) namespaces, applies the policy only to the
latter, and invokes [`policies/bin/smoke`](bin/smoke). The smoke test uses
server-side dry-runs to prove one compliant Pod is admitted and two
violating Pods are denied; it never creates test Pods. The full application
is then deployed under the same policy and functionally exercised.

This policy is **opt-in**. It is not automatically installed in any real
OpenShift cluster. Operators must verify the namespace and the policy
compatibility before applying it outside the disposable test environment.
