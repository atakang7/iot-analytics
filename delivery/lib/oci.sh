#!/usr/bin/env bash
# Shared build-once -> scan -> digest-preserving copy contract.
# This is sourced by BOTH the local CI proof and the real GHCR publisher.
set -Eeuo pipefail

oci_build() {
  local service="$1" archive="$2"
  local context dockerfile
  case "$service" in
    ingestion|device-registry)
      context="services/$service"
      dockerfile="$context/Dockerfile"
      ;;
    telemetry-worker|stream-worker|alert-worker|kpi-job)
      context="services/workers"
      dockerfile="$context/$service/Dockerfile"
      ;;
    *) echo "Unknown OCI component: $service" >&2; return 2 ;;
  esac
  test -n "$GITHUB_SHA"
  docker buildx build --platform linux/amd64 --provenance=false --sbom=false \
    --label "org.opencontainers.image.revision=$GITHUB_SHA" \
    --file "$dockerfile" --output "type=oci,dest=$archive" "$context"
  test -s "$archive"
}

oci_scan() {
  local archive="$1" sbom="$2"
  local layout
  test -s "$archive"
  layout="$(mktemp -d)"
  # Trivy --input detects an OCI *directory*, not an OCI tar archive. Scan
  # the unpacked layout, but publish the original untouched archive.
  tar -xf "$archive" -C "$layout"
  test -s "$layout/index.json"
  test -s "$layout/oci-layout"
  if ! trivy image --input "$layout" --scanners vuln \
      --severity CRITICAL --exit-code 1; then
    rm -rf "$layout"
    return 1
  fi
  if ! trivy image --input "$layout" --format cyclonedx --output "$sbom"; then
    rm -rf "$layout"
    return 1
  fi
  rm -rf "$layout"
  python3 - "$sbom" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    document = json.load(f)
assert document.get("bomFormat") == "CycloneDX", "Missing valid SBOM"
PY
}

oci_copy() {
  local archive="$1" image="$2" tag="$3" digestfile="$4" transport="$5"
  test -s "$archive"
  if [[ "$transport" == "local" ]]; then
    case "$image" in
      localhost:*|127.0.0.1:*) ;;
      *) echo "HTTP registry is permitted only on loopback" >&2; return 1 ;;
    esac
    skopeo copy --all --preserve-digests --dest-tls-verify=false \
      --digestfile "$digestfile" \
      "oci-archive:$archive" "docker://$image:$tag"
  elif [[ "$transport" == "secure" ]]; then
    skopeo copy --all --preserve-digests \
      --digestfile "$digestfile" \
      "oci-archive:$archive" "docker://$image:$tag"
  else
    echo "Unknown registry transport" >&2
    return 2
  fi
  test -s "$digestfile"
}

oci_verify() {
  local archive="$1" image="$2" digest="$3" transport="$4"
  local source_digest remote_digest
  source_digest="sha256:$(skopeo inspect --raw "oci-archive:$archive" | sha256sum | cut -d' ' -f1)"
  [[ "$digest" == "$source_digest" ]] || {
    echo "Digest changed between scanned OCI and publish" >&2; return 1;
  }
  if [[ "$transport" == "local" ]]; then
    remote_digest="sha256:$(skopeo inspect --raw --tls-verify=false \
      "docker://$image@$digest" | sha256sum | cut -d' ' -f1)"
  elif [[ "$transport" == "secure" ]]; then
    remote_digest="sha256:$(skopeo inspect --raw \
      "docker://$image@$digest" | sha256sum | cut -d' ' -f1)"
  else
    echo "Unknown registry transport" >&2
    return 2
  fi
  [[ "$remote_digest" == "$digest" ]] || {
    echo "Published registry digest does not match source bytes" >&2; return 1;
  }
}
