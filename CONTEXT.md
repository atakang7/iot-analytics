# Domain context

Use these names in code, tests and documentation.

- **Device:** A managed physical or logical asset. Its registration identity is distinct from the source identifier on readings.
- **Telemetry source:** The external identifier included with a reading. It is not proof that a registered device exists.
- **Sensor:** A named measurement stream belonging to a telemetry source. A sensor identifier identifies that stream within its source.
- **Reading:** One observation from a sensor at a particular instant, containing a sensor type, unit and measurement payload.
- **Reading identity:** The source identifier, sensor identifier and observation timestamp together. Retransmitting an identical identity does not create another stored reading.
- **Threshold:** A configured upper or lower limit for a sensor type, optionally narrowed to a device type.
- **Alert:** A rule evaluation outcome associated with a reading. Repeating the same outcome should keep its identity.
- **Window:** A half-open interval of event time. A reading on the end boundary belongs to the next window.
- **KPI:** A derived measurement for one sensor and one window.
- **Watermark:** The end of the latest window successfully processed into KPIs.
- **Replay:** Reading a previously consumed message again after an interrupted or repeated delivery.
- **Quarantine:** Durable isolation of a message that cannot satisfy the domain contract, preserving evidence for review before it is reprocessed.
- **Acknowledgment:** The sender or consumer's confirmation of a particular delivery stage. It is not confirmation of all downstream outcomes.
