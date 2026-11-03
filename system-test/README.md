# Bounded performance check

The old scripts used an obsolete JSON contract, assumed cluster tooling and
printed unverified throughput targets. They have been retired.

Use the single, measurable local HTTP benchmark:

```bash
docker compose -f services/docker-compose.yml up -d --build
python3 system-test/load.py --count 100 --concurrency 5
```

This reports actual HTTP 202 acknowledgements, response-status totals,
wall-clock throughput and p50/p95 acknowledgement latency. **It does not
measure end-to-end database persistence** (the ordinary integration smoke
test verifies persistence).

Safety properties:

- Defaults to loopback only. A remote URL needs explicit `--allow-remote`
  and HTTPS. Never point a load test at a system you do not own.
- Caps each invocation at 10,000 requests and concurrency at 64.
- Creates a fresh synthetic device identity per run and unique event timestamps.
- Does not change deployment replica counts, delete data or write bogus
  success statuses. Exits nonzero if any request is not accepted.

Run the offline tests with:

```bash
python3 -m unittest discover -s system-test -p 'test_*.py' -v
```

The GitHub-hosted CI runs the offline checks and a short **25-event** test
against actual ingestion inside the full-stack smoke job. These short CI
runs are correctness checks, not a performance SLA or throughput claim.
