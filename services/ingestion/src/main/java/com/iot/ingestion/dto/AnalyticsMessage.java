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
public class AnalyticsMessage {

    private UUID id;
    private UUID deviceId;
    private String metricName;
    private Double metricValue;
    private String unit;
    private Instant timestamp;
    private String messageType;
}
