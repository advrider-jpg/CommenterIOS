#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
ASSETS = ROOT / "docs" / "release" / "app-store" / "05_assets"

sys.path.insert(0, str(ROOT / "scripts"))
from validate_app_store_release_package import png_info  # noqa: E402


def main() -> int:
    errors: list[str] = []
    icon = ASSETS / "app_icon" / "report-comment-writer-icon-1024.png"
    screenshots = ASSETS / "screenshot_drafts_6_9_inch"
    contents = ASSETS / "app_icon" / "AppIcon.appiconset" / "Contents.json"

    if not icon.exists():
        errors.append(f"missing {icon}")
    else:
        width, height, alpha_min = png_info(icon)
        if (width, height) != (1024, 1024):
            errors.append(f"icon is {width}x{height}")
        if alpha_min is not None and alpha_min < 255:
            errors.append("icon has transparency")

    if contents.exists():
        data = json.loads(contents.read_text(encoding="utf-8"))
        for item in data.get("images", []):
            filename = item.get("filename")
            if filename and not (contents.parent / filename).exists():
                errors.append(f"Contents.json references missing icon file {filename}")
    else:
        errors.append("missing AppIcon Contents.json")

    for path in sorted(screenshots.glob("*.png")):
        width, height, _ = png_info(path)
        if (width, height) != (1320, 2868):
            errors.append(f"{path.name} is {width}x{height}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Release assets validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
