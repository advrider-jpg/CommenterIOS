#!/usr/bin/env python3
"""Fail if CI uploads artifacts outside the documented diagnostic allowlist."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = [
    ROOT / ".github" / "workflows" / "ios-ci.yml",
    ROOT / ".github" / "workflows" / "ios-screenshots.yml",
]

ALLOWED_ARTIFACT_NAMES = {
    "commenter-ios-swift-test-diagnostics",
    "commenter-ios-ci-diagnostics",
    "commenter-ios-core-screenshots",
}

ALLOWED_PATHS = {
    "build/swift-test.log",
    "build/ios-ci-xcodebuild.log",
    "build/CommenterIOSBuild.xcresult",
    "build/screenshots/*.png",
    "build/CommenterIOSScreenshots.xcresult",
    "build/screenshot-xcodebuild.log",
}


def upload_blocks(text: str) -> list[str]:
    pattern = re.compile(r"uses:\s+actions/upload-artifact@v4(?P<body>(?:\n\s{8,}.+)*)")
    return [match.group("body") for match in pattern.finditer(text)]


def scalar_after(block: str, key: str) -> str | None:
    match = re.search(rf"\n\s+{re.escape(key)}:\s+(.+)", block)
    return match.group(1).strip() if match else None


def paths_after(block: str) -> list[str]:
    match = re.search(r"\n\s+path:\s*\|\s*(?P<body>(?:\n\s{12,}.+)*)", block)
    if match:
        return [line.strip() for line in match.group("body").splitlines() if line.strip()]
    scalar = scalar_after(block, "path")
    return [scalar] if scalar else []


def main() -> int:
    errors: list[str] = []
    for workflow in WORKFLOWS:
        text = workflow.read_text(encoding="utf-8")
        for block in upload_blocks(text):
            name = scalar_after(block, "name")
            if name not in ALLOWED_ARTIFACT_NAMES:
                errors.append(f"{workflow.name}: unapproved artifact name {name!r}")
            for path in paths_after(block):
                if path not in ALLOWED_PATHS:
                    errors.append(f"{workflow.name}: unapproved artifact path {path!r}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("CI artifact upload names and paths are restricted to the diagnostic allowlist.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
