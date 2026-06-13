#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "Package.swift"
PLAN = ROOT / "docs" / "validation" / "LOCALIZATION_PLAN.md"


def main() -> int:
    errors: list[str] = []
    package_text = PACKAGE.read_text(encoding="utf-8")
    if 'defaultLocalization: "en"' not in package_text:
        errors.append('Package.swift must declare defaultLocalization: "en"')

    if not PLAN.exists():
        errors.append("docs/validation/LOCALIZATION_PLAN.md is missing")
    else:
        plan_text = PLAN.read_text(encoding="utf-8")
        required_phrases = [
            "English-only",
            "String Catalog",
            "pseudolocalized simulator build",
            "large Dynamic Type",
            "no translated-locale claim",
        ]
        for phrase in required_phrases:
            if phrase not in plan_text:
                errors.append(f"localization plan missing required phrase: {phrase}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("Localization plan verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
