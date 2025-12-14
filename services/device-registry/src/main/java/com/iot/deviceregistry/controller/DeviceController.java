package com.iot.deviceregistry.controller;

import com.iot.deviceregistry.dto.DeviceRequest;
import com.iot.deviceregistry.dto.DeviceResponse;
import com.iot.deviceregistry.dto.DeviceStatsResponse;
import com.iot.deviceregistry.model.DeviceStatus;
import com.iot.deviceregistry.service.DeviceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/devices")
@RequiredArgsConstructor
@Tag(name = "Device Registry", description = "APIs for managing IoT devices")
public class DeviceController {

    private final DeviceService deviceService;

    @GetMapping
    @Operation(summary = "Get all devices", description = "Retrieve all devices with pagination")
    public ResponseEntity<Page<DeviceResponse>> getAllDevices(
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(deviceService.getAllDevices(pageable));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get device by ID", description = "Retrieve a specific device by its ID")
    public ResponseEntity<DeviceResponse> getDeviceById(@PathVariable UUID id) {
        return ResponseEntity.ok(deviceService.getDeviceById(id));
    }

    @PostMapping
    @Operation(summary = "Create a new device", description = "Register a new IoT device")
    public ResponseEntity<DeviceResponse> createDevice(@Valid @RequestBody DeviceRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(deviceService.createDevice(request));
    }

    @PutMapping("/{id}")
    @Operation(summary = "Update a device", description = "Update an existing device's information")
    public ResponseEntity<DeviceResponse> updateDevice(
            @PathVariable UUID id,
            @Valid @RequestBody DeviceRequest request) {
        return ResponseEntity.ok(deviceService.updateDevice(id, request));
    }

    @DeleteMapping("/{id}")
    @Operation(summary = "Delete a device", description = "Remove a device from the registry")
    public ResponseEntity<Void> deleteDevice(@PathVariable UUID id) {
        deviceService.deleteDevice(id);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/status")
    @Operation(summary = "Update device status", description = "Update the status of a device")
    public ResponseEntity<DeviceResponse> updateDeviceStatus(
            @PathVariable UUID id,
            @RequestParam DeviceStatus status) {
        return ResponseEntity.ok(deviceService.updateDeviceStatus(id, status));
    }

    @PostMapping("/{id}/heartbeat")
    @Operation(summary = "Device heartbeat", description = "Update the last seen timestamp of a device")
    public ResponseEntity<DeviceResponse> deviceHeartbeat(@PathVariable UUID id) {
        return ResponseEntity.ok(deviceService.updateLastSeen(id));
    }

    @GetMapping("/search")
    @Operation(summary = "Search devices", description = "Search devices by type, status, and location")
    public ResponseEntity<Page<DeviceResponse>> searchDevices(
            @RequestParam(required = false) String type,
            @RequestParam(required = false) DeviceStatus status,
            @RequestParam(required = false) String location,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(deviceService.findByFilters(type, status, location, pageable));
    }

    @GetMapping("/stats")
    @Operation(summary = "Get device statistics", description = "Get aggregated statistics about devices")
    public ResponseEntity<DeviceStatsResponse> getDeviceStats() {
        return ResponseEntity.ok(deviceService.getDeviceStats());
    }

    @GetMapping("/types")
    @Operation(summary = "Get all device types", description = "Get list of all unique device types")
    public ResponseEntity<List<String>> getAllDeviceTypes() {
        return ResponseEntity.ok(deviceService.getAllDeviceTypes());
    }

    @GetMapping("/locations")
    @Operation(summary = "Get all locations", description = "Get list of all unique device locations")
    public ResponseEntity<List<String>> getAllLocations() {
        return ResponseEntity.ok(deviceService.getAllLocations());
    }
}
