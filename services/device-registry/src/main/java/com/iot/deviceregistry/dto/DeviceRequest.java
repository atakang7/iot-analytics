package com.iot.deviceregistry.dto;

import com.iot.deviceregistry.model.DeviceStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import com.iot.common.model.DeviceType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceRequest {

    @NotBlank(message = "Device name is required")
    @Size(min = 1, max = 255, message = "Name must be between 1 and 255 characters")
    private String name;

    @NotNull(message = "Device type is required")
    private DeviceType type;

    @Size(max = 500, message = "Description cannot exceed 500 characters")
    private String description;

    @Size(max = 255, message = "Location cannot exceed 255 characters")
    private String location;

    private DeviceStatus status;

    @Size(max = 100, message = "Firmware version cannot exceed 100 characters")
    private String firmwareVersion;
}
