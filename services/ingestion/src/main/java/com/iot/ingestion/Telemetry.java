package com.iot.ingestion;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;

/** Wire-level reading. Keep numeric rules consistent with Python common.models.Telemetry. */
public record Telemetry(
        @NotBlank @Size(max = 128) String deviceId,
        @NotBlank @Size(max = 128) String deviceType,
        @NotBlank @Size(max = 128) String sensorId,
        @NotBlank @Size(max = 128) String sensorType,
        @NotNull Instant timestamp,
        @NotBlank @Size(max = 64) String unit,
        @NotEmpty Map<String, Object> value) {

    @AssertTrue(message = "value must contain finite numeric sensor readings")
    public boolean isMeasurementValid() {
        if (sensorType == null || value == null || value.isEmpty()) {
            return false;
        }
        if ("vibration".equals(sensorType)) {
            boolean seenAxis = false;
            for (String axis : new String[]{"x", "y", "z"}) {
                if (value.containsKey(axis)) {
                    seenAxis = true;
                    if (!finite(value.get(axis))) {
                        return false;
                    }
                }
            }
            return seenAxis;
        }
        return finite(value.get("value"));
    }

    private static boolean finite(Object candidate) {
        return candidate instanceof Number number && Double.isFinite(number.doubleValue());
    }
}
