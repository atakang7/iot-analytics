# IoT Analytics Helm Chart

## Overview
Umbrella Helm chart deploying the IoT Analytics platform with infrastructure, applications, monitoring, and CI/CD components.

## Structure
- **infra/**: Deploys core infrastructure (Kafka, TimescaleDB, Loki)
- **apps/**: Deploys application services (device-registry, ingestion, workers)
- **monitoring/**: Deploys monitoring stack (Prometheus, Grafana, log-collector)
- **ci-cd/**: Deploys GitOps controller for automated deployments

## Values Files
- `values.yaml`: Global settings and subchart enables
- `values-dev.yaml`: Development environment with simulator configs
- `values-prod.yaml`: Production environment with simulator configs

## Deployment
```bash
# Install with dev values
helm install iot-analytics . -f values-dev.yaml

# Install with prod values
helm install iot-analytics . -f values-prod.yaml
```

## Key Components
- **Kafka**: Message broker for telemetry data
- **TimescaleDB**: Time-series database for metrics
- **Device Registry**: REST API for device management
- **Ingestion**: Telemetry data ingestion service
- **Workers**: Python workers for analytics (telemetry, stream, alert, KPI)
- **Monitoring**: Prometheus metrics, Grafana dashboards, Loki logging
- **GitOps**: Automated deployment from Git repo changes

## OpenShift Specific
Uses ImageStreams and BuildConfigs for container builds in OpenShift environment.</content>
<parameter name="filePath">/home/zperson/iot-analytics/iot-analytics/README.md