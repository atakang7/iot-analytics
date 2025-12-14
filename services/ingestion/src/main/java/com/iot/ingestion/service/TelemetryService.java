package com.iot.ingestion.service;

import com.iot.ingestion.config.KafkaConfig;
import com.iot.ingestion.dto.*;
import com.iot.ingestion.model.TelemetryData;
import com.iot.ingestion.repository.TelemetryRepository;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@Slf4j
public class TelemetryService {

    private final TelemetryRepository telemetryRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;
    private final DeviceRegistryClient deviceRegistryClient;
    private final Counter telemetryReceivedCounter;
    private final Counter telemetryProcessedCounter;
    private final Counter telemetryRejectedCounter;

    @Value("${ingestion.batch.size:100}")
    private int batchSize;

    public TelemetryService(TelemetryRepository telemetryRepository,
                           KafkaTemplate<String, Object> kafkaTemplate,
                           DeviceRegistryClient deviceRegistryClient,
                           MeterRegistry meterRegistry) {
        this.telemetryRepository = telemetryRepository;
        this.kafkaTemplate = kafkaTemplate;
        this.deviceRegistryClient = deviceRegistryClient;
        
        this.telemetryReceivedCounter = Counter.builder("telemetry.received")
                .description("Number of telemetry data points received")
                .register(meterRegistry);
        this.telemetryProcessedCounter = Counter.builder("telemetry.processed")
                .description("Number of telemetry data points processed")
                .register(meterRegistry);
        this.telemetryRejectedCounter = Counter.builder("telemetry.rejected")
                .description("Number of telemetry data points rejected")
                .register(meterRegistry);
    }

    @Transactional
    public TelemetryResponse ingestTelemetry(TelemetryRequest request) {
        log.debug("Ingesting telemetry for device: {}", request.getDeviceId());
        telemetryReceivedCounter.increment();

        // Validate device exists and update heartbeat
        try {
            deviceRegistryClient.sendHeartbeat(request.getDeviceId());
        } catch (Exception e) {
            log.warn("Failed to send heartbeat to device registry for device: {}", request.getDeviceId(), e);
        }

        TelemetryData telemetry = TelemetryData.builder()
                .deviceId(request.getDeviceId())
                .metricName(request.getMetricName())
                .metricValue(request.getMetricValue())
                .unit(request.getUnit())
                .timestamp(request.getTimestamp() != null ? request.getTimestamp() : Instant.now())
                .build();

        TelemetryData saved = telemetryRepository.save(telemetry);
        
        // Send to analytics queue
        sendToAnalytics(saved);
        
        telemetryProcessedCounter.increment();
        return TelemetryResponse.fromEntity(saved);
    }

    @Transactional
    public BatchTelemetryResponse ingestBatch(BatchTelemetryRequest request) {
        log.info("Ingesting batch of {} telemetry points", request.getData().size());
        
        int received = request.getData().size();
        int accepted = 0;
        int rejected = 0;
        
        List<TelemetryData> telemetryList = new ArrayList<>();
        
        for (TelemetryRequest item : request.getData()) {
            try {
                telemetryReceivedCounter.increment();
                
                TelemetryData telemetry = TelemetryData.builder()
                        .deviceId(item.getDeviceId())
                        .metricName(item.getMetricName())
                        .metricValue(item.getMetricValue())
                        .unit(item.getUnit())
                        .timestamp(item.getTimestamp() != null ? item.getTimestamp() : Instant.now())
                        .build();
                
                telemetryList.add(telemetry);
                accepted++;
            } catch (Exception e) {
                log.error("Failed to process telemetry item: {}", e.getMessage());
                rejected++;
                telemetryRejectedCounter.increment();
            }
        }
        
        // Batch save
        List<TelemetryData> savedList = telemetryRepository.saveAll(telemetryList);
        
        // Send all to analytics
        savedList.forEach(this::sendToAnalytics);
        
        telemetryProcessedCounter.increment(accepted);
        
        // Update device heartbeats
        savedList.stream()
                .map(TelemetryData::getDeviceId)
                .distinct()
                .forEach(deviceId -> {
                    try {
                        deviceRegistryClient.sendHeartbeat(deviceId);
                    } catch (Exception e) {
                        log.warn("Failed to send heartbeat for device: {}", deviceId);
                    }
                });
        
        return BatchTelemetryResponse.builder()
                .received(received)
                .accepted(accepted)
                .rejected(rejected)
                .message(String.format("Processed %d of %d telemetry points", accepted, received))
                .build();
    }

