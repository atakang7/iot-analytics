package com.iot.ingestion.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatchTelemetryRequest {

    @NotEmpty(message = "At least one telemetry data point is required")
    @Valid
    private List<TelemetryRequest> data;
}
