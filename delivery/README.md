Part of [iot-analytics](../README.md).

# delivery

Build, scan and sign six image digests, then record release intent in Git.

## Run

```bash
python3 delivery/release.py validate delivery/fixtures/release.test.json
```

## Test

```bash
python3 -m unittest discover -s delivery -p 'test_*.py' -v
```

## Config

| Var | Default | What |
| --- | --- | --- |
| `GITHUB_SHA` | Required by publisher | Exact source revision |
| `REGISTRY_TOKEN` | Required by publisher | GHCR write credential |

## Interfaces

`release.py` validates the six-image manifest; `assemble.py` combines image identities; `state.py` checks Git promotion history. [Publish commands](bin/README.md) share the [OCI library](lib/README.md). See [release procedure](../docs/how-to/publish-release.md).
