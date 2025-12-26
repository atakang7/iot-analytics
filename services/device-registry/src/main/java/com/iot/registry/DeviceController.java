package com.iot.registry;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/devices")
public class DeviceController {

    private final DeviceRepository repository;

    public DeviceController(DeviceRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Device> list() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Device> get(@PathVariable UUID id) {
        return repository.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping
    public Device create(@RequestBody Device device) {
        return repository.save(device);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Device> update(@PathVariable UUID id, @RequestBody Device device) {
        return repository.findById(id)
                .map(existing -> {
                    existing.setName(device.getName());
                    existing.setType(device.getType());
                    existing.setStatus(device.getStatus());
                    existing.setLocation(device.getLocation());
                    return ResponseEntity.ok(repository.save(existing));
                })
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable UUID id) {
        if (repository.existsById(id)) {
            repository.deleteById(id);
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }
}
