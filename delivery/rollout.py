#!/usr/bin/env python3
"""Fail-closed, operator-initiated deployment of signed Git release identity.

This tool never builds, publishes, alters credentials, or deploys the lab infra.
Plan mode is read-only. Apply mode requires explicit namespace/context consent.
"""
import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path

import yaml

from release import ReleaseError, SERVICES, helm_values
from state import load_state, verify

ROOT = Path(__file__).resolve().parents[1]
CONTEXT = re.compile(r"^[A-Za-z0-9_.:@/-]{3,160}$")
NAMESPACE = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$")
OWNER = re.compile(r"^[a-z0-9][a-z0-9-]{0,38}/[a-z0-9][a-z0-9._-]{0,99}$")
IDENTITY = "https://github.com/{repo}/.github/workflows/publish.yaml@refs/heads/main"
ISSUER = "https://token.actions.githubusercontent.com"


def checked(command, *, cwd=ROOT):
    return subprocess.run(command, cwd=cwd, capture_output=True,
                          text=True, check=True).stdout.strip()


def validate_target(environment, namespace, context, repo, confirm=None, apply=False):
    if environment not in {"dev", "stage", "prod"}:
        raise ReleaseError("Only dev, stage and prod are valid environments")
    if not NAMESPACE.fullmatch(namespace) or len(namespace) > 63:
        raise ReleaseError("Invalid namespace")
    if namespace in {"default", "kube-system", "kube-public", "kube-node-lease"}:
        raise ReleaseError("System namespaces cannot be release destinations")
    if not CONTEXT.fullmatch(context):
        raise ReleaseError("Invalid or ambiguous Kubernetes context")
    if not OWNER.fullmatch(repo):
        raise ReleaseError("Expected GitHub repository OWNER/REPO")
    if apply and confirm != f"{environment}:{namespace}@{context}":
        raise ReleaseError("Explicit --confirm ENV:NAMESPACE@CONTEXT is mandatory")


def ensure_committed_state(environment, state_path):
    relative = state_path.relative_to(ROOT).as_posix()
    committed = checked(["git", "show", f"HEAD:{relative}"])
    actual = state_path.read_text(encoding="utf-8").strip()
    # Textual equality prevents deploying an uncommitted local state edit.
    if committed.strip() != actual:
        raise ReleaseError(f"Uncommitted state file: {relative}")


def desired_release(environment, expected_repo, history_ref="HEAD"):
    states = verify(ROOT / "state", history_ref)
    current = states[environment]
    release = current["release"]
    if release is None:
        raise ReleaseError(f"{environment} state has no published release")
    for service, image in release["images"].items():
        prefix = f"ghcr.io/{expected_repo}/{service}@sha256:"
        if not image.startswith(prefix):
            raise ReleaseError(f"{service}: digest is not from expected repository")
    ensure_committed_state(environment, ROOT / "state" / f"{environment}.json")
    return release


def image_signature_commands(release, expected_repo):
    identity = IDENTITY.format(repo=expected_repo)
    return [
        ["cosign", "verify", "--certificate-identity", identity,
         "--certificate-oidc-issuer", ISSUER, release["images"][name]]
        for name in sorted(SERVICES)
    ]


def verify_rendered(manifests, release):
    documents = [doc for doc in yaml.safe_load_all(manifests) if doc]
    allowed = {"Deployment", "Service", "CronJob"}
    if not documents or any(d.get("kind") not in allowed for d in documents):
        raise ReleaseError("Unexpected infrastructure, build, route or privileged resource in app release")
    observed = {}
    for doc in documents:
        kind = doc["kind"]
        name = doc["metadata"]["name"]
        if kind not in {"Deployment", "CronJob"}:
            continue
        pod = (doc["spec"]["jobTemplate"]["spec"]["template"]["spec"]
               if kind == "CronJob" else doc["spec"]["template"]["spec"])
        containers = pod["containers"]
        if len(containers) != 1 or name in observed:
            raise ReleaseError("Invalid or duplicate app workload")
        observed[name] = containers[0]["image"]
    if observed != release["images"]:
        raise ReleaseError("Rendered chart images do not exactly match all six Git digests")
    return documents


def helm_commands(environment, namespace, context, values_file, rendered):
    name = f"iot-apps-{environment}"
    chart = str(ROOT / "iot-helm/charts/apps")
    common = ["--namespace", namespace, "--kube-context", context]
    template = ["helm", "template", name, chart, "-f", str(values_file),
                *common]
    server_dryrun = ["kubectl", "--context", context, "-n", namespace,
                     "apply", "--dry-run=server", "-f", str(rendered)]
    upgrade = ["helm", "upgrade", "--install", name, chart,
               "-f", str(values_file), *common,
               "--atomic", "--cleanup-on-fail", "--wait", "--timeout", "10m",
               "--history-max", "10"]
    return name, template, server_dryrun, upgrade


