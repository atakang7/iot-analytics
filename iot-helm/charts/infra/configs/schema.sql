-- Shared TimescaleDB schema. Keep the Helm copy byte-for-byte identical.
-- Intended for a fresh development database; use migrations for existing data.
CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'inactive',
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE telemetry (
    time TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    device_type TEXT NOT NULL,
    sensor_id TEXT NOT NULL,
    sensor_type TEXT NOT NULL,
    unit TEXT NOT NULL,
    value JSONB NOT NULL
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

-- Partition on the logical window, NOT on updated_at. An upsert of the same
-- device/sensor/KPI/window replaces the prior computation, even on retries.
CREATE TABLE kpis (
    created_at TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    device_type TEXT NOT NULL,
    sensor_id TEXT NOT NULL,
    kpi_name TEXT NOT NULL,
    kpi_value DOUBLE PRECISION NOT NULL,
    unit TEXT,
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    sample_count BIGINT NOT NULL
);
SELECT create_hypertable('kpis', 'window_start');
CREATE UNIQUE INDEX idx_kpis_window
    ON kpis (device_id, sensor_id, kpi_name, window_start);
CREATE INDEX idx_kpis_device ON kpis (device_id, window_start DESC);
CREATE INDEX idx_kpis_name ON kpis (kpi_name, window_start DESC);

-- Alert ID is a stable deduplication key. A regular PostgreSQL table avoids
-- the illegal UNIQUE(alert_id) constraint on a time-partitioned hypertable.
CREATE TABLE alerts (
    alert_id TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    device_type TEXT NOT NULL,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    message TEXT NOT NULL,
    threshold DOUBLE PRECISION,
    value DOUBLE PRECISION,
    acknowledged BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_alerts_device ON alerts (device_id, created_at DESC);
CREATE INDEX idx_alerts_severity ON alerts (severity, created_at DESC);
CREATE INDEX idx_alerts_unack ON alerts (acknowledged, created_at DESC)
    WHERE NOT acknowledged;

CREATE TABLE thresholds (
    id BIGSERIAL PRIMARY KEY,
    sensor_type TEXT NOT NULL,
    device_type TEXT,
    warning_low DOUBLE PRECISION,
    warning_high DOUBLE PRECISION,
    critical_low DOUBLE PRECISION,
    critical_high DOUBLE PRECISION,
    CONSTRAINT uq_threshold UNIQUE NULLS NOT DISTINCT (sensor_type, device_type)
);
INSERT INTO thresholds (sensor_type, warning_low, warning_high, critical_low, critical_high) VALUES
    ('temperature', 5.0, 70.0, 0.0, 85.0),
    ('vibration', NULL, 1.5, NULL, 2.5),
    ('humidity', NULL, 80.0, NULL, 95.0),
    ('pressure', NULL, 8.0, NULL, 10.0);

-- A checkpoint is advanced in the SAME transaction as its KPI writes.
-- Start at the previous fully closed window on a newly initialized database.
CREATE TABLE job_watermarks (
    job_name TEXT PRIMARY KEY,
    last_processed_at TIMESTAMPTZ NOT NULL,
    window_size INTERVAL NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
INSERT INTO job_watermarks (job_name, last_processed_at, window_size)
VALUES (
    'kpi_5min',
    date_bin('5 minutes', NOW() - INTERVAL '5 minutes', TIMESTAMPTZ '1970-01-01'),
    INTERVAL '5 minutes'
);
