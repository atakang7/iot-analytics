Part of [iot-analytics](../README.md).

# system-test

Bounded HTTP load generator for ingestion acknowledgments.

## Run

```bash
python3 system-test/load.py --count 100 --concurrency 5
```

The local ingestion API must already be running.

## Test

```bash
python3 -m unittest discover -s system-test -p 'test_*.py' -v
```

## Config

| Flag | Default | What |
| --- | --- | --- |
| `--count` | See `--help` | Request count, max 10000 |
| `--concurrency` | See `--help` | Concurrent calls, max 64 |
| `--allow-remote` | Off | Permit a remote HTTPS endpoint |

## Interfaces

`load.py` posts synthetic readings to ingestion and reports status totals, elapsed throughput, and p50/p95 HTTP latency. Results measure Kafka acknowledgments, not SQL persistence. It exits nonzero on rejected requests.
