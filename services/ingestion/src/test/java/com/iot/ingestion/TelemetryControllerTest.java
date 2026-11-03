package com.iot.ingestion;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import tools.jackson.databind.json.JsonMapper;
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
        var result = new TelemetryController(kafka, JsonMapper.builder().build(), "iot.telemetry")
                .ingest(telemetry).get();
        assertEquals(HttpStatus.ACCEPTED, result.getStatusCode());
        assertEquals("accepted", result.getBody().get("status"));
    }

    @Test
    void acceptsConfiguredTopic() throws Exception {
        when(kafka.send(eq("iot.custom"), eq("device-1"), anyString()))
                .thenReturn(CompletableFuture.completedFuture(null));
        var result = new TelemetryController(kafka, JsonMapper.builder().build(), "iot.custom")
                .ingest(telemetry).get();
        assertEquals(HttpStatus.ACCEPTED, result.getStatusCode());
        verify(kafka).send(eq("iot.custom"), eq("device-1"), anyString());
    }

    @Test
    void rejectsSynchronousKafkaFailure() throws Exception {
        when(kafka.send(eq("iot.telemetry"), eq("device-1"), anyString()))
                .thenThrow(new org.apache.kafka.common.errors.TimeoutException("broker timeout"));
        var result = new TelemetryController(kafka, JsonMapper.builder().build(), "iot.telemetry")
                .ingest(telemetry).get();
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, result.getStatusCode());
        assertEquals("publish_failed", result.getBody().get("status"));
    }

    @Test
    void rejectsUnavailableKafkaWithoutFalseSuccess() throws Exception {
        CompletableFuture<org.springframework.kafka.support.SendResult<String, String>> failed =
                new CompletableFuture<>();
        failed.completeExceptionally(new RuntimeException("broker unavailable"));
        when(kafka.send(eq("iot.telemetry"), eq("device-1"), anyString()))
                .thenReturn(failed);
        var result = new TelemetryController(kafka, JsonMapper.builder().build(), "iot.telemetry")
                .ingest(telemetry).get();
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, result.getStatusCode());
        assertEquals("publish_failed", result.getBody().get("status"));
    }
}
