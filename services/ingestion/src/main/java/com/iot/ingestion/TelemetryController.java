package com.iot.ingestion;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/telemetry")
public class TelemetryController {

    private final KafkaTemplate<String, String> kafka;
    private final ObjectMapper mapper;

    public TelemetryController(KafkaTemplate<String, String> kafka, ObjectMapper mapper) {
        this.kafka = kafka;
        this.mapper = mapper;
    }

    @PostMapping
    public ResponseEntity<Map<String, String>> ingest(@RequestBody Telemetry telemetry) {
        try {
            String json = mapper.writeValueAsString(telemetry);
            kafka.send("iot.telemetry", telemetry.deviceId(), json);
            return ResponseEntity.ok(Map.of("status", "ok", "deviceId", telemetry.deviceId()));
        } catch (JsonProcessingException e) {
            return ResponseEntity.badRequest().body(Map.of("status", "error", "message", e.getMessage()));
        }
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok!");
    }
}
