-- IoT Analytics - Full Schema
-- TimescaleDB (PostgreSQL + timeseries)

CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ===========================================
-- DEVICES
-- ===========================================

CREATE TABLE devices (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name       TEXT NOT NULL,
    type       TEXT NOT NULL,
    status     TEXT NOT NULL DEFAULT 'inactive',
    location   TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===========================================
-- TELEMETRY
-- ===========================================

CREATE TABLE telemetry (
    time        TIMESTAMPTZ NOT NULL,
    device_id   TEXT NOT NULL,
    device_type TEXT NOT NULL,
    sensor_id   TEXT NOT NULL,
    sensor_type TEXT NOT NULL,
    unit        TEXT NOT NULL,
    value       JSONB NOT NULL
);

SELECT create_hypertable('telemetry', 'time');

CREATE INDEX idx_telemetry_device ON telemetry (device_id, time DESC);
CREATE INDEX idx_telemetry_sensor ON telemetry (sensor_type, time DESC);

ALTER TABLE telemetry SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'device_id, sensor_type'
);
SELECT add_compression_policy('telemetry', INTERVAL '7 days');
SELECT add_retention_policy('telemetry', INTERVAL '30 days');

-- ===========================================
-- KPIS
-- ===========================================

CREATE TABLE kpis (
    created_at   TIMESTAMPTZ NOT NULL,
    device_id    TEXT NOT NULL,
    device_type  TEXT NOT NULL,
    kpi_name     TEXT NOT NULL,
    kpi_value    DOUBLE PRECISION NOT NULL,
    unit         TEXT,
    window_start TIMESTAMPTZ NOT NULL,
    window_end   TIMESTAMPTZ NOT NULL,
    sample_count BIGINT
);

SELECT create_hypertable('kpis', 'created_at');

CREATE UNIQUE INDEX idx_kpis_upsert ON kpis (device_id, kpi_name, window_start);
CREATE INDEX idx_kpis_device ON kpis (device_id, created_at DESC);
CREATE INDEX idx_kpis_name ON kpis (kpi_name, created_at DESC);

-- ===========================================
-- ALERTS
-- ===========================================

CREATE TABLE alerts (
    created_at   TIMESTAMPTZ NOT NULL,
    alert_id     TEXT NOT NULL UNIQUE,
    device_id    TEXT NOT NULL,
    device_type  TEXT NOT NULL,
    alert_type   TEXT NOT NULL,
    severity     TEXT NOT NULL,
    message      TEXT NOT NULL,
    threshold    DOUBLE PRECISION,
    value        DOUBLE PRECISION,
    acknowledged BOOLEAN DEFAULT FALSE
);

SELECT create_hypertable('alerts', 'created_at');

CREATE INDEX idx_alerts_device ON alerts (device_id, created_at DESC);
CREATE INDEX idx_alerts_severity ON alerts (severity, created_at DESC);
CREATE INDEX idx_alerts_unack ON alerts (acknowledged, created_at DESC) WHERE NOT acknowledged;

-- ===========================================
-- THRESHOLDS (config)
-- ===========================================

CREATE TABLE thresholds (
    id            SERIAL PRIMARY KEY,
    sensor_type   TEXT NOT NULL,
    device_type   TEXT,
    warning_low   DOUBLE PRECISION,
    warning_high  DOUBLE PRECISION,
    critical_low  DOUBLE PRECISION,
    critical_high DOUBLE PRECISION,
    UNIQUE(sensor_type, device_type)
);

-- Defaults
INSERT INTO thresholds (sensor_type, warning_high, critical_high) VALUES
    ('temperature', 70.0, 85.0),
    ('vibration', 1.5, 2.5),
    ('humidity', 80.0, 95.0),
    ('pressure', 8.0, 10.0);

INSERT INTO thresholds (sensor_type, warning_low, critical_low) VALUES
    ('temperature', 5.0, 0.0);

-- ===========================================
-- JOB WATERMARKS (for exactly-once processing)
-- ===========================================

CREATE TABLE job_watermarks (
    job_name          TEXT PRIMARY KEY,
    last_processed_at TIMESTAMPTZ NOT NULL,
    window_size       INTERVAL NOT NULL,
    updated_at        TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO job_watermarks (job_name, last_processed_at, window_size) VALUES
    ('kpi_5min', '1970-01-01', '5 minutes'),
    ('kpi_1hr', '1970-01-01', '1 hour');
