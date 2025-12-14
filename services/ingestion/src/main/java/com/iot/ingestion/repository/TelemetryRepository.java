package com.iot.ingestion.repository;

import com.iot.ingestion.model.TelemetryData;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Repository
public interface TelemetryRepository extends JpaRepository<TelemetryData, UUID> {

    Page<TelemetryData> findByDeviceId(UUID deviceId, Pageable pageable);

    List<TelemetryData> findByDeviceIdAndTimestampBetween(UUID deviceId, Instant start, Instant end);

    List<TelemetryData> findByDeviceIdAndMetricNameAndTimestampBetween(
            UUID deviceId, String metricName, Instant start, Instant end);

    @Query("SELECT DISTINCT t.metricName FROM TelemetryData t WHERE t.deviceId = :deviceId")
    List<String> findDistinctMetricNamesByDeviceId(@Param("deviceId") UUID deviceId);

    @Query("SELECT t FROM TelemetryData t WHERE t.processed = false ORDER BY t.receivedAt ASC")
    List<TelemetryData> findUnprocessedData(Pageable pageable);

    @Modifying
    @Query("UPDATE TelemetryData t SET t.processed = true WHERE t.id IN :ids")
    int markAsProcessed(@Param("ids") List<UUID> ids);

    @Query("SELECT AVG(t.metricValue) FROM TelemetryData t WHERE t.deviceId = :deviceId AND t.metricName = :metricName AND t.timestamp BETWEEN :start AND :end")
    Double getAverageMetricValue(@Param("deviceId") UUID deviceId, @Param("metricName") String metricName, 
                                  @Param("start") Instant start, @Param("end") Instant end);

    @Query("SELECT MAX(t.metricValue) FROM TelemetryData t WHERE t.deviceId = :deviceId AND t.metricName = :metricName AND t.timestamp BETWEEN :start AND :end")
    Double getMaxMetricValue(@Param("deviceId") UUID deviceId, @Param("metricName") String metricName, 
                              @Param("start") Instant start, @Param("end") Instant end);

    @Query("SELECT MIN(t.metricValue) FROM TelemetryData t WHERE t.deviceId = :deviceId AND t.metricName = :metricName AND t.timestamp BETWEEN :start AND :end")
    Double getMinMetricValue(@Param("deviceId") UUID deviceId, @Param("metricName") String metricName, 
                              @Param("start") Instant start, @Param("end") Instant end);

    long countByDeviceId(UUID deviceId);

    @Query("SELECT COUNT(t) FROM TelemetryData t WHERE t.timestamp >= :since")
    long countRecentTelemetry(@Param("since") Instant since);

    @Modifying
    @Query("DELETE FROM TelemetryData t WHERE t.timestamp < :cutoff AND t.processed = true")
    int deleteOldProcessedData(@Param("cutoff") Instant cutoff);
}
