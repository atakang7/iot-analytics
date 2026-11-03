# 0001: Separate registry identity and telemetry source identity

Status: Accepted

## Context

A managed device has a UUID in the registry. A reading carries a source ID supplied by a producer. The API currently accepts readings without resolving their source IDs against registry records.

## Decision

Treat these as different identifiers. The registry manages device metadata; telemetry groups observations by the source ID in the event. Do not imply a foreign-key relationship or device authorization.

## Consequences

A sensor source may publish readings without a registry record. The registry cannot authorize data ingestion by itself. Adding device ownership or access policy requires a new identity mapping, migration and API contract. A silent join on device IDs would corrupt meaning.
