package com.iot.common.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Supported sensor types with their associated units.
 */
public enum SensorType {
    // Scalar sensors (single double value)
    TEMPERATURE("temperature", "celsius", ValueType.SCALAR),
    HUMIDITY("humidity", "percent", ValueType.SCALAR),
    PRESSURE("pressure", "bar", ValueType.SCALAR),
    SPEED("speed", "m_per_sec", ValueType.SCALAR),

    // Integer sensors
    SPINDLE_RPM("spindle_rpm", "rpm", ValueType.SCALAR),
    FAN_RPM("fan_rpm", "rpm", ValueType.SCALAR),

    // Complex sensors
    VIBRATION("vibration", "g", ValueType.VIBRATION),
    POWER("power", "mixed", ValueType.POWER),

    // Boolean sensors
    PROXIMITY("proximity", "boolean", ValueType.BOOLEAN),
    CONTACT("contact", "boolean", ValueType.BOOLEAN);

    private final String value;
    private final String unit;
    private final ValueType valueType;

    SensorType(String value, String unit, ValueType valueType) {
        this.value = value;
        this.unit = unit;
        this.valueType = valueType;
    }

    @JsonValue
    public String getValue() {
        return value;
    }

    public String getUnit() {
        return unit;
    }

    public ValueType getValueType() {
        return valueType;
    }

    @JsonCreator
    public static SensorType fromValue(String value) {
        for (SensorType type : SensorType.values()) {
            if (type.value.equalsIgnoreCase(value)) {
                return type;
            }
        }
        throw new IllegalArgumentException("Unknown sensor type: " + value);
    }

    /**
     * Categorizes the shape of sensor values.
     */
    public enum ValueType {
        SCALAR,     // Single numeric value
        VIBRATION,  // 3-axis x, y, z
        POWER,      // voltage, current, power, powerFactor
        BOOLEAN     // true/false
    }
}
