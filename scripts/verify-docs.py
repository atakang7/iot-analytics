#!/usr/bin/env python3
"""Check Diátaxis coverage and local Markdown navigation without dependencies."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"!?\[[^\]\n]+\]\(([^)\n]+)\)")
HEADINGS = re.compile(r"^#{1,3}\s+(.+)$", re.MULTILINE)
CATEGORIES = ("tutorials", "how-to", "reference", "explanation")
STYLE = re.compile(r"\b(?:delve|tapestry|pivotal|seamless|groundbreaking)\b", re.I)


def check_links(root: Path, source: Path, contents: str) -> list[str]:
    errors = []
    for raw in LINK.findall(contents):
        destination = raw.strip().split("#", 1)[0]
        if not destination or destination.startswith(("https://", "http://", "mailto:")):
            continue
        destination = unquote(destination)
        target = (source.parent / destination).resolve()
        if not target.is_relative_to(root.resolve()):
            errors.append(f"{source}: link escapes repository: {raw}")
        elif not target.exists():
            errors.append(f"{source}: missing link target: {raw}")
    return errors


def check_style(path: Path, content: str) -> list[str]:
    errors = []
    if "\u2014" in content or "\u2013" in content:
        errors.append(f"{path}: prose contains em/en dash")
    if STYLE.search(content):
        errors.append(f"{path}: prose contains an inflated stock phrase")
    return errors


def verify(root: Path) -> list[str]:
    errors = []
    required = [
        "README.md", "AGENTS.md", "CONTEXT.md", "GLOSSARY.md",
        "docs/README.md",
        *[f"docs/{part}" for part in CATEGORIES],
        "docs/adr",
    ]
    for item in required:
        if not (root / item).exists():
            errors.append(f"required documentation missing: {item}")
    if errors:
        return errors

    readme = (root / "README.md").read_text(encoding="utf-8")
    if len(readme.splitlines()) > 120:
        errors.append("README.md exceeds 120 lines; move detail into docs/")
    agent = (root / "AGENTS.md").read_text(encoding="utf-8")
    if len(agent.splitlines()) > 120:
        errors.append("AGENTS.md exceeds 120 lines; use context pointers")

    docs = sorted((root / "docs").rglob("*.md"))
    for category in CATEGORIES:
        if not any((root / "docs" / category).glob("*.md")):
            errors.append(f"docs/{category}: no pages")
    adrs = list((root / "docs/adr").glob("[0-9][0-9][0-9][0-9]-*.md"))
    if not adrs:
        errors.append("docs/adr: no numbered decisions")
    for adr in adrs:
        text = adr.read_text(encoding="utf-8")
        if "Status: " not in text or "## Context" not in text or "## Decision" not in text or "## Consequences" not in text:
            errors.append(f"{adr}: missing status, context, decision or consequences")

    checked = [root / x for x in ("README.md", "AGENTS.md", "CONTEXT.md", "GLOSSARY.md")] + docs
    for path in checked:
        contents = path.read_text(encoding="utf-8")
        errors.extend(check_links(root, path, contents))
        # Apply prose lint to the curated Diátaxis tree and the four root guides.
        if path.parent == root or path.parent.name in CATEGORIES or path.parent.name == "adr":
            errors.extend(check_style(path, contents))
    return errors


def main():
    errors = verify(ROOT)
    for problem in errors:
        print(problem, file=sys.stderr)
    if errors:
        raise SystemExit(1)
    print("PASS: Diátaxis sections, ADRs, relative links and concise prose")


if __name__ == "__main__":
    main()
