#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Preserve the named TimescaleDB volume: no destructive -v.
docker compose -f "$ROOT/services/docker-compose.yml" stop kafka
