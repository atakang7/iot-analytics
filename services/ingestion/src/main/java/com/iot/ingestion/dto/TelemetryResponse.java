package com.iot.ingestion.dto;

import com.iot.ingestion.model.TelemetryData;
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
public class TelemetryResponse {

    private UUID id;
    private UUID deviceId;
    private String metricName;
    private Double metricValue;
    private String unit;
    private Instant timestamp;
    private Instant receivedAt;
    private Boolean processed;

    public static TelemetryResponse fromEntity(TelemetryData telemetry) {
        return TelemetryResponse.builder()
                .id(telemetry.getId())
                .deviceId(telemetry.getDeviceId())
                .metricName(telemetry.getMetricName())
                .metricValue(telemetry.getMetricValue())
                .unit(telemetry.getUnit())
                .timestamp(telemetry.getTimestamp())
                .receivedAt(telemetry.getReceivedAt())
                .processed(telemetry.getProcessed())
                .build();
    }
}
