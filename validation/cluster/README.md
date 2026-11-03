# Foundation evidence

The three-node Kubernetes validation proves actual cross-node traffic,
DNS/Service resolution, dynamic persistent storage and server-side
admission decisions. Test workloads are created in a temporary namespace
and then removed. Failures must be repaired in the owning infrastructure
or policy code, not concealed inside the validator.

Run after `infra/cluster/bin/up` from the repository root:
`bash validation/cluster/validate.sh`.
