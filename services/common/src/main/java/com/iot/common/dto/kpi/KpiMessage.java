package com.iot.common.dto.kpi;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.iot.common.model.DeviceType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.Instant;

/**
 * KPI message representing a computed metric from Flink.
 * Written to Postgres for historical analysis and dashboarding.
 *
 * Example JSON:
 * {
 *   "deviceId": "cnc-001",
 *   "deviceType": "cnc_machine",
 *   "kpiName": "vibration_rms",
 *   "kpiValue": 1.25,
 *   "unit": "g",
 *   "windowStart": "2024-01-15T10:30:00Z",
 *   "windowEnd": "2024-01-15T10:31:00Z",
 *   "sampleCount": 6000,
 *   "createdAt": "2024-01-15T10:31:05Z"
 * }
 */
public record KpiMessage(
    @NotBlank
    @JsonProperty("deviceId")
    String deviceId,

    @NotNull
    @JsonProperty("deviceType")
    DeviceType deviceType,

    @NotBlank
    @JsonProperty("kpiName")
    String kpiName,

    @NotNull
    @JsonProperty("kpiValue")
    Double kpiValue,

    @JsonProperty("unit")
    String unit,

    @NotNull
    @JsonProperty("windowStart")
    Instant windowStart,

    @NotNull
    @JsonProperty("windowEnd")
    Instant windowEnd,

    @JsonProperty("sampleCount")
    Long sampleCount,

    @NotNull
    @JsonProperty("createdAt")
    Instant createdAt
) {
    @JsonCreator
    public KpiMessage(
        @JsonProperty("deviceId") String deviceId,
        @JsonProperty("deviceType") DeviceType deviceType,
        @JsonProperty("kpiName") String kpiName,
        @JsonProperty("kpiValue") Double kpiValue,
        @JsonProperty("unit") String unit,
        @JsonProperty("windowStart") Instant windowStart,
        @JsonProperty("windowEnd") Instant windowEnd,
        @JsonProperty("sampleCount") Long sampleCount,
        @JsonProperty("createdAt") Instant createdAt
    ) {
        this.deviceId = deviceId;
        this.deviceType = deviceType;
        this.kpiName = kpiName;
        this.kpiValue = kpiValue;
        this.unit = unit;
        this.windowStart = windowStart;
        this.windowEnd = windowEnd;
        this.sampleCount = sampleCount;
        this.createdAt = createdAt;
    }

    /**
     * Builder for creating KpiMessage instances.
     */
    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private String deviceId;
        private DeviceType deviceType;
        private String kpiName;
        private Double kpiValue;
        private String unit;
        private Instant windowStart;
        private Instant windowEnd;
        private Long sampleCount;
        private Instant createdAt;

        public Builder deviceId(String deviceId) { this.deviceId = deviceId; return this; }
        public Builder deviceType(DeviceType deviceType) { this.deviceType = deviceType; return this; }
        public Builder kpiName(String kpiName) { this.kpiName = kpiName; return this; }
        public Builder kpiValue(Double kpiValue) { this.kpiValue = kpiValue; return this; }
        public Builder unit(String unit) { this.unit = unit; return this; }
        public Builder windowStart(Instant windowStart) { this.windowStart = windowStart; return this; }
        public Builder windowEnd(Instant windowEnd) { this.windowEnd = windowEnd; return this; }
        public Builder sampleCount(Long sampleCount) { this.sampleCount = sampleCount; return this; }
        public Builder createdAt(Instant createdAt) { this.createdAt = createdAt; return this; }

        public KpiMessage build() {
            return new KpiMessage(
                deviceId, deviceType, kpiName, kpiValue, unit,
                windowStart, windowEnd, sampleCount,
                createdAt != null ? createdAt : Instant.now()
            );
        }
    }
}
