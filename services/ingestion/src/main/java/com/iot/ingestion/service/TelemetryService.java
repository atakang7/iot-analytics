package com.iot.ingestion.service;

import com.iot.common.dto.telemetry.AnalyticsMessage;
import com.iot.common.dto.telemetry.BatchTelemetryRequest;
import com.iot.common.dto.telemetry.BatchTelemetryResponse;
import com.iot.common.dto.telemetry.TelemetryRequest;
import com.iot.common.dto.telemetry.TelemetryResponse;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;

/**
 * Service for processing telemetry data and publishing to Kafka.
 */
@Service
public class TelemetryService {

    private static final Logger log = LoggerFactory.getLogger(TelemetryService.class);

    private final KafkaTemplate<String, AnalyticsMessage> kafkaTemplate;
    private final String topicName;
    
    // Metrics
    private final Counter messagesReceived;
    private final Counter messagesPublished;
    private final Counter messagesFailed;
    private final Timer publishLatency;

    public TelemetryService(
            KafkaTemplate<String, AnalyticsMessage> kafkaTemplate,
            @Value("${app.kafka.topic.telemetry}") String topicName,
            MeterRegistry meterRegistry) {
        this.kafkaTemplate = kafkaTemplate;
        this.topicName = topicName;
        
        // Initialize metrics
        this.messagesReceived = Counter.builder("ingestion.messages.received")
                .description("Number of telemetry messages received")
                .register(meterRegistry);
        
        this.messagesPublished = Counter.builder("ingestion.messages.published")
                .description("Number of messages successfully published to Kafka")
                .register(meterRegistry);
        
        this.messagesFailed = Counter.builder("ingestion.messages.failed")
                .description("Number of messages that failed to publish")
                .register(meterRegistry);
        
        this.publishLatency = Timer.builder("ingestion.publish.latency")
                .description("Time taken to publish message to Kafka")
                .register(meterRegistry);
    }

    /**
     * Process a single telemetry request.
     */
    public Mono<TelemetryResponse> processTelemetry(TelemetryRequest request) {
        messagesReceived.increment();
        
        // Validate value type matches sensor type
        if (!request.isValueTypeValid()) {
            messagesFailed.increment();
            return Mono.just(TelemetryResponse.error(
                request.deviceId(),
                request.sensorId(),
                "Value type does not match sensor type: " + request.sensorType()
            ));
        }

        AnalyticsMessage message = request.toAnalyticsMessage();
        String key = buildMessageKey(message);

        return publishToKafka(key, message)
                .map(result -> {
                    messagesPublished.increment();
                    log.debug("Published telemetry for device={}, sensor={}, partition={}, offset={}",
                            message.deviceId(), message.sensorId(),
                            result.getRecordMetadata().partition(),
                            result.getRecordMetadata().offset());
                    return TelemetryResponse.success(request.deviceId(), request.sensorId());
                })
                .onErrorResume(error -> {
                    messagesFailed.increment();
                    log.error("Failed to publish telemetry for device={}, sensor={}: {}",
                            message.deviceId(), message.sensorId(), error.getMessage());
                    return Mono.just(TelemetryResponse.error(
                            request.deviceId(),
                            request.sensorId(),
                            "Failed to publish: " + error.getMessage()
                    ));
                });
    }

    /**
     * Process a batch of telemetry requests.
     */
    public Mono<BatchTelemetryResponse> processBatch(BatchTelemetryRequest batchRequest) {
        messagesReceived.increment(batchRequest.size());

        List<BatchTelemetryResponse.BatchError> errors = new ArrayList<>();
        
        return Flux.fromIterable(batchRequest.readings())
                .index()
                .flatMap(tuple -> {
                    int index = tuple.getT1().intValue();
                    TelemetryRequest request = tuple.getT2();
                    
                    // Validate
                    if (!request.isValueTypeValid()) {
                        errors.add(new BatchTelemetryResponse.BatchError(
                                index,
                                request.deviceId(),
                                "Value type does not match sensor type"
                        ));
                        messagesFailed.increment();
                        return Mono.empty();
                    }

                    AnalyticsMessage message = request.toAnalyticsMessage();
                    String key = buildMessageKey(message);

                    return publishToKafka(key, message)
                            .doOnSuccess(r -> messagesPublished.increment())
                            .onErrorResume(error -> {
                                errors.add(new BatchTelemetryResponse.BatchError(
                                        index,
                                        request.deviceId(),
                                        error.getMessage()
                                ));
                                messagesFailed.increment();
                                return Mono.empty();
                            });
                })
                .collectList()
                .map(results -> {
                    int total = batchRequest.size();
                    int accepted = total - errors.size();
                    
                    if (errors.isEmpty()) {
                        return BatchTelemetryResponse.success(total);
                    } else if (accepted > 0) {
                        return BatchTelemetryResponse.partial(total, accepted, errors);
                    } else {
                        return BatchTelemetryResponse.error(total, "All messages failed");
                    }
                });
    }

    /**
     * Publish message to Kafka with timing.
     */
    private Mono<SendResult<String, AnalyticsMessage>> publishToKafka(String key, AnalyticsMessage message) {
        return Mono.fromFuture(() -> {
            Timer.Sample sample = Timer.start();
            CompletableFuture<SendResult<String, AnalyticsMessage>> future = 
                    kafkaTemplate.send(topicName, key, message);
            
            future.whenComplete((result, error) -> {
                sample.stop(publishLatency);
            });
            
            return future;
        });
    }

    /**
     * Build Kafka message key for partitioning.
     * Using deviceId ensures all messages from same device go to same partition,
     * maintaining ordering per device.
     */
    private String buildMessageKey(AnalyticsMessage message) {
        return message.deviceId();
    }
}
