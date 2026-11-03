# Publish and promote an immutable release

GitHub Actions publishes only when an operator dispatches the `Publish immutable OCI release` workflow on a passing `main` commit. The workflow builds six application images, runs Trivy and CycloneDX SBOM generation, publishes digest-preserving OCI artifacts and checks Cosign signatures.

Download the `immutable-release` artifact from that workflow. It contains a release manifest and Helm values.

```bash
python3 delivery/release.py validate release.json
python3 delivery/release.py helm-values release.json --output /tmp/release-values.json
helm dependency build iot-helm
helm template iot-analytics iot-helm -f /tmp/release-values.json > /tmp/release.yaml
python3 scripts/verify-helm.py /tmp/release.yaml --release-manifest release.json
```

These commands validate files. They do not install a release.

## Record the first environment

```bash
python3 delivery/state.py record-dev release.json
python3 delivery/state.py verify --history-ref origin/main
```

Review and merge the resulting `state/dev.json` change. Deploy and check that exact digest set in an authorized environment before promotion.

## Promote without rebuilding

After the dev release has appeared in committed history and passed environment checks:

```bash
python3 delivery/state.py promote \
  --source state/dev.json --target state/stage.json
python3 delivery/state.py verify --history-ref origin/main
```

Promote stage to prod the same way, in a later reviewed change. CI rejects a promotion if the release never appeared in the predecessor's history.

This repository's GitHub runners do not perform live OpenShift deployment. Use [the OpenShift checks](openshift-lab.md) for lab prerequisites and secure operator review.
