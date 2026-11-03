package com.iot.ingestion;

import static org.junit.jupiter.api.Assertions.*;

import jakarta.validation.Validation;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.Test;

class TelemetryContractTest {
    private static final Instant TIME = Instant.parse("2026-11-03T10:00:00Z");

    private Telemetry reading(String sensorType, Map<String, Object> value) {
        return new Telemetry("motor-1", "motor", "sensor-1", sensorType, TIME,
                "celsius", value);
    }

    private boolean accepted(Telemetry reading) {
        try (var factory = Validation.buildDefaultValidatorFactory()) {
            return factory.getValidator().validate(reading).isEmpty();
        }
    }

    @Test
    void validatesFiniteScalarReadings() {
        assertTrue(accepted(reading("temperature", Map.of("value", 0.0))));
        assertFalse(accepted(reading("temperature", Map.of("value", "99"))));
        assertFalse(accepted(reading("temperature", Map.of("value", true))));
        assertFalse(accepted(reading("temperature", Map.of("value", Double.NaN))));
        assertFalse(accepted(reading("temperature", Map.of("value", Double.POSITIVE_INFINITY))));
    }

    @Test
    void validatesVibrationAxes() {
        assertTrue(accepted(reading("vibration", Map.of("x", 3.0, "y", 4.0))));
        assertFalse(accepted(reading("vibration", Map.of("note", "missing axes"))));
        assertFalse(accepted(reading("vibration", Map.of("x", "NaN"))));
        assertFalse(accepted(reading("vibration", Map.of("z", Double.NEGATIVE_INFINITY))));
    }

    @Test
    void rejectsUnboundedIdentifiersAndMissingUnits() {
        var longName = "x".repeat(129);
        assertFalse(accepted(new Telemetry(longName, "motor", "sensor-1", "temperature",
                TIME, "celsius", Map.of("value", 1))));
        assertFalse(accepted(new Telemetry("motor", "motor", "sensor", "temperature",
                TIME, " ", Map.of("value", 1))));
    }
}
