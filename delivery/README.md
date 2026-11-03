# Immutable delivery

The manual [publish workflow](../.github/workflows/publish.yaml) requires successful `main` verification. It builds the six service images, unpacks each OCI archive for Trivy scanning, produces a CycloneDX SBOM, and publishes the original archive with Skopeo preserving its manifest digest. Cosign signs and verifies the published digest using GitHub OIDC.

The GitHub runner's [local release proof](LOCAL_TEST.md) uses the same build, scan and copy functions against a loopback registry and checks that an unrelated signing key is rejected. It does not publish to GHCR.

`release.py` validates the complete six-image manifest. `state.py` records `dev` and promotes the same digests through `stage` and `prod` when their Git history permits it.

See [publishing and promotion](../docs/how-to/publish-release.md), [release integrity](../docs/explanation/consistency.md) and [production boundaries](../docs/explanation/production-boundaries.md). No live OpenShift deployment is implied.
