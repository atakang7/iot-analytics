package com.iot.common.dto.telemetry;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.iot.common.model.DeviceType;
import com.iot.common.model.SensorType;
import com.iot.common.model.sensor.SensorValue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;

import java.time.Instant;

/**
 * Incoming telemetry request from IoT devices.
 * This is the API contract for the ingestion service.
 *
 * Example JSON:
 * {
 *   "deviceId": "cnc-001",
 *   "deviceType": "cnc_machine",
 *   "sensorType": "temperature",
 *   "timestamp": "2024-01-15T10:30:00Z",
 *   "value": {"@type": "scalar", "value": 65.5}
 * }
 */
public record TelemetryRequest(
    @NotBlank(message = "Device ID is required")
    @JsonProperty("deviceId")
    String deviceId,

    @NotNull(message = "Device type is required")
    @JsonProperty("deviceType")
    DeviceType deviceType,

    @NotBlank(message = "Sensor ID is required")
    @JsonProperty("sensorId")
    String sensorId,

    @NotNull(message = "Sensor type is required")
    @JsonProperty("sensorType")
    SensorType sensorType,

    @NotNull(message = "Timestamp is required")
    @PastOrPresent(message = "Timestamp cannot be in the future")
    @JsonProperty("timestamp")
    Instant timestamp,

    @NotNull(message = "Value is required")
    @JsonProperty("value")
    SensorValue value
) {
    @JsonCreator
    public TelemetryRequest(
        @JsonProperty("deviceId") String deviceId,
        @JsonProperty("deviceType") DeviceType deviceType,
        @JsonProperty("sensorId") String sensorId,
        @JsonProperty("sensorType") SensorType sensorType,
        @JsonProperty("timestamp") Instant timestamp,
        @JsonProperty("value") SensorValue value
    ) {
        this.deviceId = deviceId;
        this.deviceType = deviceType;
        this.sensorId = sensorId;
        this.sensorType = sensorType;
        this.timestamp = timestamp;
        this.value = value;
    }

    /**
     * Validates that the value type matches the sensor type.
     */
    public boolean isValueTypeValid() {
        return switch (sensorType.getValueType()) {
            case SCALAR -> value instanceof com.iot.common.model.sensor.ScalarValue;
            case VIBRATION -> value instanceof com.iot.common.model.sensor.VibrationValue;
            case POWER -> value instanceof com.iot.common.model.sensor.PowerValue;
            case BOOLEAN -> value instanceof com.iot.common.model.sensor.BooleanValue;
        };
    }

    /**
     * Converts to AnalyticsMessage for Kafka.
     */
    public AnalyticsMessage toAnalyticsMessage() {
        return new AnalyticsMessage(
            deviceId,
            deviceType,
            sensorId,
            sensorType,
            timestamp,
            sensorType.getUnit(),
            value
        );
    }
}
