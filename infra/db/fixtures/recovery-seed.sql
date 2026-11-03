-- CI-only fixture in a disposable database volume.
INSERT INTO telemetry (time, device_id, device_type, sensor_id, sensor_type, unit, value)
VALUES (NOW(), 'ci-recovery', 'motor', 'sensor-1', 'temperature', 'celsius', '{"value": 71}'::jsonb);
INSERT INTO alerts (alert_id, created_at, device_id, device_type, alert_type, severity, message)
VALUES ('ci-recovery-alert', NOW(), 'ci-recovery', 'motor', 'threshold_breach', 'warning', 'restored');
