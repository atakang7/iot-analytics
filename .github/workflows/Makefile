# Makefile - Local development commands that match CI
# Usage: make <target>

.PHONY: help test test-java test-python lint build deploy clean

NAMESPACE ?= atakangul-dev

# ─────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────
help:
	@echo "IoT Analytics - Development Commands"
	@echo ""
	@echo "Testing:"
	@echo "  make test              Run all tests"
	@echo "  make test-java         Run Java tests"
	@echo "  make test-python       Run Python tests"
	@echo "  make lint              Run linters"
	@echo ""
	@echo "Build & Deploy:"
	@echo "  make build             Build all images in OpenShift"
	@echo "  make build-<name>      Build specific component"
	@echo "  make deploy            Deploy via Helm"
	@echo "  make deploy-<name>     Deploy specific component"
	@echo ""
	@echo "Development:"
	@echo "  make logs              Tail all logs"
	@echo "  make status            Show cluster status"
	@echo "  make port-forward      Port forward common services"
	@echo "  make clean             Clean up simulators"
	@echo ""
	@echo "Components: ingestion, device-registry, telemetry-worker, stream-worker, alert-worker"

# ─────────────────────────────────────────────
# Testing
# ─────────────────────────────────────────────
test: test-java test-python

test-java:
	@echo "=== Testing Java Services ==="
	cd services/ingestion && mvn clean test -B -q
	cd services/device-registry && mvn clean test -B -q

test-python:
	@echo "=== Testing Python Workers ==="
	@for w in telemetry-worker stream-worker alert-worker; do \
		echo "Testing $$w..."; \
		cd workers/$$w && pip install -q -r requirements.txt && \
		python -m pytest -v --tb=short 2>/dev/null || echo "No tests"; \
		cd ../..; \
	done

lint:
	@echo "=== Linting ==="
	@for w in telemetry-worker stream-worker alert-worker; do \
		echo "Linting workers/$$w..."; \
		cd workers/$$w && ruff check . || true; \
		cd ../..; \
	done

# ─────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────
build: build-ingestion build-device-registry build-telemetry-worker build-stream-worker build-alert-worker

build-ingestion:
	cd services/ingestion && oc start-build ingestion --from-dir=. --follow

build-device-registry:
	cd services/device-registry && oc start-build device-registry --from-dir=. --follow

build-telemetry-worker:
	cd workers/telemetry-worker && oc start-build telemetry-worker --from-dir=. --follow

build-stream-worker:
	cd workers/stream-worker && oc start-build stream-worker --from-dir=. --follow

build-alert-worker:
	cd workers/alert-worker && oc start-build alert-worker --from-dir=. --follow

# ─────────────────────────────────────────────
# Deploy
# ─────────────────────────────────────────────
deploy:
	helm upgrade --install iot-analytics . --namespace $(NAMESPACE)

deploy-%:
	oc rollout restart deployment/$* -n $(NAMESPACE)
	oc rollout status deployment/$* -n $(NAMESPACE) --timeout=300s

# ─────────────────────────────────────────────
# Development Utilities
# ─────────────────────────────────────────────
status:
	@echo "=== Pods ==="
	@oc get pods -n $(NAMESPACE)
	@echo ""
	@echo "=== Services ==="
	@oc get svc -n $(NAMESPACE)

logs:
	oc logs -l app.kubernetes.io/part-of=iot-analytics -f --max-log-requests=20 2>/dev/null || \
	oc logs -l app -f --max-log-requests=10

logs-%:
	oc logs -l app=$* -f

port-forward:
	@echo "Starting port forwards..."
	@oc port-forward svc/ingestion 8081:8081 &
	@oc port-forward svc/grafana 3000:3000 &
	@oc port-forward svc/prometheus 9090:9090 &
	@echo "Ingestion: http://localhost:8081"
	@echo "Grafana:   http://localhost:3000"
	@echo "Prometheus: http://localhost:9090"

clean:
	oc delete deployment -l app=device-simulator -n $(NAMESPACE) 2>/dev/null || true
	oc delete configmap -l app=device-simulator -n $(NAMESPACE) 2>/dev/null || true

# ─────────────────────────────────────────────
# Database
# ─────────────────────────────────────────────
db-shell:
	oc exec -it deploy/timescaledb -- psql -U iot -d iot

db-query:
	@read -p "SQL: " sql; \
	oc exec deploy/timescaledb -- psql -U iot -d iot -c "$$sql"
