#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = Path(
    os.environ.get(
        "COMMENTERV3_DATASET_SOURCE",
        r"C:\Commenterv3\client\public\data\comment-engine.json",
    )
)
BUNDLED_PATH = ROOT / "Sources" / "CommentEngine" / "Resources" / "comment-engine.json"

EXPECTED_SOURCE_SHA256 = "65E37D45A707CE7D3B18A79CFA06C0507DC7AECEEBF790F0005406DFE4D6B0EF"
EXPECTED_BUNDLED_NORMALIZED_SHA256 = "C6D7F90C06F16C9D4B810BB076FB6647DE1C5831A1ED99E118F470A19F7F48F3"
EXPECTED_COUNTS = {
    "ComponentBank": 56564,
    "RecipeBank": 5,
    "AssembledVariants": 4340,
    "UniquenessGuard": 2,
}


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def normalize_line_endings(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n")


def section_count(root: object, section: str) -> int:
    value = root.get(section) if isinstance(root, dict) else None
    if isinstance(value, list):
        return len(value)
    if isinstance(value, dict):
        return len(value)
    return -1


def main() -> int:
    errors: list[str] = []

    if not SOURCE_PATH.exists():
        errors.append(f"source dataset missing: {SOURCE_PATH}")
    if not BUNDLED_PATH.exists():
        errors.append(f"bundled dataset missing: {BUNDLED_PATH.relative_to(ROOT)}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    source_data = SOURCE_PATH.read_bytes()
    bundled_data = BUNDLED_PATH.read_bytes()
    normalized_source = normalize_line_endings(source_data)

    source_hash = sha256_hex(source_data)
    bundled_normalized_hash = sha256_hex(normalize_line_endings(bundled_data))
    if source_hash != EXPECTED_SOURCE_SHA256:
        errors.append(f"source SHA-256 changed: {source_hash}")
    if bundled_normalized_hash != EXPECTED_BUNDLED_NORMALIZED_SHA256:
        errors.append(f"bundled normalized SHA-256 changed: {bundled_normalized_hash}")
    if normalized_source != normalize_line_endings(bundled_data):
        errors.append("bundled dataset does not exactly match LF-normalized source dataset")

    try:
        root = json.loads(bundled_data.decode("utf-8-sig"))
    except Exception as exc:
        errors.append(f"bundled dataset is not valid UTF-8 JSON: {exc}")
        root = {}

    for section, expected in EXPECTED_COUNTS.items():
        actual = section_count(root, section)
        if actual != expected:
            errors.append(f"{section} count changed: expected {expected}, found {actual}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print("Dataset source transform verified.")
    print(f"Source raw SHA-256: {source_hash}")
    print(f"Bundled normalized SHA-256: {bundled_normalized_hash}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
