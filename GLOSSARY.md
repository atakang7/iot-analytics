# Glossary

[CONTEXT.md](CONTEXT.md) defines the domain language. Infrastructure terms used in the runbooks follow.

| Term | Meaning |
| --- | --- |
| At-least-once delivery | An event may be processed again after a crash. Consumers must tolerate replay. |
| Consumer group | Kafka readers that share partition assignments and committed offsets. |
| Offset commit | The consumer's record of progress through a partition. |
| Hypertable | A TimescaleDB table partitioned by time. |
| OCI digest | The content address of an image manifest, written as `sha256:...`. |
| Release manifest | A single source commit and six immutable application image references. |
| Admission policy | A Kubernetes API rule that accepts or rejects resource creation. |
| Kind | Disposable Kubernetes running in Docker for integration tests. |
| Server dry-run | Kubernetes validation of a request without persisting the object. |
| Prometheus scrape | A metrics request to a configured application endpoint. |
| Recovery rehearsal | Restoring a backup into a separate test database and checking its contents. |

See [event reference](docs/reference/events.md) for JSON fields and [decisions](docs/explanation/decisions.md) for architectural trade-offs.
