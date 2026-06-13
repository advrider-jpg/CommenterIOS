#!/usr/bin/env python3
"""Validate that the shared Xcode scheme/test scope matches the documented CI contract."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCHEME = ROOT / "CommenterIOS.xcodeproj" / "xcshareddata" / "xcschemes" / "CommenterIOS.xcscheme"
CI_WORKFLOW = ROOT / ".github" / "workflows" / "ios-ci.yml"
SCREENSHOT_WORKFLOW = ROOT / ".github" / "workflows" / "ios-screenshots.yml"


def main() -> int:
    errors: list[str] = []
    if not SCHEME.exists():
        errors.append(f"Missing shared scheme: {SCHEME}")
    else:
        tree = ET.parse(SCHEME)
        root = tree.getroot()
        testable_names = [
            ref.attrib.get("BlueprintName", "")
            for testable in root.findall(".//TestAction/Testables/TestableReference")
            for ref in testable.findall(".//BuildableReference")
        ]
        if testable_names != ["CommenterIOSScreenshotTests"]:
            errors.append(
                "CommenterIOS.xcscheme TestAction must contain only "
                f"CommenterIOSScreenshotTests; found {testable_names or 'none'}"
            )

    ci_text = CI_WORKFLOW.read_text(encoding="utf-8") if CI_WORKFLOW.exists() else ""
    if "swift test" not in ci_text:
        errors.append("ios-ci.yml must run Swift package tests separately from the Xcode screenshot scheme.")
    if "CommenterIOSScreenshotTests/CommenterIOSScreenshotTests/testCoreReportFlowScreenshots" not in ci_text:
        errors.append("ios-ci.yml must run the core screenshot UI test through the shared Xcode scheme.")

    screenshot_text = SCREENSHOT_WORKFLOW.read_text(encoding="utf-8") if SCREENSHOT_WORKFLOW.exists() else ""
    if "scripts/extract_core_screenshots.py" not in ci_text or "scripts/extract_core_screenshots.py" not in screenshot_text:
        errors.append("Both screenshot workflows must use scripts/extract_core_screenshots.py for the required screenshot contract.")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Xcode scheme scope and screenshot workflow contract verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
