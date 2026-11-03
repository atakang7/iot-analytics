package com.iot.ingestion;

import tools.jackson.core.JacksonException;
import org.springframework.beans.factory.annotation.Value;
import tools.jackson.databind.json.JsonMapper;
import jakarta.validation.Valid;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/telemetry")
public class TelemetryController {

    private final KafkaTemplate<String, String> kafka;
    private final JsonMapper mapper;
    private final String telemetryTopic;

    public TelemetryController(KafkaTemplate<String, String> kafka, JsonMapper mapper,
            @Value("${iot.telemetry-topic:iot.telemetry}") String telemetryTopic) {
        this.kafka = kafka;
        this.mapper = mapper;
        this.telemetryTopic = telemetryTopic;
    }

    @PostMapping
    public CompletableFuture<ResponseEntity<Map<String, String>>> ingest(
            @Valid @RequestBody Telemetry telemetry) {
        final String json;
        try {
            json = mapper.writeValueAsString(telemetry);
        } catch (JacksonException exception) {
            return CompletableFuture.completedFuture(
                    ResponseEntity.badRequest().body(Map.of("status", "invalid_payload")));
        }

        return kafka.send(telemetryTopic, telemetry.deviceId(), json)
                .handle((ack, failure) -> {
                    if (failure != null) {
                        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                                .body(Map.of("status", "publish_failed"));
                    }
                    return ResponseEntity.accepted()
                            .body(Map.of("status", "accepted", "deviceId", telemetry.deviceId()));
                });
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}
