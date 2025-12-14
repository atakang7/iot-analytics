package com.iot.ingestion.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "telemetry_data", indexes = {
    @Index(name = "idx_telemetry_device_id", columnList = "device_id"),
    @Index(name = "idx_telemetry_timestamp", columnList = "timestamp"),
    @Index(name = "idx_telemetry_metric_name", columnList = "metric_name")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TelemetryData {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "device_id", nullable = false)
    private UUID deviceId;

    @Column(name = "metric_name", nullable = false)
    private String metricName;

    @Column(name = "metric_value", nullable = false)
    private Double metricValue;

    @Column(name = "unit")
    private String unit;

    @Column(name = "timestamp", nullable = false)
    private Instant timestamp;

    @Column(name = "received_at", nullable = false)
    private Instant receivedAt;

    @Column(name = "processed")
    @Builder.Default
    private Boolean processed = false;

    @PrePersist
    protected void onCreate() {
        if (receivedAt == null) {
            receivedAt = Instant.now();
        }
        if (timestamp == null) {
            timestamp = Instant.now();
        }
    }
}
