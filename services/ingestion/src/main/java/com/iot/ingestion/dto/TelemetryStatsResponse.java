package com.iot.ingestion.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TelemetryStatsResponse {

    private UUID deviceId;
    private String metricName;
    private Instant startTime;
    private Instant endTime;
    private Double average;
    private Double max;
    private Double min;
}
