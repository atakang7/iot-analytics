package com.iot.common.dto.telemetry;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Batch telemetry request for sending multiple readings at once.
 * Useful for devices that buffer readings or high-frequency sensors.
 *
 * Example JSON:
 * {
 *   "readings": [
 *     {"deviceId": "cnc-001", "sensorType": "temperature", ...},
 *     {"deviceId": "cnc-001", "sensorType": "vibration", ...}
 *   ]
 * }
 */
public record BatchTelemetryRequest(
    @NotEmpty(message = "Readings list cannot be empty")
    @Size(max = 1000, message = "Maximum 1000 readings per batch")
    @Valid
    @JsonProperty("readings")
    List<TelemetryRequest> readings
) {
    @JsonCreator
    public BatchTelemetryRequest(
        @JsonProperty("readings") List<TelemetryRequest> readings
    ) {
        this.readings = readings != null ? List.copyOf(readings) : List.of();
    }

    /**
     * Returns the number of readings in the batch.
     */
    public int size() {
        return readings.size();
    }

    /**
     * Converts all readings to AnalyticsMessages.
     */
    public List<AnalyticsMessage> toAnalyticsMessages() {
        return readings.stream()
            .map(TelemetryRequest::toAnalyticsMessage)
            .toList();
    }
}
