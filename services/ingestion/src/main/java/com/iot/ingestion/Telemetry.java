package com.iot.ingestion;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.Map;

/** Shared telemetry envelope consumed by all Python workers. */
public record Telemetry(
        @NotBlank String deviceId,
        @NotBlank String deviceType,
        @NotBlank String sensorId,
        @NotBlank String sensorType,
        @NotNull Instant timestamp,
        @NotBlank String unit,
        @NotEmpty Map<String, Object> value) {
}
