# 0003: Keep application rollout separate from data infrastructure

Status: Accepted

## Context

OpenShift lab charts contain stateful Kafka and TimescaleDB resources as well as build configurations. A Helm upgrade that treats the whole chart as one application release risks changing persistent infrastructure while deploying ordinary code.

## Decision

Release manifests identify the six application images by immutable OCI digest. Keep the application-only Helm subchart distinct from the OpenShift infrastructure and monitoring charts. Promotion copies the same digest identities through dev, stage and prod.

## Consequences

The application release cannot bootstrap databases, credentials or the network. Operators must provide those dependencies and review migrations separately. CI can validate the chart and release state but cannot claim to have tested a production OpenShift rollout.
