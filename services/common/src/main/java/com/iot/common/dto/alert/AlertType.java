package com.iot.common.dto.alert;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Predefined alert types for common anomalies.
 */
public enum AlertType {
    // Temperature alerts
    HIGH_TEMPERATURE("high_temperature"),
    LOW_TEMPERATURE("low_temperature"),
    RAPID_TEMPERATURE_CHANGE("rapid_temperature_change"),

    // Vibration alerts
    HIGH_VIBRATION("high_vibration"),
    VIBRATION_ANOMALY("vibration_anomaly"),

    // Power alerts
    POWER_OVERCURRENT("power_overcurrent"),
    POWER_UNDERVOLTAGE("power_undervoltage"),
    POWER_OVERVOLTAGE("power_overvoltage"),
    LOW_POWER_FACTOR("low_power_factor"),

    // Pressure alerts
    HIGH_PRESSURE("high_pressure"),
    LOW_PRESSURE("low_pressure"),

    // Operational alerts
    DEVICE_OFFLINE("device_offline"),
    SENSOR_MALFUNCTION("sensor_malfunction"),
    THRESHOLD_BREACH("threshold_breach"),

    // Door/access alerts
    DOOR_OPEN_TOO_LONG("door_open_too_long"),
    UNAUTHORIZED_ACCESS("unauthorized_access");

    private final String value;

    AlertType(String value) {
        this.value = value;
    }

    @JsonValue
    public String getValue() {
        return value;
    }

    @JsonCreator
    public static AlertType fromValue(String value) {
        for (AlertType type : AlertType.values()) {
            if (type.value.equalsIgnoreCase(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown alert type: " + value);
    }
}
