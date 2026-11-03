#!/usr/bin/env python3
"""Validate an immutable six-service release and emit Helm override values.

Only image digests are deployable identities; tags never enter release state.
This module intentionally has no cloud SDK or secret-handling dependency.
"""
import argparse
import json
import re
from pathlib import Path

SERVICES = frozenset({
    "ingestion", "device-registry", "telemetry-worker",
    "stream-worker", "alert-worker", "kpi-job",
})
SHA = re.compile(r"^[0-9a-f]{40}$")
DIGEST_IMAGE = re.compile(
    r"^ghcr\.io/[a-z0-9][a-z0-9._-]*/[a-z0-9][a-z0-9._-]*/"
    r"([a-z0-9-]+)@sha256:[0-9a-f]{64}$"
)


class ReleaseError(ValueError):
    """Fail closed on an invalid or incomplete release identity."""


def validate_release(release):
    if not isinstance(release, dict) or set(release) != {"schema", "commit", "images"}:
        raise ReleaseError("expected exactly schema, commit, images")
    if type(release["schema"]) is not int or release["schema"] != 1:
        raise ReleaseError("unsupported release schema")
    if not isinstance(release["commit"], str) or not SHA.fullmatch(release["commit"]):
        raise ReleaseError("commit must be a complete lowercase Git SHA")
    images = release["images"]
    if not isinstance(images, dict) or set(images) != SERVICES:
        raise ReleaseError(f"images must name exactly: {', '.join(sorted(SERVICES))}")
    for name, image in images.items():
        match = DIGEST_IMAGE.fullmatch(image) if isinstance(image, str) else None
        if match is None or match.group(1) != name:
            raise ReleaseError(f"{name}: expected ghcr.io/OWNER/REPO/{name}@sha256:DIGEST")
    return release


def load_release(path):
    try:
        return validate_release(json.loads(Path(path).read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReleaseError(str(exc)) from exc


def helm_values(release):
    validate_release(release)
    return {"apps": {"imageMode": "release", "images": release["images"]}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    check = sub.add_parser("validate")
    check.add_argument("manifest", type=Path)
    render = sub.add_parser("helm-values")
    render.add_argument("manifest", type=Path)
    render.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        release = load_release(args.manifest)
        if args.action == "helm-values":
            args.output.write_text(json.dumps(helm_values(release), indent=2, sort_keys=True) + "\n", encoding="utf-8")
            print(f"Generated release Helm values: {args.output}")
        else:
            print("PASS: complete digest-pinned release")
    except ReleaseError as exc:
        parser.exit(1, f"Invalid release: {exc}\n")


if __name__ == "__main__":
    main()
