# CI

[`ci.yaml`](ci.yaml) verifies pull requests and pushes to `main`; it does not deploy to OpenShift.

```text
+--------------+ trigger +---------+
| pull_request | ------> | ci.yaml |
+--------------+         +---------+
                            |      |
                         runs      runs
                            v      v
                         +------+ +------------+
                         | java | | kubernetes |
                         +------+ +------------+
```

The workflow runs 11 jobs, including unit tests, Compose and database checks, cluster smoke tests and an isolated OCI signing rehearsal.

- Each job has its own failure status and logs.
- `publish.yaml` is manual and only accepts a previously verified `main` revision.
- Neither workflow automatically deploys, promotes or rolls back an OpenShift workload.
