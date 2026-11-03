# Delivery contract

The golden platform's important property is not a Jenkinsfile; it is that
**a deployable artifact is built once, scanned, identified by digest and
promoted without rebuilding**.

This repository implements the *consumption boundary* for that contract:
`release.py` validates a complete six-image GHCR manifest and produces
values for OpenShift Helm deployments. `scripts/verify-helm.py` checks that
rendered workloads use exactly those digests and no BuildConfig or ImageStream
survives release mode.

```
source commit -> six scanned OCI images -> release.json -> helm values
                                                       -> OpenShift (operator)
```

The producer/publisher, cryptographic signature check, release-state
promotion and deployment checks are **not implemented by this PR**.
Do not treat `delivery/fixtures/release.test.json` as deployable state.
No cluster configuration, tokens or secrets belong in release.json.
