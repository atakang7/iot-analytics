package com.iot.ingestion.controller;

import com.iot.ingestion.dto.*;
import com.iot.ingestion.service.TelemetryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/telemetry")
@RequiredArgsConstructor
@Tag(name = "Telemetry Ingestion", description = "APIs for ingesting and querying IoT telemetry data")
public class TelemetryController {

    private final TelemetryService telemetryService;

    @PostMapping
    @Operation(summary = "Ingest telemetry", description = "Ingest a single telemetry data point")
    public ResponseEntity<TelemetryResponse> ingestTelemetry(@Valid @RequestBody TelemetryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(telemetryService.ingestTelemetry(request));
    }

    @PostMapping("/batch")
    @Operation(summary = "Ingest batch telemetry", description = "Ingest multiple telemetry data points in a batch")
    public ResponseEntity<BatchTelemetryResponse> ingestBatch(@Valid @RequestBody BatchTelemetryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(telemetryService.ingestBatch(request));
    }

    @GetMapping("/device/{deviceId}")
    @Operation(summary = "Get device telemetry", description = "Get telemetry data for a specific device")
    public ResponseEntity<Page<TelemetryResponse>> getDeviceTelemetry(
            @PathVariable UUID deviceId,
            @PageableDefault(size = 50) Pageable pageable) {
        return ResponseEntity.ok(telemetryService.getTelemetryByDevice(deviceId, pageable));
    }

    @GetMapping("/device/{deviceId}/range")
    @Operation(summary = "Get telemetry by time range", description = "Get telemetry data for a device within a time range")
    public ResponseEntity<List<TelemetryResponse>> getTelemetryByRange(
            @PathVariable UUID deviceId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant end) {
        return ResponseEntity.ok(telemetryService.getTelemetryByDeviceAndTimeRange(deviceId, start, end));
    }

    @GetMapping("/device/{deviceId}/metrics")
    @Operation(summary = "Get device metrics", description = "Get list of metrics available for a device")
    public ResponseEntity<List<String>> getDeviceMetrics(@PathVariable UUID deviceId) {
        return ResponseEntity.ok(telemetryService.getMetricsByDevice(deviceId));
    }

    @GetMapping("/device/{deviceId}/stats")
    @Operation(summary = "Get telemetry statistics", description = "Get statistical summary for a device metric")
    public ResponseEntity<TelemetryStatsResponse> getTelemetryStats(
            @PathVariable UUID deviceId,
            @RequestParam String metricName,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant start,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant end) {
        
        // Default to last 24 hours if not specified
        if (start == null) {
            start = Instant.now().minus(24, ChronoUnit.HOURS);
        }
        if (end == null) {
            end = Instant.now();
        }
        
        return ResponseEntity.ok(telemetryService.getStats(deviceId, metricName, start, end));
    }
}
