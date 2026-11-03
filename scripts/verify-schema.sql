-- Executed against a fresh TimescaleDB container in GitHub Actions.
-- Every insert is rolled back; all assertions must fail loudly.
BEGIN;

DO $$
BEGIN
    IF (SELECT count(*) FROM thresholds WHERE sensor_type = 'temperature'
        AND device_type IS NULL) <> 1 THEN
        RAISE EXCEPTION 'Expected one global temperature threshold';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_telemetry_identity')
       OR NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_kpis_window') THEN
        RAISE EXCEPTION 'Missing idempotency indexes';
    END IF;
END $$;

CREATE TEMP TABLE ci_stamp AS SELECT clock_timestamp() AS event_time;

INSERT INTO telemetry (time, device_id, device_type, sensor_id, sensor_type, unit, value)
SELECT event_time, 'ci-sensor-device', 'motor', 'sensor-1', 'temperature', 'celsius',
       '{"value": 20}'::jsonb FROM ci_stamp;
INSERT INTO telemetry (time, device_id, device_type, sensor_id, sensor_type, unit, value)
SELECT event_time, 'ci-sensor-device', 'motor', 'sensor-1', 'temperature', 'celsius',
       '{"value": 20}'::jsonb FROM ci_stamp
ON CONFLICT (device_id, sensor_id, time) DO NOTHING;

DO $$
BEGIN
    IF (SELECT count(*) FROM telemetry WHERE device_id = 'ci-sensor-device') <> 1 THEN
        RAISE EXCEPTION 'Replayed telemetry produced duplicate rows';
    END IF;
END $$;

INSERT INTO alerts (
    alert_id, created_at, device_id, device_type, alert_type, severity, message
) VALUES ('ci-alert', NOW(), 'ci-sensor-device', 'motor', 'threshold_breach', 'warning', 'one');
INSERT INTO alerts (
    alert_id, created_at, device_id, device_type, alert_type, severity, message
) VALUES ('ci-alert', NOW(), 'ci-sensor-device', 'motor', 'threshold_breach', 'warning', 'two')
ON CONFLICT (alert_id) DO UPDATE SET message = EXCLUDED.message;

DO $$
BEGIN
    IF (SELECT count(*) FROM alerts WHERE alert_id = 'ci-alert') <> 1
       OR (SELECT message FROM alerts WHERE alert_id = 'ci-alert') <> 'two' THEN
        RAISE EXCEPTION 'Alert replay was not idempotent';
    END IF;
END $$;
ROLLBACK;
