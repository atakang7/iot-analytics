Part of [iot-analytics](../../README.md).

# delivery commands

Shell entry points for immutable OCI publication and its local proof.

## Run

```bash
bash delivery/bin/test-local-publish
```

The local proof requires Docker, Buildx, Trivy, Skopeo, Cosign and a Git commit SHA exported as `GITHUB_SHA`.

## Test

```bash
bash -n delivery/bin/publish-image delivery/bin/test-local-publish
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `GITHUB_SHA` | Required | Source commit |
| `GITHUB_REF` | Required for publish | Must be `refs/heads/main` |
| `REGISTRY_TOKEN` | Required for publish | GHCR token |
| `REGISTRY_USER` | Required for publish | Registry account |

## Interfaces

`publish-image` accepts a service name and publishes a scanned image digest and identity JSON to GHCR. `test-local-publish` uses a loopback registry and ephemeral signing material. See [release procedure](../../docs/how-to/publish-release.md).
