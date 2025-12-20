package com.iot.common.model.sensor;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;

/**
 * Represents 3-axis accelerometer/vibration sensor data.
 * Units: g (gravitational acceleration)
 * Typical range: -16g to +16g
 */
public record VibrationValue(
    @NotNull
    @JsonProperty("x")
    Double x,

    @NotNull
    @JsonProperty("y")
    Double y,

    @NotNull
    @JsonProperty("z")
    Double z
) implements SensorValue {

    @JsonCreator
    public VibrationValue(
        @JsonProperty("x") Double x,
        @JsonProperty("y") Double y,
        @JsonProperty("z") Double z
    ) {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    @Override
    public String toJsonString() {
        return String.format("{\"x\":%s,\"y\":%s,\"z\":%s}", x, y, z);
    }

    /**
     * Calculates the Root Mean Square (RMS) magnitude.
     * RMS = sqrt(x² + y² + z²)
     */
    public double rms() {
        return Math.sqrt(x * x + y * y + z * z);
    }

    /**
     * Calculates magnitude (same as RMS for single reading).
     */
    public double magnitude() {
        return rms();
    }

    /**
     * Factory method for convenience.
     */
    public static VibrationValue of(double x, double y, double z) {
        return new VibrationValue(x, y, z);
    }
}
