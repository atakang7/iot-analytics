package com.iot.common.dto.telemetry;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;
import java.util.List;

/**
 * Response for batch telemetry ingestion.
 */
public record BatchTelemetryResponse(
    @JsonProperty("status")
    String status,

    @JsonProperty("total")
    int total,

    @JsonProperty("accepted")
    int accepted,

    @JsonProperty("rejected")
    int rejected,

    @JsonProperty("receivedAt")
    Instant receivedAt,

    @JsonProperty("errors")
    List<BatchError> errors
) {
    public record BatchError(
        @JsonProperty("index")
        int index,

        @JsonProperty("deviceId")
        String deviceId,

        @JsonProperty("message")
        String message
    ) {}

    public static BatchTelemetryResponse success(int total) {
        return new BatchTelemetryResponse(
            "OK",
            total,
            total,
            0,
            Instant.now(),
            List.of()
        );
    }

    public static BatchTelemetryResponse partial(int total, int accepted, List<BatchError> errors) {
        return new BatchTelemetryResponse(
            "PARTIAL",
            total,
            accepted,
            total - accepted,
            Instant.now(),
            errors
        );
    }

    public static BatchTelemetryResponse error(int total, String message) {
        return new BatchTelemetryResponse(
            "ERROR",
            total,
            0,
            total,
            Instant.now(),
            List.of(new BatchError(0, null, message))
        );
    }
}
