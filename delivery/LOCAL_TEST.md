# Release trust proof without production credentials

The hosted GitHub runner executes the same library used by the real
[GHCR publisher](bin/publish-image) against a loopback-only OCI registry.

```text
source commit -> buildx OCI archive
            -> Trivy CRITICAL gate + CycloneDX SBOM
            -> skopeo preserve-digest to local registry
            -> source SHA256 == registry SHA256
            -> Cosign sign and verify with ephemeral key
            -> wrong-key verification MUST fail
```

The registry binds to **127.0.0.1 only** and is deleted at the end of
the test. No package write permissions, GitHub OIDC, secrets or remote
Kubernetes access are granted. Its temporary private signing key is never
persisted to Actions artifacts.

The production publisher is still manual and uses GitHub OIDC keyless
signatures. An offline key test does not prove a live GHCR publication,
OIDC trust, or production deployment: these must be verified separately.
