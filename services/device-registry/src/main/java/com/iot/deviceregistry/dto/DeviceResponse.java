package com.iot.deviceregistry.dto;

import com.iot.deviceregistry.model.Device;
import com.iot.deviceregistry.model.DeviceStatus;
import com.iot.common.model.DeviceType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceResponse {

    private UUID id;
    private String name;
    private DeviceType type;
    private String description;
    private String location;
    private DeviceStatus status;
    private String firmwareVersion;
    private Instant createdAt;
    private Instant updatedAt;
    private Instant lastSeenAt;

    public static DeviceResponse fromEntity(Device device) {
        return DeviceResponse.builder()
                .id(device.getId())
                .name(device.getName())
                .type(device.getType())
                .description(device.getDescription())
                .location(device.getLocation())
                .status(device.getStatus())
                .firmwareVersion(device.getFirmwareVersion())
                .createdAt(device.getCreatedAt())
                .updatedAt(device.getUpdatedAt())
                .lastSeenAt(device.getLastSeenAt())
                .build();
    }
}
