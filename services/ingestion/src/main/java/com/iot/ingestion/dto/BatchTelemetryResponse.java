package com.iot.ingestion.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BatchTelemetryResponse {

    private int received;
    private int accepted;
    private int rejected;
    private String message;
}