def assert_live_images(environment, namespace, context, release):
    for name in sorted(SERVICES):
        kind = "cronjob" if name == "kpi-job" else "deployment"
        raw = checked(["kubectl", "--context", context, "-n", namespace,
                       "get", kind, name, "-o", "json"])
        obj = json.loads(raw)
        if kind == "cronjob":
            containers = obj["spec"]["jobTemplate"]["spec"]["template"]["spec"]["containers"]
        else:
            containers = obj["spec"]["template"]["spec"]["containers"]
            ready = obj.get("status", {}).get("readyReplicas", 0)
            desired = obj["spec"].get("replicas", 1)
            if ready != desired:
                raise ReleaseError(f"{name}: not Ready ({ready}/{desired})")
        if len(containers) != 1 or containers[0]["image"] != release["images"][name]:
            raise ReleaseError(f"{name}: runtime image does not match Git release")


def verify_namespace(namespace, context):
    actual = checked(["kubectl", "config", "current-context"])
    if actual != context:
        raise ReleaseError("Current context differs from explicitly chosen context")
    data = json.loads(checked(["kubectl", "--context", context, "get",
                               "namespace", namespace, "-o", "json"]))
    labels = data["metadata"].get("labels") or {}
    if labels.get("iot-release-allowed") != "true":
        raise ReleaseError("Namespace is not explicitly opted in to signed releases")


def execute(args):
    validate_target(args.environment, args.namespace, args.context,
                    args.repository, confirm=args.confirm, apply=args.apply)
    release = desired_release(args.environment, args.repository)
    state = release["commit"]
    print(f"Git state: {args.environment} -> {state}", flush=True)

    with tempfile.TemporaryDirectory(prefix="iot-release-") as tmp:
        root = Path(tmp)
        values = root / "values.json"
        rendered = root / "manifests.yaml"
        values.write_text(json.dumps(helm_values(release)["apps"], sort_keys=True) + "\n")
        name, template, dryrun, upgrade = helm_commands(
            args.environment, args.namespace, args.context, values, rendered
        )
        rendered.write_text(checked(template) + "\n")
        verify_rendered(rendered.read_text(), release)

        # Offline plan never contacts the cluster and cannot perform an install.
        if not args.apply:
            print(f"PLAN ONLY: {name}, {len(SERVICES)} immutable image digests")
            print("No signatures, cluster state, or deployment have been verified")
            return

        verify_namespace(args.namespace, args.context)
        for command in image_signature_commands(release, args.repository):
            checked(command)
        print("PASS: all six Git image identities have verified Cosign signatures")

        checked(dryrun)
        print("PASS: Kubernetes API accepted server-side manifest dry-run")

        # Release name is separate from the lab's parent Helm release, so an
        # app-only upgrade cannot remove stateful Kafka/TimescaleDB resources.
        previous = None
        try:
            status = json.loads(checked(["helm", "status", name, "-o", "json",
                                         "--namespace", args.namespace,
                                         "--kube-context", args.context]))
        except subprocess.CalledProcessError:
            status = None
        if status:
            current_chart = status.get("chart", {}).get("metadata", {}).get("name")
            if current_chart != "apps":
                raise ReleaseError("Existing Helm release is not owned by apps chart")
            previous = status.get("version")
            if type(previous) is not int or previous < 1:
                raise ReleaseError("Existing Helm release has invalid revision")

        checked(upgrade)
        try:
            assert_live_images(args.environment, args.namespace, args.context, release)
        except (ReleaseError, subprocess.CalledProcessError) as failure:
            if previous:
                checked(["helm", "rollback", name, str(previous),
                         "--namespace", args.namespace, "--kube-context", args.context,
                         "--wait", "--timeout", "10m"])
                raise ReleaseError("Post-rollout image check failed; restored prior revision") from failure
            checked(["helm", "uninstall", name, "--namespace", args.namespace,
                     "--kube-context", args.context])
            raise ReleaseError("Initial rollout failed post-check; uninstalled new app release") from failure

        print("PASS: all runtime images match Git and application deployments are Ready")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--environment", required=True, choices=("dev", "stage", "prod"))
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--context", required=True)
    parser.add_argument("--repository", required=True,
                        help="OWNER/REPO hosting the trusted main publishing workflow")
    parser.add_argument("--apply", action="store_true", help="Allow real deployment")
    parser.add_argument("--confirm", help="Must exactly equal ENV:NAMESPACE@CONTEXT")
    args = parser.parse_args()
    try:
        execute(args)
    except (ReleaseError, OSError, json.JSONDecodeError,
            subprocess.CalledProcessError) as exc:
        parser.exit(1, f"Release aborted: {exc}\n")


if __name__ == "__main__":
    main()
