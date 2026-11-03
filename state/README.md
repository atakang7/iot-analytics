Part of [iot-analytics](../README.md).

# state

Git-tracked desired image digests for dev, stage and prod.

## Run

```bash
python3 delivery/state.py verify --history-ref origin/main
```

## Test

```bash
python3 -m unittest discover -s delivery -p 'test_*.py' -v
```

## Config

| File | Default | What |
| --- | --- | --- |
| `dev.json` | `release: null` | First recorded release |
| `stage.json` | `release: null` | Promoted dev identity |
| `prod.json` | `release: null` | Promoted stage identity |

## Interfaces

`delivery/state.py record-dev` writes dev intent. `promote --source ... --target ...` copies immutable digests; `verify --history-ref` checks predecessor Git history. See [promotion steps](../docs/how-to/publish-release.md).
