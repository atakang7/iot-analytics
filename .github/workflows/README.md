Part of [iot-analytics](../../README.md).

# workflows

GitHub Actions checks the stack and publishes signed image digests on manual dispatch.

## Run

`ci.yaml` runs on pull requests and pushes to `main`. `publish.yaml` requires manual dispatch on a verified `main` commit.

## Test

```bash
python3 security/verify_actions.py
python3 -m unittest discover -s security -p 'test_*.py' -v
```

## Config

| Runtime | Pinned version | Job |
| --- | --- | --- |
| Java | 21 | Maven services |
| Python | 3.11 | Worker tests |
| Helm | 3.16.4 | Chart rendering |

## Interfaces

[ci.yaml](ci.yaml) runs the [verification jobs](../../docs/reference/verification.md). [publish.yaml](publish.yaml) creates a six-image release artifact. Neither workflow deploys into a live OpenShift cluster.
