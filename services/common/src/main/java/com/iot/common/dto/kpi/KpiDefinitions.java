package com.iot.common.dto.kpi;

/**
 * Standard KPI definitions with names, units, and default thresholds.
 */
public final class KpiDefinitions {

    private KpiDefinitions() {} // Prevent instantiation

    // Temperature KPIs
    public static final String TEMP_AVG = "temperature_avg";
    public static final String TEMP_MAX = "temperature_max";
    public static final String TEMP_MIN = "temperature_min";
    public static final String TEMP_RATE_OF_CHANGE = "temperature_rate_of_change";

    // Vibration KPIs
    public static final String VIBRATION_RMS = "vibration_rms";
    public static final String VIBRATION_PEAK = "vibration_peak";
    public static final String VIBRATION_CREST_FACTOR = "vibration_crest_factor";

    // Power KPIs
    public static final String POWER_AVG = "power_avg";
    public static final String POWER_MAX = "power_max";
    public static final String POWER_FACTOR_AVG = "power_factor_avg";
    public static final String ENERGY_CONSUMPTION = "energy_consumption";

    // Operational KPIs
    public static final String UPTIME_PERCENT = "uptime_percent";
    public static final String AVAILABILITY = "availability";
    public static final String THROUGHPUT = "throughput";

    // Composite KPIs
    public static final String MACHINE_HEALTH_SCORE = "machine_health_score";
    public static final String ENERGY_EFFICIENCY = "energy_efficiency";

    /**
     * Default warning thresholds by KPI name.
     */
    public static class WarningThresholds {
        public static final double TEMP_HIGH = 70.0;        // °C
        public static final double TEMP_LOW = 5.0;          // °C
        public static final double VIBRATION_RMS = 1.5;     // g
        public static final double POWER_FACTOR_LOW = 0.85; // ratio
        public static final double UPTIME_LOW = 95.0;       // %
    }

    /**
     * Default critical thresholds by KPI name.
     */
    public static class CriticalThresholds {
        public static final double TEMP_HIGH = 85.0;        // °C
        public static final double TEMP_LOW = 0.0;          // °C
        public static final double VIBRATION_RMS = 2.5;     // g
        public static final double POWER_FACTOR_LOW = 0.70; // ratio
        public static final double UPTIME_LOW = 90.0;       // %
    }
}
