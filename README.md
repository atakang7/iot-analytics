
# IoT Analytics Platform

## MVP TODOs

- [ ] Design Postgres device modeling
- [ ] Update device-registry to save devices in Postgres
- [ ] Update ingestion service for strict device checks, Kafka routing, and storage topic
- [ ] Implement storage writing worker for DB persistence
- [ ] Design and implement analytics results storage in Postgres (JSONB, device-agnostic)
- [ ] Implement bookmark/checkpoint table for workers to track last processed window per device/config
- [ ] Make analytics workers config-driven and device-agnostic (data sources, calculation logic, target storage)
- [ ] Document architecture and best practices for analytics, storage, and event-driven patterns

A microservices-based IoT analytics platform for device management, telemetry ingestion, and real-time analytics.

