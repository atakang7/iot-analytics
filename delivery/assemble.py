#!/usr/bin/env python3
"""Assemble one complete release identity from independently scanned images."""
import argparse
import json
from pathlib import Path

from release import SERVICES, ReleaseError, validate_release


def assemble(directory: Path):
    identities = list(directory.glob("*.identity.json"))
    if len(identities) != len(SERVICES):
        raise ReleaseError(f"expected {len(SERVICES)} image identities, found {len(identities)}")
    images = {}
    revisions = set()
    for path in identities:
        try:
            item = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise ReleaseError(f"{path}: {exc}") from exc
        if not isinstance(item, dict) or set(item) != {"commit", "service", "image"}:
            raise ReleaseError(f"{path}: expected exactly commit, service, image")
        service = item["service"]
        if service not in SERVICES or service in images:
            raise ReleaseError(f"{path}: unexpected or duplicate service {service!r}")
        images[service] = item["image"]
        revisions.add(item["commit"])
    if len(revisions) != 1:
        raise ReleaseError("mixed source revisions cannot form one release")
    return validate_release({"schema": 1, "commit": revisions.pop(), "images": images})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        release = assemble(args.identity_dir)
        args.output.write_text(json.dumps(release, sort_keys=True, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: immutable release for {release['commit']}: {args.output}")
    except (ReleaseError, OSError) as exc:
        parser.exit(1, f"Release assembly failed: {exc}\n")


if __name__ == "__main__":
    main()
