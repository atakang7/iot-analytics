package com.iot.common.model.sensor;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;

/**
 * Represents binary/boolean sensor values.
 * Used for: proximity (detected/not detected), contact (open/closed) sensors.
 */
public record BooleanValue(
    @NotNull
    @JsonProperty("state")
    Boolean state
) implements SensorValue {

    @JsonCreator
    public BooleanValue(
        @JsonProperty("state") Boolean state
    ) {
        this.state = state;
    }

    @Override
    public String toJsonString() {
        return String.format("{\"state\":%s}", state);
    }

    /**
     * Returns true if state is active (detected/closed).
     */
    public boolean isActive() {
        return Boolean.TRUE.equals(state);
    }

    /**
     * Factory methods for convenience.
     */
    public static BooleanValue of(boolean state) {
        return new BooleanValue(state);
    }

    public static BooleanValue active() {
        return new BooleanValue(true);
    }

    public static BooleanValue inactive() {
        return new BooleanValue(false);
    }
}
