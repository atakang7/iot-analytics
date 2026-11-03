# Immutable delivery

[`publish.yaml`](../.github/workflows/publish.yaml) manually builds six images from a verified `main` commit and produces a digest-pinned release artifact.

```text
+--------------+ OCI +-------+ OCI +--------+ image +------+ digest +--------+
| publish.yaml | ---> | Trivy | ---> | skopeo | -----> | GHCR | ------> | Cosign |
+--------------+      +-------+      +--------+        +------+         +--------+
                                                                      |
                                                                      | identities
                                                                      v
                                                               +-------------+ JSON +--------------+
                                                               | assemble.py | ---> | release.json |
                                                               +-------------+      +--------------+
```

Trivy rejects critical findings; skopeo preserves image digests, and Cosign signs and verifies them.

## Verify a release

Download `release.json` and `release-values.json` from the manually triggered `immutable-release` Actions artifact.

```bash
python3 delivery/release.py validate release.json
helm template iot-analytics iot-helm -f release-values.json > /tmp/release.yaml
python3 scripts/verify-helm.py /tmp/release.yaml --release-manifest release.json
```

## Limits

- CI proves local registry transport and signing with test credentials, not a GHCR publication.
- Live GHCR publishing, OpenShift rollout and rollback are separate operator actions.
- `delivery/fixtures/release.test.json` contains test identities, not deployable images.
- Environment promotion uses [`state.py`](state.py) and versioned [state files](../state/).
