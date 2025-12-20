package com.iot.common.dto.alert;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Alert severity levels.
 */
public enum AlertSeverity {
    INFO("info"),
    WARNING("warning"),
    CRITICAL("critical");

    private final String value;

    AlertSeverity(String value) {
        this.value = value;
    }

    @JsonValue
    public String getValue() {
        return value;
    }

    @JsonCreator
    public static AlertSeverity fromValue(String value) {
        for (AlertSeverity severity : AlertSeverity.values()) {
            if (severity.value.equalsIgnoreCase(value)) {
                return severity;
            }
        }
        throw new IllegalArgumentException("Unknown severity: " + value);
    }
}
