package com.iot.registry;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class DeviceControllerTest {
    @Mock
    private DeviceRepository repository;

    @Test
    void createUsesServerGeneratedIdentityAndReturnsLocation() {
        UUID id = UUID.randomUUID();
        when(repository.save(any(Device.class))).thenAnswer(invocation -> {
            Device entity = invocation.getArgument(0);
            entity.setId(id);
            return entity;
        });
        DeviceController controller = new DeviceController(repository);
        var response = controller.create(
                new DeviceRequest("CNC-001", "motor", null, "factory"));

        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertEquals("/devices/" + id, response.getHeaders().getLocation().toString());
        assertEquals("inactive", response.getBody().getStatus());
    }

    @Test
    void missingDeviceReturns404() {
        UUID id = UUID.randomUUID();
        when(repository.findById(id)).thenReturn(Optional.empty());
        var response = new DeviceController(repository).get(id);
        assertEquals(HttpStatus.NOT_FOUND, response.getStatusCode());
    }
}
