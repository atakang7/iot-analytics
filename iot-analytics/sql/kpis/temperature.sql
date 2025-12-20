-- ============================================================================
-- JOB: Temperature KPI
-- ============================================================================
-- Computes: avg, max, min temperature per device per minute
-- Output: PostgreSQL device_kpis table
-- 
-- Run: ./bin/sql-client.sh -f sql/kpis/temperature.sql
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
    'properties.group.id' = 'flink-temperature-kpi',
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

-- COMPUTE: Temperature average per minute
INSERT INTO kpi_output
SELECT 
    deviceId,
    deviceType,
    'temperature_avg' AS kpi_name,
    AVG(CAST(JSON_VALUE(`value`, '$.value') AS DOUBLE)) AS kpi_value,
    window_start,
    window_end,
    COUNT(*) AS sample_count,
    CURRENT_TIMESTAMP AS created_at
FROM TABLE(
    TUMBLE(TABLE sensor_readings, DESCRIPTOR(`timestamp`), INTERVAL '1' MINUTE)
)
WHERE sensorType = 'temperature'
GROUP BY deviceId, deviceType, window_start, window_end;
