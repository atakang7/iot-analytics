SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
COMPOSE := docker compose -f services/docker-compose.yml

.PHONY: help up down ps logs smoke api-smoke kpi kind-up kind-smoke kind-down backup

help:
	@printf '%s\n' 'up          Build and start the local stack' \
	  'down        Stop containers (preserve database volume)' \
	  'ps          Inspect container status' \
	  'logs        Tail recent service logs' \
	  'smoke       Run complete end-to-end smoke test' \
	  'api-smoke   Verify ingestion API contract' \
	  'kpi         Run one closed five-minute KPI window' \
	  'kind-up     Create an isolated Kubernetes cluster and all apps' \
	  'kind-smoke  Exercise the real Kubernetes telemetry path' \
	  'kind-down   Remove only that named disposable kind cluster'

up:
	@test -f services/.env || (echo "Create services/.env from .env.example and set IOT_DB_PASSWORD" >&2; exit 1)
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --tail=100

smoke:
	bash scripts/smoke-local.sh

api-smoke:
	bash scripts/test-ingestion.sh

kpi:
	$(COMPOSE) --profile batch run --rm kpi-job

kind-up:
	bash infra/kind/bin/up

kind-smoke:
	bash validation/kind/e2e.sh

kind-down:
	bash infra/kind/bin/down

backup:
	@test -n "$(DEST)" || (echo "Set DEST=/absolute/path/outside/repo.dump" >&2; exit 2)
	bash infra/db/bin/backup "$(DEST)"
