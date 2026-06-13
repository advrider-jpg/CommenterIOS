#!/usr/bin/env python3
"""Validate release-proof artifacts that cannot be faked by ordinary repo checks."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

ARCHIVE_EVIDENCE = ROOT / "docs" / "validation" / "archive-testflight-evidence.json"
FOUNDATION_MODELS_EVIDENCE = ROOT / "docs" / "validation" / "foundation-models-compile-evidence.json"
TARGET_APP_EVIDENCE = ROOT / "docs" / "validation" / "target-app-open-validation.json"

TARGET_APP_REQUIREMENTS = {
    "docx": {"Word", "Pages"},
    "xlsx": {"Excel", "Numbers", "LibreOffice"},
    "xls": {"Excel", "LibreOffice"},
}


def load_json(path: Path, errors: list[str]) -> dict:
    if not path.exists():
        errors.append(f"Missing release proof artifact: {path.relative_to(ROOT)}")
        return {}
    try:
        with path.open(encoding="utf-8") as handle:
            value = json.load(handle)
    except Exception as exc:
        errors.append(f"{path.relative_to(ROOT)} is not valid JSON: {exc}")
        return {}
    if not isinstance(value, dict):
        errors.append(f"{path.relative_to(ROOT)} must be a JSON object")
        return {}
    return value


def validate_package_resolved(errors: list[str]) -> None:
    if not (ROOT / "Package.resolved").exists():
        errors.append("Package.resolved is missing; run swift package resolve on the release machine and commit the lockfile.")


def validate_archive_evidence(errors: list[str]) -> None:
    evidence = load_json(ARCHIVE_EVIDENCE, errors)
    if not evidence:
        return
    for field in ["xcode_version", "archive_path", "export_method", "team_id", "uploaded_to_testflight_at"]:
        if not str(evidence.get(field, "")).strip():
            errors.append(f"{ARCHIVE_EVIDENCE.relative_to(ROOT)} missing {field}")
    if evidence.get("archive_validation") != "passed":
        errors.append(f"{ARCHIVE_EVIDENCE.relative_to(ROOT)} archive_validation must be 'passed'")


def validate_foundation_models_evidence(errors: list[str]) -> None:
    evidence = load_json(FOUNDATION_MODELS_EVIDENCE, errors)
    if not evidence:
        return
    if evidence.get("foundation_models_compile") != "passed":
        errors.append(f"{FOUNDATION_MODELS_EVIDENCE.relative_to(ROOT)} foundation_models_compile must be 'passed'")
    for field in ["xcode_version", "sdk", "scheme", "commit"]:
        if not str(evidence.get(field, "")).strip():
            errors.append(f"{FOUNDATION_MODELS_EVIDENCE.relative_to(ROOT)} missing {field}")


def validate_target_app_evidence(errors: list[str]) -> None:
    evidence = load_json(TARGET_APP_EVIDENCE, errors)
    if not evidence:
        return
    formats = evidence.get("formats")
    if not isinstance(formats, dict):
        errors.append(f"{TARGET_APP_EVIDENCE.relative_to(ROOT)} must contain a formats object")
        return
    for file_format, required_apps in TARGET_APP_REQUIREMENTS.items():
        records = formats.get(file_format)
        if not isinstance(records, list):
            errors.append(f"{TARGET_APP_EVIDENCE.relative_to(ROOT)} missing {file_format} validation records")
            continue
        passed_apps = {
            str(record.get("app", "")).strip()
            for record in records
            if isinstance(record, dict) and record.get("opened") is True and record.get("private_field_leak_check") == "passed"
        }
        missing = sorted(required_apps - passed_apps)
        if missing:
            errors.append(f"{file_format} target-app validation missing passing records for: {', '.join(missing)}")


def main() -> int:
    errors: list[str] = []
    validate_package_resolved(errors)
    validate_archive_evidence(errors)
    validate_foundation_models_evidence(errors)
    validate_target_app_evidence(errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("Release proof matrix verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
