package com.iot.registry;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Client-owned device fields; generated ID and createdAt are never writable. */
public record DeviceRequest(
        @NotBlank @Size(max = 255) String name,
        @NotBlank @Size(max = 100) String type,
        @Size(max = 40) String status,
        @Size(max = 255) String location) {
}
