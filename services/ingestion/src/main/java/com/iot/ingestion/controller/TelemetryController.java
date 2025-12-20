package com.iot.ingestion.controller;

import com.iot.common.dto.telemetry.BatchTelemetryRequest;
import com.iot.common.dto.telemetry.BatchTelemetryResponse;
import com.iot.common.dto.telemetry.TelemetryRequest;
import com.iot.common.dto.telemetry.TelemetryResponse;
import com.iot.ingestion.service.TelemetryService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

/**
 * REST controller for ingesting telemetry data from IoT devices.
 * 
 * Endpoints:
 * - POST /api/v1/telemetry - Single telemetry reading
 * - POST /api/v1/telemetry/batch - Batch of telemetry readings
 */
@RestController
@RequestMapping("/api/v1/telemetry")
public class TelemetryController {

    private static final Logger log = LoggerFactory.getLogger(TelemetryController.class);

    private final TelemetryService telemetryService;

    public TelemetryController(TelemetryService telemetryService) {
        this.telemetryService = telemetryService;
    }

    /**
     * Ingest a single telemetry reading.
     */
    @PostMapping(
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public Mono<ResponseEntity<TelemetryResponse>> ingestTelemetry(
            @Valid @RequestBody TelemetryRequest request) {
        
        log.debug("Received telemetry: device={}, sensor={}, type={}",
                request.deviceId(), request.sensorId(), request.sensorType());

        return telemetryService.processTelemetry(request)
                .map(response -> {
                    if ("OK".equals(response.status())) {
                        return ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
                    } else {
                        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
                    }
                });
    }

    /**
     * Ingest a batch of telemetry readings.
     */
    @PostMapping(
            path = "/batch",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.APPLICATION_JSON_VALUE
    )
    public Mono<ResponseEntity<BatchTelemetryResponse>> ingestBatch(
            @Valid @RequestBody BatchTelemetryRequest request) {
        
        log.debug("Received batch telemetry: count={}", request.size());

        return telemetryService.processBatch(request)
                .map(response -> switch (response.status()) {
                    case "OK" -> ResponseEntity.status(HttpStatus.ACCEPTED).body(response);
                    case "PARTIAL" -> ResponseEntity.status(HttpStatus.MULTI_STATUS).body(response);
                    default -> ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
                });
    }

    /**
     * Health check endpoint for simple connectivity test.
     */
    @GetMapping("/health")
    public Mono<ResponseEntity<String>> health() {
        return Mono.just(ResponseEntity.ok("OK"));
    }
}
