package com.iot.deviceregistry.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureTestDatabase
@AutoConfigureMockMvc
public class DeviceControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void createDevice_withValidType_returnsCreated() throws Exception {
        String payload = "{\"name\": \"cnc-001\", \"type\": \"cnc_machine\"}";

        mockMvc.perform(post("/api/v1/devices")
                .contentType(MediaType.APPLICATION_JSON)
                .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("cnc-001"))
                .andExpect(jsonPath("$.type").value("cnc_machine"));
    }

    @Test
    void createDevice_withInvalidType_returnsBadRequest() throws Exception {
        String payload = "{\"name\": \"bad-1\", \"type\": \"invalid_type\"}";

        mockMvc.perform(post("/api/v1/devices")
                .contentType(MediaType.APPLICATION_JSON)
                .content(payload))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Unknown device type")));
    }
}
