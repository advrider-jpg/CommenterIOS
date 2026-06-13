#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "docs" / "release" / "app-store"

REQUIRED_FILES = [
    "README.md",
    "INTEGRATION_NOTES.md",
    "MANIFEST.json",
    "01_app_store_connect/app_store_copy_paste.md",
    "01_app_store_connect/app_privacy_answers.md",
    "01_app_store_connect/app_review_notes.md",
    "01_app_store_connect/age_rating_answers.md",
    "01_app_store_connect/remaining_inputs.md",
    "01_app_store_connect/keyword_note.md",
    "02_legal_and_privacy/privacy_policy_draft.md",
    "02_legal_and_privacy/terms_page_draft.md",
    "02_legal_and_privacy/open_source_notices_draft.md",
    "02_legal_and_privacy/school_policy_and_teacher_judgement_note.md",
    "03_brand_and_marketing/brand_guide.md",
    "03_brand_and_marketing/teacher_language_guide.md",
    "03_brand_and_marketing/trust_boundaries.md",
    "03_brand_and_marketing/landing_page_copy.md",
    "03_brand_and_marketing/faq.md",
    "03_brand_and_marketing/press_kit_copy.md",
    "03_brand_and_marketing/launch_messages.md",
    "04_screenshots/screenshot_plan.md",
    "04_screenshots/app_store_screenshot_captions.txt",
    "04_screenshots/screenshot_source_workflow.md",
    "05_assets/app_icon/report-comment-writer-icon-1024.png",
    "05_assets/app_icon/AppIcon.appiconset/Contents.json",
    "05_assets/app_icon/AccentColor.colorset/Contents.json",
    "05_assets/logo/report-comment-writer-logo.svg",
    "05_assets/logo/report-comment-writer-logo.png",
    "05_assets/logo/report-comment-writer-wordmark.png",
    "05_assets/logo/colour-swatches.png",
    "05_assets/social/social-card-1200x630.png",
    "05_assets/social/social-card-1200x630.jpg",
    "05_assets/social/landing-hero-1600x900.png",
    "05_assets/social/landing-hero-1600x900.jpg",
    "06_support_site_drafts/index.html",
    "06_support_site_drafts/support.html",
    "06_support_site_drafts/privacy.html",
    "06_support_site_drafts/terms.html",
    "07_repo_evidence/repo_based_claims.md",
    "07_repo_evidence/source_and_policy_sources.md",
    "07_repo_evidence/release_risks.md",
    "08_after_you_add_contact_details/finalisation_steps.md",
    "08_after_you_add_contact_details/todo_placeholders_to_replace.txt",
    "fastlane/metadata/en-AU/name.txt",
    "fastlane/metadata/en-AU/subtitle.txt",
    "fastlane/metadata/en-AU/promotional_text.txt",
    "fastlane/metadata/en-AU/description.txt",
    "fastlane/metadata/en-AU/keywords.txt",
    "fastlane/metadata/en-AU/support_url.txt",
    "fastlane/metadata/en-AU/marketing_url.txt",
    "fastlane/metadata/en-AU/privacy_url.txt",
    "fastlane/metadata/en-AU/release_notes.txt",
]

SCREENSHOTS = [
    "01-write-report-comments-faster.png",
    "02-start-with-your-class-list.png",
    "03-add-achievement-and-evidence.png",
    "04-create-a-draft-from-your-notes.png",
    "05-check-every-comment-yourself.png",
    "06-save-or-share-when-ready.png",
    "07-no-sign-in-works-without-wifi.png",
]

BANNED_PHRASES = [
    "local-only",
    "local first",
    "local-first",
    "offline-first",
    "AI-powered",
    "LLM",
    "workflow automation",
    "platform",
    "Australian Curriculum aligned",
    "ACARA aligned",
    "government approved",
    "department approved",
    "state approved",
    "school approved",
    "compliant with every",
    "data never leaves your device",
    "data never leaves your phone",
    "perfectly private",
    "secure by default",
]

TEACHER_FACING = [
    "01_app_store_connect/app_store_copy_paste.md",
    "02_legal_and_privacy/privacy_policy_draft.md",
    "02_legal_and_privacy/terms_page_draft.md",
    "02_legal_and_privacy/school_policy_and_teacher_judgement_note.md",
    "03_brand_and_marketing/landing_page_copy.md",
    "03_brand_and_marketing/faq.md",
    "03_brand_and_marketing/press_kit_copy.md",
    "03_brand_and_marketing/launch_messages.md",
    "06_support_site_drafts/index.html",
    "06_support_site_drafts/support.html",
    "06_support_site_drafts/privacy.html",
    "06_support_site_drafts/terms.html",
]


