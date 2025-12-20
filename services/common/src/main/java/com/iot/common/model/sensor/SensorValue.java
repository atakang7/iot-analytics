package com.iot.common.model.sensor;

import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;

/**
 * Sealed interface for all sensor value types.
 * Jackson uses the @type field to determine which concrete class to deserialize.
 */
@JsonTypeInfo(
    use = JsonTypeInfo.Id.NAME,
    include = JsonTypeInfo.As.PROPERTY,
    property = "@type"
)
@JsonSubTypes({
    @JsonSubTypes.Type(value = ScalarValue.class, name = "scalar"),
    @JsonSubTypes.Type(value = VibrationValue.class, name = "vibration"),
    @JsonSubTypes.Type(value = PowerValue.class, name = "power"),
    @JsonSubTypes.Type(value = BooleanValue.class, name = "boolean")
})
public sealed interface SensorValue permits ScalarValue, VibrationValue, PowerValue, BooleanValue {
    
    /**
     * Returns a JSON-friendly representation for Flink SQL processing.
     */
    String toJsonString();
}
