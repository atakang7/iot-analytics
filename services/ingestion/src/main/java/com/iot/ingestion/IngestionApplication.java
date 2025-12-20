package com.iot.ingestion;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * IoT Ingestion Service
 * 
 * Receives telemetry data from IoT devices via HTTP and publishes to Kafka
 * for downstream processing by Flink.
 */
@SpringBootApplication
public class IngestionApplication {

    public static void main(String[] args) {
        SpringApplication.run(IngestionApplication.class, args);
    }
}
