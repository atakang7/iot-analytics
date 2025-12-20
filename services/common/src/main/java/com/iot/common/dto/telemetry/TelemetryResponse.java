package com.iot.common.dto.telemetry;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;

/**
 * Response for successful telemetry ingestion.
 */
public record TelemetryResponse(
    @JsonProperty("status")
    String status,

    @JsonProperty("deviceId")
    String deviceId,

    @JsonProperty("sensorId")
    String sensorId,

    @JsonProperty("receivedAt")
    Instant receivedAt,

    @JsonProperty("message")
    String message
) {
    public static TelemetryResponse success(String deviceId, String sensorId) {
        return new TelemetryResponse(
            "OK",
            deviceId,
            sensorId,
            Instant.now(),
            "Telemetry data received successfully"
        );
    }

    public static TelemetryResponse error(String deviceId, String sensorId, String message) {
        return new TelemetryResponse(
            "ERROR",
            deviceId,
            sensorId,
            Instant.now(),
            message
        );
    }
}
