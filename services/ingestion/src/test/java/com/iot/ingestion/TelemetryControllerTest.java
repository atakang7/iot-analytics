package com.iot.ingestion;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.kafka.core.KafkaTemplate;

class TelemetryControllerTest {
    @SuppressWarnings("unchecked")
    private final KafkaTemplate<String, String> kafka = mock(KafkaTemplate.class);
    private final Telemetry telemetry = new Telemetry(
            "device-1", "motor", "sensor-1", "temperature",
            Instant.parse("2026-11-03T10:00:00Z"), "celsius", Map.of("value", 80.0));

    @Test
    void returns202OnlyAfterKafkaAcknowledges() throws Exception {
        when(kafka.send(eq("iot.telemetry"), eq("device-1"), anyString()))
                .thenReturn(CompletableFuture.completedFuture(null));
        var result = new TelemetryController(kafka, new ObjectMapper().findAndRegisterModules())
                .ingest(telemetry).get();
        assertEquals(HttpStatus.ACCEPTED, result.getStatusCode());
        assertEquals("accepted", result.getBody().get("status"));
    }

    @Test
    void rejectsUnavailableKafkaWithoutFalseSuccess() throws Exception {
        CompletableFuture<org.springframework.kafka.support.SendResult<String, String>> failed =
                new CompletableFuture<>();
        failed.completeExceptionally(new RuntimeException("broker unavailable"));
        when(kafka.send(eq("iot.telemetry"), eq("device-1"), anyString()))
                .thenReturn(failed);
        var result = new TelemetryController(kafka, new ObjectMapper().findAndRegisterModules())
                .ingest(telemetry).get();
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, result.getStatusCode());
        assertEquals("publish_failed", result.getBody().get("status"));
    }
}
