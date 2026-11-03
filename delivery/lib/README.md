Part of [iot-analytics](../../README.md).

# oci.sh

Shell functions shared by the GHCR publisher and local registry test.

## Run

`delivery/bin/publish-image` and `delivery/bin/test-local-publish` source `oci.sh`.

## Test

```bash
bash -n delivery/lib/oci.sh
```

## Interfaces

`oci_build` creates an OCI archive, `oci_scan` runs Trivy and writes a CycloneDX SBOM, and `oci_copy` and `oci_verify` check digest preservation. See [delivery commands](../bin/README.md).
