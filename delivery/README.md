# Immutable delivery

The golden repo's release invariant now has an explicit implementation:

```text
green main CI
    │ manual workflow dispatch
    ▼
six independent OCI builds (one per service)
    ▼
Trivy CRITICAL gate + CycloneDX SBOM on each local OCI layout
    ▼
skopeo --preserve-digests → GHCR (byte-identity checked)
    ▼
Cosign keyless sign + verify (GitHub OIDC main workflow)
    ▼
six image identities → assemble.py → release.json
    ▼
release.py → release-values.json → reviewed OpenShift deployment
```

The `.github/workflows/publish.yaml` workflow **only runs on explicit
dispatch**, and rejects any branch except `main` or a commit without a
successful main-branch Verify run. It never connects to a Kubernetes cluster.
Each matrix job must pass the vulnerability gate, registry digest check and
cryptographic signature verification; the final job refuses an incomplete or
mixed-revision release.

Download the `immutable-release` Actions artifact containing `release.json`
and `release-values.json`. SBOMs are stored as separate per-image workflow
artifacts. Release image identifiers are pinned OCI digests, not tags.

```bash
python3 delivery/release.py validate release.json
helm template iot-analytics iot-helm -f release-values.json > /tmp/release.yaml
python3 scripts/verify-helm.py /tmp/release.yaml --release-manifest release.json
```

Prerequisites for publication are GitHub Actions package write permission,
container-registry access, Sigstore OIDC and the security feed. Publication
*fails* if a gate or registry/identity check cannot complete. The CI checks
the scripts and release-contract code, but **publishing has not been run
against GHCR** and **live OpenShift deployment is not verified**.

Do not manually substitute synthetic test fixture digests. Never store secrets
in a release manifest. Environment state/promotion is implemented by [state.py](state.py) and
[state/](../state/). Live cluster verification remains operator-owned.

## Supply-chain trust boundary

Every Action is now pinned to a verified full Git SHA, including the patched
post-March-2026 Trivy installer. Pull requests run a secret scan and
`security/verify_actions.py` forbids reintroducing mutable Action tags.
The publisher passes the **OCI archive itself** to Trivy before copying that
exact artifact into GHCR; a raw extracted directory is not a container scan.

The publication workflow is still manual, separate from CI. It has not
published a registry artifact in this repository yet.
