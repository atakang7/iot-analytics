#!/usr/bin/env python3
"""Git-tracked release intent: dev -> stage -> prod without rebuilding.

Git history checks are intentionally required for stage/prod so a PR cannot
promote a digest that never appeared in the preceding environment's history.
"""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

from release import ReleaseError, load_release, validate_release

ENVIRONMENTS = ("dev", "stage", "prod")
SOURCE = {"stage": "dev", "prod": "stage"}
ROOT = Path(__file__).resolve().parents[1]


def validate_state(value, environment):
    if not isinstance(value, dict) or set(value) != {"schema", "environment", "release"}:
        raise ReleaseError("state must contain exactly schema, environment, release")
    if type(value["schema"]) is not int or value["schema"] != 1:
        raise ReleaseError("unsupported environment state schema")
    if value["environment"] != environment:
        raise ReleaseError(f"expected {environment} state, got {value['environment']!r}")
    if value["release"] is not None:
        validate_release(value["release"])
    return value


def load_state(path: Path, environment: str):
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ReleaseError(f"{path}: {exc}") from exc
    return validate_state(value, environment)


def save_state(path: Path, state):
    """Atomic replacement; never corrupt a checked-in state file on interruption."""
    state = validate_state(state, state["environment"])
    directory = path.parent
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8",
                                     prefix=".state-", suffix=".json",
                                     dir=directory, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(state, output, sort_keys=True, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    os.replace(temporary, path)


def record_dev(existing, release):
    validate_state(existing, "dev")
    validate_release(release)
    return {"schema": 1, "environment": "dev", "release": release}


def promote(source, target):
    source_env = source["environment"]
    target_env = target["environment"]
    validate_state(source, source_env)
    validate_state(target, target_env)
    if SOURCE.get(target_env) != source_env:
        raise ReleaseError("promotion must advance exactly dev -> stage -> prod")
    if source["release"] is None:
        raise ReleaseError(f"{source_env} contains no release to promote")
    return {"schema": 1, "environment": target_env, "release": source["release"]}


def history_contains_release(environment, release, ref):
    """Only historical preceding-environment *commits* authorize promotion."""
    path = f"state/{environment}.json"
    command = ["git", "log", "--format=%H", ref, "--", path]
    try:
        commits = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 check=True).stdout.splitlines()
    except subprocess.CalledProcessError as exc:
        raise ReleaseError(f"cannot inspect git history of {ref}: {exc.stderr}") from exc
    for commit in commits:
        result = subprocess.run(["git", "show", f"{commit}:{path}"],
                                cwd=ROOT, capture_output=True, text=True)
        if result.returncode:
            continue
        try:
            past = validate_state(json.loads(result.stdout), environment)
        except (ReleaseError, json.JSONDecodeError):
            continue
        if past["release"] == release:
            return True
    return False


def verify(root: Path, history_ref):
    states = {env: load_state(root / f"{env}.json", env) for env in ENVIRONMENTS}
    if history_ref:
        for env, predecessor in SOURCE.items():
            release = states[env]["release"]
            if release is not None and not history_contains_release(predecessor, release, history_ref):
                raise ReleaseError(
                    f"{env} release was never recorded in {predecessor} Git history at {history_ref}"
                )
    return states


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)
    check = sub.add_parser("verify")
    check.add_argument("--root", type=Path, default=ROOT / "state")
    check.add_argument("--history-ref", help="existing Git ref, e.g. origin/main")
    record = sub.add_parser("record-dev")
    record.add_argument("release", type=Path)
    record.add_argument("--target", type=Path, default=ROOT / "state/dev.json")
    move = sub.add_parser("promote")
    move.add_argument("--source", type=Path, required=True)
    move.add_argument("--target", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.action == "verify":
            verify(args.root, args.history_ref)
            print("PASS: valid environment state and promotion history")
        elif args.action == "record-dev":
            existing = load_state(args.target, "dev")
            save_state(args.target, record_dev(existing, load_release(args.release)))
            print(f"Recorded dev release intent: {args.target}")
        else:
            source_env = args.source.stem
            target_env = args.target.stem
            if source_env not in ENVIRONMENTS or target_env not in ENVIRONMENTS:
                raise ReleaseError("state filenames must be dev.json, stage.json or prod.json")
            source = load_state(args.source, source_env)
            target = load_state(args.target, target_env)
            save_state(args.target, promote(source, target))
            print(f"Proposed {source_env} -> {target_env} promotion: {args.target}")
    except (ReleaseError, OSError, KeyError) as exc:
        parser.exit(1, f"State rejected: {exc}\n")


if __name__ == "__main__":
    main()
