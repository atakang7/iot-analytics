-- ============================================================================
-- Kafka Source: sensor-readings topic
-- ============================================================================
-- Reusable source table definition
-- Include this in any job that needs to read from Kafka

CREATE TABLE IF NOT EXISTS sensor_readings (
    deviceId        STRING,
    deviceType      STRING,
    sensorId        STRING,
    sensorType      STRING,
    `timestamp`     TIMESTAMP(3),
    unit            STRING,
    `value`         STRING,
    WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'sensor-readings',
    'properties.bootstrap.servers' = 'kafka:9092',
    'properties.group.id' = 'flink-analytics',
    'scan.startup.mode' = 'latest-offset',
    'format' = 'json',
    'json.ignore-parse-errors' = 'true'
);
