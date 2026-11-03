Part of [iot-analytics](../README.md).

# security

Static checks for GitHub Actions ref pinning and workflow permissions.

## Run

```bash
python3 security/verify_actions.py
```

## Test

```bash
python3 -m unittest discover -s security -p 'test_*.py' -v
```

## Interfaces

`verify_actions.py` reads `.github/workflows/*.yaml` and rejects mutable action refs, `pull_request_target` and `write-all` permissions. No network calls or credentials.
