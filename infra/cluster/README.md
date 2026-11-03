# Kubernetes foundation lab

This layer models the golden platform's separation between
**cluster provisioning** and **runtime validation** without pretending
that an application-only chart is infrastructure.

Topology:

```text
Kind control plane (private API)
       |
  -----+-----
  |         |
worker1   worker2
server     client
PV         DNS -> Service -> server
```

`infra/cluster/bin/up` creates a **separate three-node cluster**,
then installs namespace-scoped native admission policies. It refuses
to modify an existing cluster. No remote OpenShift, kubeadm host,
production VM, public ingress or credentials are involved.

`validation/cluster/validate.sh` independently checks:
- exactly one Ready control plane and two Ready worker nodes;
- real DNS and Service connectivity across workers;
- a dynamically provisioned PV retaining data after Pod replacement;
- Kubernetes API server acceptance and rejection under the admission policy.

It cleans up only its own temporary validation namespace.
`infra/cluster/bin/down` deletes **only** the named disposable cluster.

```bash
make foundation-up
make foundation-validate
make foundation-down
```

This proves the network, storage and admission primitives on GitHub-hosted
runners. It is not a multi-AZ production cluster, host-side Vault,
private CA, BIND, MetalLB or control-plane HA deployment.
