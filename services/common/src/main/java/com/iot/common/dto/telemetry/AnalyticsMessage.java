package com.iot.common.dto.telemetry;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.iot.common.model.DeviceType;
import com.iot.common.model.SensorType;
import com.iot.common.model.sensor.SensorValue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

/**
 * Message format sent to Kafka for Flink processing.
 * Enriched with unit information derived from sensor type.
 *
 * Example JSON:
 * {
 *   "deviceId": "cnc-001",
 *   "deviceType": "cnc_machine",
 *   "sensorId": "temp-01",
 *   "sensorType": "temperature",
 *   "timestamp": "2024-01-15T10:30:00Z",
 *   "unit": "celsius",
 *   "value": {"@type": "scalar", "value": 65.5}
 * }
 */
public record AnalyticsMessage(
    @NotBlank
    @JsonProperty("deviceId")
    String deviceId,

    @NotNull
    @JsonProperty("deviceType")
    DeviceType deviceType,

    @NotBlank
    @JsonProperty("sensorId")
    String sensorId,

    @NotNull
    @JsonProperty("sensorType")
    SensorType sensorType,

    @NotNull
    @JsonProperty("timestamp")
    Instant timestamp,

    @NotBlank
    @JsonProperty("unit")
    String unit,

    @NotNull
    @JsonProperty("value")
    SensorValue value
) {
    @JsonCreator
    public AnalyticsMessage(
        @JsonProperty("deviceId") String deviceId,
        @JsonProperty("deviceType") DeviceType deviceType,
        @JsonProperty("sensorId") String sensorId,
        @JsonProperty("sensorType") SensorType sensorType,
        @JsonProperty("timestamp") Instant timestamp,
        @JsonProperty("unit") String unit,
        @JsonProperty("value") SensorValue value
    ) {
        this.deviceId = deviceId;
        this.deviceType = deviceType;
        this.sensorId = sensorId;
        this.sensorType = sensorType;
        this.timestamp = timestamp;
        this.unit = unit;
        this.value = value;
    }

    /**
     * Returns timestamp as epoch milliseconds for Flink event time.
     */
    public long timestampMillis() {
        return timestamp.toEpochMilli();
    }

    /**
     * Returns the value as a JSON string for Flink SQL parsing.
     */
    public String valueAsJson() {
        return value.toJsonString();
    }
}
