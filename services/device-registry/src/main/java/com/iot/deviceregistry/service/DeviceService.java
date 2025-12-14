package com.iot.deviceregistry.service;

import com.iot.deviceregistry.dto.DeviceRequest;
import com.iot.deviceregistry.dto.DeviceResponse;
import com.iot.deviceregistry.dto.DeviceStatsResponse;
import com.iot.deviceregistry.exception.DeviceNotFoundException;
import com.iot.deviceregistry.model.Device;
import com.iot.deviceregistry.model.DeviceStatus;
import com.iot.deviceregistry.repository.DeviceRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DeviceService {

    private final DeviceRepository deviceRepository;

    @Transactional(readOnly = true)
    public Page<DeviceResponse> getAllDevices(Pageable pageable) {
        log.debug("Fetching all devices with pagination: {}", pageable);
        return deviceRepository.findAll(pageable)
                .map(DeviceResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public DeviceResponse getDeviceById(UUID id) {
        log.debug("Fetching device by ID: {}", id);
        return deviceRepository.findById(id)
                .map(DeviceResponse::fromEntity)
                .orElseThrow(() -> new DeviceNotFoundException("Device not found with id: " + id));
    }

    @Transactional
    public DeviceResponse createDevice(DeviceRequest request) {
        log.info("Creating new device: {}", request.getName());
        
        Device device = Device.builder()
                .name(request.getName())
                .type(request.getType())
                .description(request.getDescription())
                .location(request.getLocation())
                .status(request.getStatus() != null ? request.getStatus() : DeviceStatus.INACTIVE)
                .firmwareVersion(request.getFirmwareVersion())
                .build();

        Device savedDevice = deviceRepository.save(device);
        log.info("Device created with ID: {}", savedDevice.getId());
        
        return DeviceResponse.fromEntity(savedDevice);
    }

    @Transactional
    public DeviceResponse updateDevice(UUID id, DeviceRequest request) {
        log.info("Updating device: {}", id);
        
        Device device = deviceRepository.findById(id)
                .orElseThrow(() -> new DeviceNotFoundException("Device not found with id: " + id));

        if (request.getName() != null) {
            device.setName(request.getName());
        }
        if (request.getType() != null) {
            device.setType(request.getType());
        }
        if (request.getDescription() != null) {
            device.setDescription(request.getDescription());
        }
        if (request.getLocation() != null) {
            device.setLocation(request.getLocation());
        }
        if (request.getStatus() != null) {
            device.setStatus(request.getStatus());
        }
        if (request.getFirmwareVersion() != null) {
            device.setFirmwareVersion(request.getFirmwareVersion());
        }

        Device updatedDevice = deviceRepository.save(device);
        log.info("Device updated: {}", updatedDevice.getId());
        
        return DeviceResponse.fromEntity(updatedDevice);
    }

    @Transactional
    public void deleteDevice(UUID id) {
        log.info("Deleting device: {}", id);
        
        if (!deviceRepository.existsById(id)) {
            throw new DeviceNotFoundException("Device not found with id: " + id);
        }
        
        deviceRepository.deleteById(id);
        log.info("Device deleted: {}", id);
    }

    @Transactional
    public DeviceResponse updateDeviceStatus(UUID id, DeviceStatus status) {
        log.info("Updating device status: {} -> {}", id, status);
        
        Device device = deviceRepository.findById(id)
                .orElseThrow(() -> new DeviceNotFoundException("Device not found with id: " + id));
        
        device.setStatus(status);
        Device updatedDevice = deviceRepository.save(device);
        
        return DeviceResponse.fromEntity(updatedDevice);
    }

    @Transactional
    public DeviceResponse updateLastSeen(UUID id) {
        log.debug("Updating last seen for device: {}", id);
        
        Device device = deviceRepository.findById(id)
                .orElseThrow(() -> new DeviceNotFoundException("Device not found with id: " + id));
        
        device.setLastSeenAt(Instant.now());
        if (device.getStatus() == DeviceStatus.INACTIVE) {
            device.setStatus(DeviceStatus.ACTIVE);
        }
        
        Device updatedDevice = deviceRepository.save(device);
        return DeviceResponse.fromEntity(updatedDevice);
    }

    @Transactional(readOnly = true)
    public Page<DeviceResponse> findByFilters(String type, DeviceStatus status, String location, Pageable pageable) {
        log.debug("Finding devices by filters - type: {}, status: {}, location: {}", type, status, location);
        return deviceRepository.findByFilters(type, status, location, pageable)
                .map(DeviceResponse::fromEntity);
    }

    @Transactional(readOnly = true)
    public DeviceStatsResponse getDeviceStats() {
        log.debug("Fetching device statistics");
        
        Map<String, Long> devicesByType = new HashMap<>();
        List<String> types = deviceRepository.findAllDeviceTypes();
        for (String type : types) {
            devicesByType.put(type, deviceRepository.countByType(type));
        }

        return DeviceStatsResponse.builder()
                .totalDevices(deviceRepository.count())
                .activeDevices(deviceRepository.countByStatus(DeviceStatus.ACTIVE))
                .inactiveDevices(deviceRepository.countByStatus(DeviceStatus.INACTIVE))
                .maintenanceDevices(deviceRepository.countByStatus(DeviceStatus.MAINTENANCE))
                .decommissionedDevices(deviceRepository.countByStatus(DeviceStatus.DECOMMISSIONED))
                .devicesByType(devicesByType)
                .build();
    }

    @Transactional(readOnly = true)
    public List<String> getAllDeviceTypes() {
        return deviceRepository.findAllDeviceTypes();
    }

    @Transactional(readOnly = true)
    public List<String> getAllLocations() {
        return deviceRepository.findAllLocations();
    }
}
