package com.iot.ingestion.exception;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;
import java.util.List;

/**
 * Standard error response format.
 */
public record ErrorResponse(
    @JsonProperty("status")
    int status,

    @JsonProperty("error")
    String error,

    @JsonProperty("message")
    String message,

    @JsonProperty("path")
    String path,

    @JsonProperty("timestamp")
    Instant timestamp,

    @JsonProperty("details")
    List<String> details
) {
    public static ErrorResponse of(int status, String error, String message, String path) {
        return new ErrorResponse(status, error, message, path, Instant.now(), List.of());
    }

    public static ErrorResponse of(int status, String error, String message, String path, List<String> details) {
        return new ErrorResponse(status, error, message, path, Instant.now(), details);
    }
}
