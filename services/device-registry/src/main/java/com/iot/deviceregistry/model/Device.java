package com.iot.deviceregistry.model;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import com.iot.common.model.DeviceType; 
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "devices", indexes = {
    @Index(name = "idx_device_type", columnList = "type"),
    @Index(name = "idx_device_status", columnList = "status"),
    @Index(name = "idx_device_location", columnList = "location")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @NotBlank(message = "Device name is required")
    @Size(min = 1, max = 255)
    @Column(nullable = false)
    private String name;

    @NotNull(message = "Device type is required")
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DeviceType type;

    @Size(max = 500)
    private String description;

    @Size(max = 255)
    private String location;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private DeviceStatus status = DeviceStatus.INACTIVE;

    @Size(max = 100)
    private String firmwareVersion;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at")
    private Instant updatedAt;

    @Column(name = "last_seen_at")
    private Instant lastSeenAt;

    @PrePersist
    protected void onCreate() {
        createdAt = Instant.now();
        updatedAt = Instant.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = Instant.now();
    }
}
