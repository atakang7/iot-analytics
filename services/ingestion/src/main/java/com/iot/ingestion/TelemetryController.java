package com.iot.ingestion;

import jakarta.validation.Valid;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;
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

    private static final Logger log = LoggerFactory.getLogger(TelemetryController.class);
    private final KafkaTemplate<String, String> kafka;
    private final JsonMapper mapper;
    private final String topic;

    public TelemetryController(
            KafkaTemplate<String, String> kafka, JsonMapper mapper,
            @Value("${iot.telemetry.topic}") String topic) {
        this.kafka = kafka;
        this.mapper = mapper;
        this.topic = topic;
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

        try {
            return kafka.send(topic, telemetry.deviceId(), json)
                    .handle((ack, failure) -> {
                        if (failure != null) {
                            log.warn("Kafka publish failed", failure);
                            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                                    .body(Map.of("status", "publish_failed"));
                        }
                        return ResponseEntity.accepted()
                                .body(Map.of("status", "accepted", "deviceId", telemetry.deviceId()));
                    });
        } catch (RuntimeException exception) {
            log.warn("Kafka publish failed", exception);
            return CompletableFuture.completedFuture(
                    ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                            .body(Map.of("status", "publish_failed")));
        }
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "ok");
    }
}
