-- ============================================================================
-- JOB: Real-time Anomaly Detection (STREAMING)
-- ============================================================================
-- Purpose: Detect temperature anomalies in REAL-TIME (per event, no windowing)
-- 
-- This is different from KPI jobs:
-- - KPI jobs: aggregate over 1-minute windows, write to Postgres
-- - This job: check EVERY event, emit alert immediately to Kafka
--
-- Thresholds:
-- - WARNING:  temperature > 70°C
-- - CRITICAL: temperature > 85°C
-- 
-- Run: ./bin/sql-client.sh -f sql/streaming/anomaly_detection.sql
-- ============================================================================

SET 'execution.checkpointing.interval' = '30s';

-- SOURCE: Kafka (same as other jobs)
CREATE TABLE sensor_readings (
    deviceId        STRING,
    deviceType      STRING,
    sensorId        STRING,
    sensorType      STRING,
    `timestamp`     TIMESTAMP(3),
    `value`         STRING,
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sensor-readings',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'flink-anomaly-detection',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
);

-- SINK: Kafka alerts topic
CREATE TABLE alerts (
    alert_id        STRING,
    device_id       STRING,
    device_type     STRING,
    sensor_id       STRING,
    alert_type      STRING,
    severity        STRING,
    message         STRING,
    value           DOUBLE,
    threshold       DOUBLE,
    event_time      TIMESTAMP(3),
    created_at      TIMESTAMP(3)
) WITH (
    'connector' = 'kafka',
    'topic' = 'alerts',
    'properties.bootstrap.servers' = 'kafka:9092',
    'format' = 'json'
);

-- DETECT: Temperature anomalies (STREAMING - per event, no window)
INSERT INTO alerts
SELECT 
    -- Unique alert ID
    CONCAT('temp-', deviceId, '-', CAST(`timestamp` AS STRING)) AS alert_id,
    deviceId AS device_id,
    deviceType AS device_type,
    sensorId AS sensor_id,
    'HIGH_TEMPERATURE' AS alert_type,
    
    -- Severity based on value
    CASE 
        WHEN CAST(JSON_VALUE(`value`, '$.value') AS DOUBLE) > 85 THEN 'CRITICAL'
        ELSE 'WARNING'
    END AS severity,
    
    -- Human-readable message
    CONCAT(
        'Temperature ', 
        JSON_VALUE(`value`, '$.value'), 
        '°C exceeds ',
        CASE 
            WHEN CAST(JSON_VALUE(`value`, '$.value') AS DOUBLE) > 85 THEN 'critical threshold (85°C)'
            ELSE 'warning threshold (70°C)'
        END
    ) AS message,
    
    CAST(JSON_VALUE(`value`, '$.value') AS DOUBLE) AS value,
    
    CASE 
        WHEN CAST(JSON_VALUE(`value`, '$.value') AS DOUBLE) > 85 THEN 85.0
        ELSE 70.0
    END AS threshold,
    
    `timestamp` AS event_time,
    CURRENT_TIMESTAMP AS created_at

FROM sensor_readings
WHERE sensorType = 'temperature'
  AND CAST(JSON_VALUE(`value`, '$.value') AS DOUBLE) > 70;
