# Telemetry wire contract

Ingestion returns HTTP 400 for a malformed reading before attempting Kafka publication.

Both Java and Python accept ISO 8601 timestamps with offsets, source and sensor identifiers of 1 to 128 characters, and units of 1 to 64 characters. Leading and trailing whitespace-only identifiers are invalid.

Scalar sensors use a finite JSON number in `value.value`. Vibration readings use at least one of `value.x`, `value.y` or `value.z`; every supplied axis must be a finite JSON number. Unspecified vibration axes count as zero. Numeric strings, booleans, null and non-finite numbers are invalid.

Java enforces the contract with Bean Validation at the HTTP boundary. Python rechecks it when decoding events from Kafka, including events sent by clients that bypass the API.

The identifier and timestamp still define storage uniqueness. This contract does not add a registry foreign key, enforce device ownership or create a dead-letter topic.
