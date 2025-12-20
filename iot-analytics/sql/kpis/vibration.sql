-- ============================================================================
-- JOB: Vibration KPI
-- ============================================================================
-- Computes: RMS (Root Mean Square) of 3-axis vibration per device per minute
-- Formula: RMS = sqrt(avg(x² + y² + z²))
-- Output: PostgreSQL device_kpis table
-- 
-- Run: ./bin/sql-client.sh -f sql/kpis/vibration.sql
-- ============================================================================

SET 'execution.checkpointing.interval' = '60s';

-- SOURCE: Kafka
CREATE TABLE sensor_readings (
    deviceId        STRING,
    deviceType      STRING,
    sensorType      STRING,
    `timestamp`     TIMESTAMP(3),
    `value`         STRING,
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sensor-readings',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'flink-vibration-kpi',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
);

-- SINK: PostgreSQL
CREATE TABLE kpi_output (
    device_id       STRING,
    device_type     STRING,
    kpi_name        STRING,
    kpi_value       DOUBLE,
    window_start    TIMESTAMP(3),
    window_end      TIMESTAMP(3),
    sample_count    BIGINT,
    created_at      TIMESTAMP(3),
    PRIMARY KEY (device_id, kpi_name, window_end) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://localhost:5432/iot_analytics',
    'table-name' = 'device_kpis',
    'username' = 'postgres',
    'password' = 'postgres'
);

-- COMPUTE: Vibration RMS per minute
-- RMS = sqrt(avg(x² + y² + z²))
INSERT INTO kpi_output
SELECT 
    deviceId,
    deviceType,
    'vibration_rms' AS kpi_name,
    SQRT(AVG(
        POWER(CAST(JSON_VALUE(`value`, '$.x') AS DOUBLE), 2) +
        POWER(CAST(JSON_VALUE(`value`, '$.y') AS DOUBLE), 2) +
        POWER(CAST(JSON_VALUE(`value`, '$.z') AS DOUBLE), 2)
    )) AS kpi_value,
    window_start,
    window_end,
    COUNT(*) AS sample_count,
    CURRENT_TIMESTAMP AS created_at
FROM TABLE(
    TUMBLE(TABLE sensor_readings, DESCRIPTOR(`timestamp`), INTERVAL '1' MINUTE)
)
WHERE sensorType = 'vibration'
GROUP BY deviceId, deviceType, window_start, window_end;
