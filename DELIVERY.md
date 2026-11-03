# Release and promotion contract

This repository uses the same **build once, verify bytes, promote the same
digest** boundary as the golden platform. Deployment is deliberately
separate from test-only OpenShift BuildConfigs and from the cluster itself.

```text
PR -> unit/e2e/Kind/foundation/policy checks
   |
main Verify success
   |
manual GHCR publisher (Trivy CRITICAL + CycloneDX SBOM)
   |
Skopeo byte-identical OCI -> Cosign GitHub OIDC signature
   |
release.json (exact six GHCR image digests)
   |
reviewed Git change to state/dev.json
   |
release deployment preflight (Git, context, namespace, six signatures)
   |
apps-only Helm template + API server dry-run
   |
explicit --apply --confirm -> Helm --atomic --wait
   |
live image + readiness verification
   |
dev -> stage -> prod (same digests; history enforced)
```

## Control boundaries

- `delivery/release.py` validates the complete six-image manifest.
- `delivery/state.py` tracks desired environment state, verifies release
  promotion history, and forbids skipping an environment.
- `delivery/rollout.py` is the **operator-owned deployment mechanism**;
  plan mode is read-only. Apply mode requires a matching
  `ENV:NAMESPACE@CONTEXT` confirmation and a namespace labeled
  `iot-release-allowed=true`.
- All six runtime image references must exactly match the committed Git
  release state; arbitrary foreign GHCR repositories and image tags are
  refused.
- The tool verifies all six Cosign certificate identities against the
  **main-branch** GitHub release workflow, and asks the target API server to
  approve the manifests through a server-side dry-run.
- The release Helm name is `iot-apps-ENV`, and the chart is
  `iot-helm/charts/apps` **only**. This keeps Helm from touching Kafka,
  TimescaleDB, PVCs, monitoring and lab ImageStreams.
- `helm upgrade --install --atomic --cleanup-on-fail --wait` handles a
  failed rollout; post-rollout drift checking either rolls back to the
  prior release revision or uninstalls the just-created app release.

## Prepare and deploy (operator)

After a successful **real** publish, download the release artifact and
create a reviewed PR recording it in `state/dev.json`. Merge the PR, then
check out the committed main revision.

```bash
# Read-only plan; does NOT contact the cluster or validate signatures.
python3 delivery/rollout.py \
  --environment dev \
  --namespace iot-dev \
  --context my-cluster \
  --repository atakang7/iot-analytics

# Explicitly opt in a dedicated app namespace (authorized operator action).
kubectl --context my-cluster label namespace iot-dev iot-release-allowed=true

# Must match all choices, and requires existing cluster credentials.
python3 delivery/rollout.py \
  --environment dev \
  --namespace iot-dev \
  --context my-cluster \
  --repository atakang7/iot-analytics \
  --apply --confirm 'dev:iot-dev@my-cluster'
```

Only run these commands after setting up the correct namespace, private
Kafka/TimescaleDB connectivity and image-pull access. Helm cannot create
those infrastructure services as part of the production app-only release.

No GHCR publishing, Cosign keyless signing, live OpenShift deployment,
remote service discovery or production database migrations have been
executed by these PR CI jobs. The plan and failure guards are unit-tested;
the complete release apply path needs an authorized operator test.
