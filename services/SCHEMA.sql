-- IoT Analytics TimescaleDB Schema
-- Matches DTOs: AnalyticsMessage, KpiMessage, AlertMessage

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Enum types
CREATE TYPE device_type AS ENUM (
    'cnc_machine', 'hvac', 'conveyor', 'compressor', 'access_door'
);

CREATE TYPE device_status AS ENUM (
    'active', 'inactive', 'maintenance', 'decommissioned'
);

CREATE TYPE sensor_type AS ENUM (
    'temperature', 'humidity', 'pressure', 'speed',
    'spindle_rpm', 'fan_rpm', 'vibration', 'power',
    'proximity', 'contact'
);

CREATE TYPE alert_severity AS ENUM ('info', 'warning', 'critical');

CREATE TYPE alert_type AS ENUM (
    'high_temperature', 'low_temperature', 'rapid_temperature_change',
    'high_vibration', 'vibration_anomaly',
    'power_overcurrent', 'power_undervoltage', 'power_overvoltage', 'low_power_factor',
    'high_pressure', 'low_pressure',
    'device_offline', 'sensor_malfunction', 'threshold_breach',
    'door_open_too_long', 'unauthorized_access'
);

-----------------------------------------------------------
-- DEVICES (registry)
-- Source: Device.java (device-registry service)
-----------------------------------------------------------
CREATE TABLE devices (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT             NOT NULL,
    type             device_type      NOT NULL,
    description      TEXT,
    location         TEXT,
    status           device_status    NOT NULL DEFAULT 'inactive',
    firmware_version TEXT,
    created_at       TIMESTAMPTZ      NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ      DEFAULT NOW(),
    last_seen_at     TIMESTAMPTZ
);

CREATE INDEX idx_devices_type ON devices (type);
CREATE INDEX idx_devices_status ON devices (status);
CREATE INDEX idx_devices_location ON devices (location);

-----------------------------------------------------------
-- TELEMETRY (raw sensor data)
-- Source: AnalyticsMessage.java
-----------------------------------------------------------
CREATE TABLE telemetry (
    time         TIMESTAMPTZ      NOT NULL,
    device_id    UUID             NOT NULL REFERENCES devices(id),
    device_type  device_type      NOT NULL,
    sensor_id    TEXT             NOT NULL,
    sensor_type  sensor_type      NOT NULL,
    unit         TEXT             NOT NULL,
    value        JSONB            NOT NULL
);

SELECT create_hypertable('telemetry', 'time');

-- Compression: older data compresses well
ALTER TABLE telemetry SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id, sensor_type'
);
SELECT add_compression_policy('telemetry', INTERVAL '7 days');

-- Retention: drop raw data after 30 days (aggregates kept longer)
SELECT add_retention_policy('telemetry', INTERVAL '30 days');

-- Indexes
CREATE INDEX idx_telemetry_device ON telemetry (device_id, time DESC);
CREATE INDEX idx_telemetry_sensor ON telemetry (sensor_id, time DESC);
CREATE INDEX idx_telemetry_type ON telemetry (sensor_type, time DESC);

-----------------------------------------------------------
-- KPIS (computed metrics from Flink)
-- Source: KpiMessage.java
-----------------------------------------------------------
CREATE TABLE kpis (
    created_at    TIMESTAMPTZ      NOT NULL,
    device_id     UUID             NOT NULL REFERENCES devices(id),
    device_type   device_type      NOT NULL,
    kpi_name      TEXT             NOT NULL,
    kpi_value     DOUBLE PRECISION NOT NULL,
    unit          TEXT,
    window_start  TIMESTAMPTZ      NOT NULL,
    window_end    TIMESTAMPTZ      NOT NULL,
    sample_count  BIGINT
);

SELECT create_hypertable('kpis', 'created_at');

ALTER TABLE kpis SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id, kpi_name'
);
SELECT add_compression_policy('kpis', INTERVAL '7 days');

-- Keep KPIs for 1 year
SELECT add_retention_policy('kpis', INTERVAL '365 days');

-- Indexes
CREATE INDEX idx_kpis_device ON kpis (device_id, created_at DESC);
CREATE INDEX idx_kpis_name ON kpis (kpi_name, created_at DESC);
CREATE INDEX idx_kpis_device_kpi ON kpis (device_id, kpi_name, created_at DESC);

