package com.iot.deviceregistry.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceStatsResponse {

    private long totalDevices;
    private long activeDevices;
    private long inactiveDevices;
    private long maintenanceDevices;
    private long decommissionedDevices;
    private Map<String, Long> devicesByType;
}
