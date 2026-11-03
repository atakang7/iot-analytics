# 0004: Validate sensor values before publishing

Status: Accepted

## Context

The HTTP endpoint previously accepted any nonempty measurement object. Python workers then rejected numeric strings, non-finite values and invalid vibration axes after Kafka had acknowledged them. A single bad record could stop a consumer before its offset advanced.

## Decision

Validate required identifiers, timestamp offsets and finite sensor measurements at the HTTP boundary. Apply the same checks when consumers decode Kafka events, including events from external producers. Keep the existing scalar and vibration wire fields.

## Consequences

Clients that sent numeric strings or empty vibration axes now receive HTTP 400 and must send valid JSON numbers. Kafka still has no quarantine path for records from producers that bypass the API. The input rules have regression tests in Java, Python and the Compose end-to-end smoke.