-----------------------------------------------------------
-- ALERTS (anomaly detection from Flink)
-- Source: AlertMessage.java
-----------------------------------------------------------
CREATE TABLE alerts (
    created_at    TIMESTAMPTZ      NOT NULL,
    alert_id      TEXT             NOT NULL UNIQUE,
    device_id     UUID             NOT NULL REFERENCES devices(id),
    device_type   device_type      NOT NULL,
    alert_type    alert_type       NOT NULL,
    severity      alert_severity   NOT NULL,
    message       TEXT             NOT NULL,
    kpi_name      TEXT,
    kpi_value     DOUBLE PRECISION,
    threshold     DOUBLE PRECISION,
    window_start  TIMESTAMPTZ,
    window_end    TIMESTAMPTZ,
    acknowledged  BOOLEAN          DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by TEXT
);

SELECT create_hypertable('alerts', 'created_at');

-- No compression for alerts - need fast updates for acknowledgment
-- Keep alerts for 2 years
SELECT add_retention_policy('alerts', INTERVAL '730 days');

-- Indexes
CREATE INDEX idx_alerts_device ON alerts (device_id, created_at DESC);
CREATE INDEX idx_alerts_severity ON alerts (severity, created_at DESC);
CREATE INDEX idx_alerts_unack ON alerts (acknowledged, created_at DESC) WHERE NOT acknowledged;
CREATE INDEX idx_alerts_type ON alerts (alert_type, created_at DESC);

-----------------------------------------------------------
-- CONTINUOUS AGGREGATES (pre-computed rollups)
-----------------------------------------------------------

-- Hourly telemetry rollup (for scalar values only)
CREATE MATERIALIZED VIEW telemetry_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    device_id,
    sensor_id,
    sensor_type,
    avg((value->>'value')::double precision) AS avg_value,
    min((value->>'value')::double precision) AS min_value,
    max((value->>'value')::double precision) AS max_value,
    count(*) AS sample_count
FROM telemetry
WHERE sensor_type IN ('temperature', 'humidity', 'pressure', 'speed', 'spindle_rpm', 'fan_rpm')
GROUP BY bucket, device_id, sensor_id, sensor_type
WITH NO DATA;

SELECT add_continuous_aggregate_policy('telemetry_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-- Daily KPI rollup
CREATE MATERIALIZED VIEW kpis_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', created_at) AS bucket,
    device_id,
    kpi_name,
    avg(kpi_value) AS avg_value,
    min(kpi_value) AS min_value,
    max(kpi_value) AS max_value,
    sum(sample_count) AS total_samples
FROM kpis
GROUP BY bucket, device_id, kpi_name
WITH NO DATA;

SELECT add_continuous_aggregate_policy('kpis_daily',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day'
);

-- Hourly alert counts
CREATE MATERIALIZED VIEW alerts_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', created_at) AS bucket,
    device_id,
    alert_type,
    severity,
    count(*) AS alert_count
FROM alerts
GROUP BY bucket, device_id, alert_type, severity
WITH NO DATA;

SELECT add_continuous_aggregate_policy('alerts_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour'
);

-----------------------------------------------------------
-- THRESHOLD CONFIG TABLE (runtime configurable)
-----------------------------------------------------------
CREATE TABLE thresholds (
    id           SERIAL PRIMARY KEY,
    kpi_name     TEXT NOT NULL,
    device_type  device_type,  -- NULL means applies to all
    warning_low  DOUBLE PRECISION,
    warning_high DOUBLE PRECISION,
    critical_low DOUBLE PRECISION,
    critical_high DOUBLE PRECISION,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(kpi_name, device_type)
);

-- Default thresholds from KpiDefinitions.java
INSERT INTO thresholds (kpi_name, warning_high, critical_high) VALUES
    ('temperature_avg', 70.0, 85.0),
    ('temperature_max', 70.0, 85.0);

INSERT INTO thresholds (kpi_name, warning_low, critical_low) VALUES
    ('temperature_min', 5.0, 0.0);

INSERT INTO thresholds (kpi_name, warning_high, critical_high) VALUES
    ('vibration_rms', 1.5, 2.5),
    ('vibration_peak', 2.0, 3.5);

INSERT INTO thresholds (kpi_name, warning_low, critical_low) VALUES
    ('power_factor_avg', 0.85, 0.70),
    ('uptime_percent', 95.0, 90.0);