def png_info(path: Path) -> tuple[int, int, int | None]:
    try:
        from PIL import Image
        with Image.open(path) as img:
            alpha_extrema = None
            if img.mode in ("RGBA", "LA"):
                alpha_extrema = img.getchannel("A").getextrema()[0]
            elif img.mode == "P" and "transparency" in img.info:
                alpha_extrema = 0
            return img.width, img.height, alpha_extrema
    except Exception:
        data = path.read_bytes()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            raise ValueError("not a PNG")
        width = int.from_bytes(data[16:20], "big")
        height = int.from_bytes(data[20:24], "big")
        return width, height, None


def add_error(errors: list[str], message: str) -> None:
    errors.append(message)
    print(f"ERROR: {message}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate the App Store release package.")
    parser.add_argument(
        "--strict-submission",
        action="store_true",
        help="Fail draft placeholders and skipped submission checks. Use before App Store Connect upload.",
    )
    return parser.parse_args()


def contains_todo_placeholder(text: str) -> bool:
    return bool(re.search(r"\bTODO\b|TODO_", text, re.IGNORECASE))


def run_strict_validator(errors: list[str], script_name: str, label: str) -> None:
    script = ROOT / "scripts" / script_name
    result = subprocess.run(
        [sys.executable, str(script)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode == 0:
        return
    output = result.stdout.splitlines() + result.stderr.splitlines()
    if not output:
        add_error(errors, f"{label}: {script_name} failed without output")
        return
    for line in output:
        if line.strip():
            add_error(errors, f"{label}: {line}")


def main() -> int:
    args = parse_args()
    errors: list[str] = []

    for rel in REQUIRED_FILES:
        if not (PACKAGE / rel).exists():
            add_error(errors, f"missing required file: {rel}")

    root_metadata = ROOT / "fastlane" / "metadata" / "en-AU"
    for rel in [
        "name.txt", "subtitle.txt", "promotional_text.txt", "description.txt",
        "keywords.txt", "support_url.txt", "marketing_url.txt",
        "privacy_url.txt", "release_notes.txt",
    ]:
        if not (root_metadata / rel).exists():
            add_error(errors, f"missing root fastlane metadata: {rel}")

    name = (root_metadata / "name.txt").read_text(encoding="utf-8").strip()
    subtitle = (root_metadata / "subtitle.txt").read_text(encoding="utf-8").strip()
    promo = (root_metadata / "promotional_text.txt").read_text(encoding="utf-8").strip()
    desc = (root_metadata / "description.txt").read_text(encoding="utf-8").strip()
    keywords = (root_metadata / "keywords.txt").read_text(encoding="utf-8").strip()

    if not 2 <= len(name) <= 30:
        add_error(errors, f"app name length invalid: {len(name)}")
    if len(subtitle) > 30:
        add_error(errors, f"subtitle length invalid: {len(subtitle)}")
    if len(promo) > 170:
        add_error(errors, f"promotional text length invalid: {len(promo)}")
    if len(desc) > 4000:
        add_error(errors, f"description length invalid: {len(desc)}")
    if len(keywords.encode("utf-8")) > 100:
        add_error(errors, "keywords exceed 100 UTF-8 bytes")

    keyword_tokens = [k.strip().lower() for k in keywords.split(",") if k.strip()]
    app_words = {w.lower() for w in re.findall(r"[A-Za-z0-9]+", name)}
    duplicates = app_words.intersection(keyword_tokens)
    if duplicates:
        add_error(errors, f"keywords duplicate app name words: {sorted(duplicates)}")

    competitors = {"chatgpt", "openai", "google", "microsoft", "seesaw", "classdojo"}
    found_competitors = competitors.intersection(keyword_tokens)
    if found_competitors:
        add_error(errors, f"keywords include competitor names: {sorted(found_competitors)}")

    for url_file in ["support_url.txt", "privacy_url.txt", "marketing_url.txt"]:
        value = (root_metadata / url_file).read_text(encoding="utf-8").strip()
        if args.strict_submission and contains_todo_placeholder(value):
            add_error(errors, f"{url_file} still contains a TODO placeholder")
        elif value != "TODO" and not re.match(r"^https://[^\s]+$", value):
            add_error(errors, f"{url_file} must be TODO or a full https URL")

    if args.strict_submission:
        for rel in [
            "01_app_store_connect/app_store_metadata.json",
            "01_app_store_connect/app_information.md",
            "01_app_store_connect/remaining_inputs.md",
            "08_after_you_add_contact_details/todo_placeholders_to_replace.txt",
        ]:
            path = PACKAGE / rel
            if path.exists() and contains_todo_placeholder(path.read_text(encoding="utf-8", errors="ignore")):
                add_error(errors, f"strict submission blocked by TODO placeholder in {rel}")

    for screenshot in SCREENSHOTS:
        path = PACKAGE / "05_assets" / "screenshot_drafts_6_9_inch" / screenshot
        if not path.exists():
            add_error(errors, f"missing screenshot draft: {screenshot}")
            continue
        try:
            width, height, _ = png_info(path)
            if (width, height) != (1320, 2868):
                add_error(errors, f"{screenshot} has {width}x{height}, expected 1320x2868")
        except Exception as exc:
            add_error(errors, f"{screenshot} is not a valid PNG: {exc}")

    icon = PACKAGE / "05_assets" / "app_icon" / "report-comment-writer-icon-1024.png"
    if icon.exists():
        try:
            width, height, alpha_min = png_info(icon)
            if (width, height) != (1024, 1024):
                add_error(errors, f"1024 icon has {width}x{height}")
            if alpha_min is not None and alpha_min < 255:
                add_error(errors, "1024 icon has transparency")
        except Exception as exc:
            add_error(errors, f"1024 icon invalid: {exc}")

    contents_path = PACKAGE / "05_assets" / "app_icon" / "AppIcon.appiconset" / "Contents.json"
    if contents_path.exists():
        try:
            contents = json.loads(contents_path.read_text(encoding="utf-8"))
            for item in contents.get("images", []):
                filename = item.get("filename")
                if filename and not (contents_path.parent / filename).exists():
                    add_error(errors, f"Contents.json references missing icon file: {filename}")
        except Exception as exc:
            add_error(errors, f"invalid Contents.json: {exc}")

    for rel in TEACHER_FACING:
        path = PACKAGE / rel
        if not path.exists():
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            lowered = line.lower()
            for phrase in BANNED_PHRASES:
                if phrase.lower() in lowered:
                    add_error(errors, f"banned phrase in {rel}:{lineno}: {phrase}")

    school_pattern = re.compile(r"\b(Primary School|State School|College|Grammar School|Department of Education)\b", re.I)
    for path in PACKAGE.rglob("*"):
        if path.is_file() and path.suffix.lower() in {".md", ".txt", ".html", ".json"}:
            text = path.read_text(encoding="utf-8", errors="ignore")
            if school_pattern.search(text):
                add_error(errors, f"possible real-looking school/department name in {path.relative_to(PACKAGE)}")

    secret_name_patterns = [".p8", ".mobileprovision", "AuthKey_", "api_key", "FASTLANE_SESSION"]
    for path in ROOT.rglob("*"):
        if ".git" in path.parts:
            continue
        if path.is_file() and any(pattern.lower() in path.name.lower() for pattern in secret_name_patterns):
            add_error(errors, f"possible secret/provisioning file present: {path.relative_to(ROOT)}")

    privacy = ROOT / "Sources" / "CommenterIOSApp" / "Resources" / "PrivacyInfo.xcprivacy"
    if shutil.which("plutil") and privacy.exists():
        result = subprocess.run(["plutil", "-lint", str(privacy)], text=True, capture_output=True)
        if result.returncode != 0:
            add_error(errors, f"plutil failed: {result.stdout}{result.stderr}")
    elif privacy.exists():
        if args.strict_submission:
            add_error(errors, "plutil unavailable; strict submission cannot skip privacy manifest lint")
        else:
            print("WARN: plutil unavailable; privacy manifest lint skipped")

    if args.strict_submission:
        proof_validator = ROOT / "scripts" / "validate_release_proof_matrix.py"
        result = subprocess.run([sys.executable, str(proof_validator)], text=True, capture_output=True)
        if result.returncode != 0:
            for line in (result.stdout + result.stderr).splitlines():
                if line.strip():
                    add_error(errors, f"release proof matrix: {line}")
        run_strict_validator(errors, "validate_dataset_source_transform.py", "dataset source transform")
        run_strict_validator(errors, "validate_localization_plan.py", "localization plan")

    if errors:
        print(f"Validation failed with {len(errors)} error(s).")
        return 1
    print("Validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
