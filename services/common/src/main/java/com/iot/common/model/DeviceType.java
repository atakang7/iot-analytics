package com.iot.common.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Supported device types in the IoT platform.
 */
public enum DeviceType {
    CNC_MACHINE("cnc_machine"),
    HVAC("hvac"),
    CONVEYOR("conveyor"),
    COMPRESSOR("compressor"),
    ACCESS_DOOR("access_door");

    private final String value;

    DeviceType(String value) {
        this.value = value;
    }

    @JsonValue
    public String getValue() {
        return value;
    }

    @JsonCreator
    public static DeviceType fromValue(String value) {
        for (DeviceType type : DeviceType.values()) {
            if (type.value.equalsIgnoreCase(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown device type: " + value);
    }
}
