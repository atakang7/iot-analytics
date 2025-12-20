package com.iot.common.model.sensor;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;

/**
 * Represents electrical power meter readings.
 * Contains voltage, current, power, and power factor.
 */
public record PowerValue(
    @NotNull
    @JsonProperty("voltage")
    Double voltage,  // Volts (V)

    @NotNull
    @JsonProperty("current")
    Double current,  // Amperes (A)

    @NotNull
    @JsonProperty("power")
    Double power,    // Watts (W)

    @NotNull
    @DecimalMin("0.0")
    @DecimalMax("1.0")
    @JsonProperty("powerFactor")
    Double powerFactor  // 0.0 to 1.0
) implements SensorValue {

    @JsonCreator
    public PowerValue(
        @JsonProperty("voltage") Double voltage,
        @JsonProperty("current") Double current,
        @JsonProperty("power") Double power,
        @JsonProperty("powerFactor") Double powerFactor
    ) {
        this.voltage = voltage;
        this.current = current;
        this.power = power;
        this.powerFactor = powerFactor;
    }

    @Override
    public String toJsonString() {
        return String.format(
            "{\"voltage\":%s,\"current\":%s,\"power\":%s,\"powerFactor\":%s}",
            voltage, current, power, powerFactor
        );
    }

    /**
     * Calculates apparent power (VA).
     * Apparent Power = Voltage × Current
     */
    public double apparentPower() {
        return voltage * current;
    }

    /**
     * Calculates reactive power (VAR).
     * Reactive Power = sqrt(Apparent² - Real²)
     */
    public double reactivePower() {
        double apparent = apparentPower();
        return Math.sqrt(apparent * apparent - power * power);
    }

    /**
     * Calculates efficiency compared to theoretical max.
     * Returns power factor as a percentage.
     */
    public double efficiencyPercent() {
        return powerFactor * 100.0;
    }

    /**
     * Factory method for convenience.
     */
    public static PowerValue of(double voltage, double current, double power, double powerFactor) {
        return new PowerValue(voltage, current, power, powerFactor);
    }
}
