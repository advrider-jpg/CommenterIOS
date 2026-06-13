#!/usr/bin/env python3
"""Export and verify CommenterIOS core-flow screenshots from an xcresult attachment dump."""

from __future__ import annotations

import json
import os
import re
import shutil
import sys
from pathlib import Path


REQUIRED_CORE_SCREENSHOTS = [
    "01-projects-empty",
    "02-worklist-no-project",
    "03-support-diagnostics",
    "04-project-created",
    "05-roster-before-student",
    "06-roster-student-entered",
    "07-subject-selected-english",
    "08-result-before-achievement",
    "09-result-ready-for-generation",
    "10-project-saved-before-generation",
    "11-generated-report-comment",
    "12-export-ready",
    "13-docx-prepared",
    "14-support-after-report",
]


def screenshot_name(value: str) -> str:
    name = Path(value).stem
    return re.sub(r"_\d+_[0-9A-Fa-f-]{36}$", "", name)


def collect_from_manifest(attachment_dir: Path) -> dict[str, Path]:
    manifest_path = attachment_dir / "manifest.json"
    screenshots: dict[str, Path] = {}
    if not manifest_path.exists():
        print("xcresult attachment export did not produce manifest.json; falling back to recursive PNG scan.")
        return screenshots

    def walk(value: object) -> None:
        if isinstance(value, dict):
            exported = value.get("exportedFileName")
            suggested = value.get("suggestedHumanReadableName") or value.get("name")
            if isinstance(exported, str) and isinstance(suggested, str):
                exported_path = attachment_dir / exported
                name = screenshot_name(suggested)
                if exported_path.is_file() and exported.lower().endswith(".png") and name in REQUIRED_CORE_SCREENSHOTS:
                    screenshots[name] = exported_path
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    with manifest_path.open(encoding="utf-8") as handle:
        walk(json.load(handle))
    return screenshots


def collect_recursive_pngs(attachment_dir: Path, screenshots: dict[str, Path]) -> None:
    for root, _, files in os.walk(attachment_dir):
        for filename in files:
            if not filename.lower().endswith(".png"):
                continue
            source = Path(root) / filename
            name = screenshot_name(filename)
            if name in REQUIRED_CORE_SCREENSHOTS:
                screenshots.setdefault(name, source)


def copy_and_verify(attachment_dir: Path, output_dir: Path) -> int:
    output_dir.mkdir(parents=True, exist_ok=True)
    screenshots = {
        name: output_dir / f"{name}.png"
        for name in REQUIRED_CORE_SCREENSHOTS
        if (output_dir / f"{name}.png").is_file()
    }
    screenshots.update(collect_from_manifest(attachment_dir))
    collect_recursive_pngs(attachment_dir, screenshots)

    missing = [name for name in REQUIRED_CORE_SCREENSHOTS if name not in screenshots]
    if missing:
        print(f"Missing required core-flow screenshots after export fallback: {', '.join(missing)}")
        print("Found screenshots:", ", ".join(sorted(screenshots)) or "none")
        for root, _, files in os.walk(attachment_dir):
            for filename in files[:50]:
                print("attachment:", Path(root) / filename)
        return 1

    for name, source in sorted(screenshots.items()):
        destination = output_dir / f"{name}.png"
        if source.resolve() != destination.resolve():
            shutil.copy2(source, destination)

    missing_or_empty = [
        name for name in REQUIRED_CORE_SCREENSHOTS
        if not (output_dir / f"{name}.png").is_file() or (output_dir / f"{name}.png").stat().st_size == 0
    ]
    if missing_or_empty:
        print(f"Missing or empty verified screenshots: {', '.join(missing_or_empty)}")
        return 1

    for path in sorted(output_dir.glob("*.png")):
        print(path)
    return 0


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("Usage: extract_core_screenshots.py <attachment_dir> <output_dir>", file=sys.stderr)
        return 2
    return copy_and_verify(Path(argv[1]), Path(argv[2]))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
