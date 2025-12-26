package com.iot.deviceregistry.repository;

import com.iot.deviceregistry.model.Device;
import com.iot.deviceregistry.model.DeviceStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface DeviceRepository extends JpaRepository<Device, UUID> {

    Page<Device> findByStatus(DeviceStatus status, Pageable pageable);

    Page<Device> findByType(com.iot.common.model.DeviceType type, Pageable pageable);

    Page<Device> findByLocation(String location, Pageable pageable);

    List<Device> findByStatusIn(List<DeviceStatus> statuses);

    @Query("SELECT d FROM Device d WHERE " +
           "(:type IS NULL OR d.type = :type) AND " +
           "(:status IS NULL OR d.status = :status) AND " +
           "(:location IS NULL OR d.location = :location)")
    Page<Device> findByFilters(
            @Param("type") com.iot.common.model.DeviceType type,
            @Param("status") DeviceStatus status,
            @Param("location") String location,
            Pageable pageable);

    @Query("SELECT DISTINCT d.type FROM Device d")
    List<com.iot.common.model.DeviceType> findAllDeviceTypes();

    @Query("SELECT DISTINCT d.location FROM Device d WHERE d.location IS NOT NULL")
    List<String> findAllLocations();

    long countByStatus(DeviceStatus status);

    long countByType(com.iot.common.model.DeviceType type);
}
