package com.iot.ingestion;

import java.time.Instant;
import java.util.Map;

public record Telemetry(
    String deviceId,
    String deviceType,
    String sensorId,
    String sensorType,
    Instant timestamp, 
    String unit, 
    Map<String, Object> value
) {}
  