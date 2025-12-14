package com.iot.ingestion.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.time.Duration;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DeviceRegistryClient {

    private final WebClient deviceRegistryWebClient;

    public void sendHeartbeat(UUID deviceId) {
        try {
            deviceRegistryWebClient.post()
                    .uri("/api/v1/devices/{id}/heartbeat", deviceId)
                    .retrieve()
                    .bodyToMono(Void.class)
                    .timeout(Duration.ofSeconds(5))
                    .onErrorResume(e -> {
                        log.warn("Heartbeat failed for device {}: {}", deviceId, e.getMessage());
                        return Mono.empty();
                    })
                    .subscribe();
        } catch (Exception e) {
            log.warn("Failed to send heartbeat for device {}: {}", deviceId, e.getMessage());
        }
    }

    public boolean deviceExists(UUID deviceId) {
        try {
            return Boolean.TRUE.equals(deviceRegistryWebClient.get()
                    .uri("/api/v1/devices/{id}", deviceId)
                    .retrieve()
                    .bodyToMono(Object.class)
                    .timeout(Duration.ofSeconds(5))
                    .map(response -> true)
                    .onErrorReturn(false)
                    .block());
        } catch (Exception e) {
            log.warn("Failed to check device existence for {}: {}", deviceId, e.getMessage());
            return false;
        }
    }
}
