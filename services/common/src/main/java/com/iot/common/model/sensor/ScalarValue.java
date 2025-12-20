package com.iot.common.model.sensor;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;

/**
 * Represents a single numeric sensor value.
 * Used for: temperature, humidity, pressure, speed, rpm sensors.
 */
public record ScalarValue(
    @NotNull
    @JsonProperty("value")
    Double value
) implements SensorValue {

    @JsonCreator
    public ScalarValue(
        @JsonProperty("value") Double value
    ) {
        this.value = value;
    }

    @Override
    public String toJsonString() {
        return String.format("{\"value\":%s}", value);
    }

    /**
     * Factory method for convenience.
     */
    public static ScalarValue of(double value) {
        return new ScalarValue(value);
    }
}
