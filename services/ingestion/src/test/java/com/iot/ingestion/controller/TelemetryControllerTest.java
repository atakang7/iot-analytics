package com.iot.ingestion.controller;

import com.iot.common.dto.telemetry.TelemetryRequest;
import com.iot.common.dto.telemetry.TelemetryResponse;
import com.iot.common.model.DeviceType;
import com.iot.common.model.SensorType;
import com.iot.common.model.sensor.ScalarValue;
import com.iot.ingestion.service.TelemetryService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.reactive.WebFluxTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.reactive.server.WebTestClient;
import reactor.core.publisher.Mono;

import java.time.Instant;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@WebFluxTest(TelemetryController.class)
class TelemetryControllerTest {

    @Autowired
    private WebTestClient webTestClient;

    @MockBean
    private TelemetryService telemetryService;

    @Test
    void shouldAcceptValidTelemetry() {
        // Given
        TelemetryRequest request = new TelemetryRequest(
                "cnc-001",
                DeviceType.CNC_MACHINE,
                "temp-01",
                SensorType.TEMPERATURE,
                Instant.now(),
                ScalarValue.of(65.5)
        );

        when(telemetryService.processTelemetry(any()))
                .thenReturn(Mono.just(TelemetryResponse.success("cnc-001", "temp-01")));

        // When & Then
        webTestClient.post()
                .uri("/api/v1/telemetry")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue("""
                    {
                        "deviceId": "cnc-001",
                        "deviceType": "cnc_machine",
                        "sensorId": "temp-01",
                        "sensorType": "temperature",
                        "timestamp": "2024-01-15T10:30:00Z",
                        "value": {"@type": "scalar", "value": 65.5}
                    }
                    """)
                .exchange()
                .expectStatus().isAccepted()
                .expectBody()
                .jsonPath("$.status").isEqualTo("OK")
                .jsonPath("$.deviceId").isEqualTo("cnc-001");
    }

    @Test
    void shouldRejectInvalidDeviceType() {
        webTestClient.post()
                .uri("/api/v1/telemetry")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue("""
                    {
                        "deviceId": "cnc-001",
                        "deviceType": "invalid_type",
                        "sensorId": "temp-01",
                        "sensorType": "temperature",
                        "timestamp": "2024-01-15T10:30:00Z",
                        "value": {"@type": "scalar", "value": 65.5}
                    }
                    """)
                .exchange()
                .expectStatus().isBadRequest();
    }

    @Test
    void shouldRejectMissingFields() {
        webTestClient.post()
                .uri("/api/v1/telemetry")
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue("""
                    {
                        "deviceId": "cnc-001"
                    }
                    """)
                .exchange()
                .expectStatus().isBadRequest();
    }

    @Test
    void healthCheckShouldReturnOk() {
        webTestClient.get()
                .uri("/api/v1/telemetry/health")
                .exchange()
                .expectStatus().isOk()
                .expectBody(String.class).isEqualTo("OK");
    }
}