    public Page<TelemetryResponse> getTelemetryByDevice(UUID deviceId, Pageable pageable) {
        return telemetryRepository.findByDeviceId(deviceId, pageable)
                .map(TelemetryResponse::fromEntity);
    }

    public List<TelemetryResponse> getTelemetryByDeviceAndTimeRange(UUID deviceId, Instant start, Instant end) {
        return telemetryRepository.findByDeviceIdAndTimestampBetween(deviceId, start, end)
                .stream()
                .map(TelemetryResponse::fromEntity)
                .collect(Collectors.toList());
    }

    public List<String> getMetricsByDevice(UUID deviceId) {
        return telemetryRepository.findDistinctMetricNamesByDeviceId(deviceId);
    }

    public TelemetryStatsResponse getStats(UUID deviceId, String metricName, Instant start, Instant end) {
        Double avg = telemetryRepository.getAverageMetricValue(deviceId, metricName, start, end);
        Double max = telemetryRepository.getMaxMetricValue(deviceId, metricName, start, end);
        Double min = telemetryRepository.getMinMetricValue(deviceId, metricName, start, end);
        
        return TelemetryStatsResponse.builder()
                .deviceId(deviceId)
                .metricName(metricName)
                .startTime(start)
                .endTime(end)
                .average(avg)
                .max(max)
                .min(min)
                .build();
    }

    private void sendToAnalytics(TelemetryData telemetry) {
        try {
            AnalyticsMessage message = AnalyticsMessage.builder()
                    .id(telemetry.getId())
                    .deviceId(telemetry.getDeviceId())
                    .metricName(telemetry.getMetricName())
                    .metricValue(telemetry.getMetricValue())
                    .unit(telemetry.getUnit())
                    .timestamp(telemetry.getTimestamp())
                    .messageType("TELEMETRY")
                    .build();
            
            // Use deviceId as key for partition ordering (same device = same partition)
            kafkaTemplate.send(
                    KafkaConfig.TELEMETRY_TOPIC,
                    telemetry.getDeviceId().toString(),
                    message
            );
            log.debug("Sent telemetry to Kafka: {}", telemetry.getId());
        } catch (Exception e) {
            log.error("Failed to send telemetry to Kafka: {}", e.getMessage());
        }
    }

    @Scheduled(fixedRateString = "${ingestion.batch.interval-ms:5000}")
    @Transactional
    public void processUnprocessedData() {
        List<TelemetryData> unprocessed = telemetryRepository.findUnprocessedData(
                PageRequest.of(0, batchSize));
        
        if (!unprocessed.isEmpty()) {
            log.info("Processing {} unprocessed telemetry records", unprocessed.size());
            
            List<UUID> ids = unprocessed.stream()
                    .map(TelemetryData::getId)
                    .collect(Collectors.toList());
            
            // Send to analytics
            unprocessed.forEach(this::sendToAnalytics);
            
            // Mark as processed
            telemetryRepository.markAsProcessed(ids);
        }
    }

    @Scheduled(cron = "0 0 2 * * ?") // Run at 2 AM daily
    @Transactional
    public void cleanupOldData() {
        Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
        int deleted = telemetryRepository.deleteOldProcessedData(cutoff);
        log.info("Cleaned up {} old telemetry records", deleted);
    }
}
