#!/usr/bin/env python3
"""Enforce immutable GitHub Action refs and least-privilege workflow boundaries."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ACTION = re.compile(r"^\s*(?:-\s*)?uses:\s*(\S+)", re.MULTILINE)
IMMUTABLE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@[a-f0-9]{40}$")


def verify(content: str, filename: str) -> None:
    refs = ACTION.findall(content)
    if not refs:
        raise ValueError(f"{filename}: no Action refs to verify")
    for ref in refs:
        if not IMMUTABLE.fullmatch(ref):
            raise ValueError(f"{filename}: mutable Action ref {ref!r}")
    if re.search(r"^\s*pull_request_target\s*:", content, re.MULTILINE):
        raise ValueError(f"{filename}: privileged pull_request_target is forbidden")
    if re.search(r"^\s*permissions:\s*write-all\s*$", content, re.MULTILINE):
        raise ValueError(f"{filename}: write-all token permission is forbidden")


def main() -> None:
    workflows = sorted((ROOT / ".github/workflows").glob("*.y*ml"))
    if not workflows:
        raise ValueError("missing GitHub workflows")
    for path in workflows:
        verify(path.read_text(encoding="utf-8"), path.name)
    print(f"PASS: immutable Action SHA refs in {len(workflows)} workflows")


if __name__ == "__main__":
    main()
