#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[5]
ASSETS = ROOT / "docs" / "release" / "app-store" / "05_assets"

PALETTE = {
    "paper": "#F6EFDF",
    "surface": "#FFFAEC",
    "deep": "#F4E8D3",
    "ink": "#171411",
    "muted": "#756D61",
    "blue": "#256DC8",
    "soft_blue": "#E6EEF8",
    "green": "#3B8750",
    "soft_green": "#E4F1DD",
    "orange": "#D8792C",
    "soft_orange": "#FAE7D2",
    "gold": "#D7A321",
}


def font(size: int) -> ImageFont.ImageFont:
    for name in ("arial.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def icon(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size), PALETTE["paper"])
    d = ImageDraw.Draw(img)
    pad = int(size * 0.18)
    paper = [pad, int(size * 0.13), size - pad, int(size * 0.79)]
    d.rounded_rectangle(paper, radius=int(size * 0.07), fill=PALETTE["surface"], outline=PALETTE["deep"], width=max(4, size // 64))
    for y in [0.28, 0.39, 0.50]:
        d.line([int(size * 0.30), int(size * y), int(size * 0.70), int(size * y)], fill=PALETTE["muted"], width=max(4, size // 64))
    bubble = [int(size * 0.26), int(size * 0.58), int(size * 0.72), int(size * 0.83)]
    d.rounded_rectangle(bubble, radius=int(size * 0.08), fill=PALETTE["soft_blue"], outline=PALETTE["blue"], width=max(5, size // 56))
    d.polygon([(int(size * 0.38), int(size * 0.82)), (int(size * 0.47), int(size * 0.82)), (int(size * 0.39), int(size * 0.90))], fill=PALETTE["soft_blue"], outline=PALETTE["blue"])
    d.line([int(size * 0.39), int(size * 0.70), int(size * 0.48), int(size * 0.78), int(size * 0.64), int(size * 0.62)], fill=PALETTE["green"], width=max(10, size // 30), joint="curve")
    return img


def save_icon_set() -> None:
    base = ASSETS / "app_icon"
    appicon = base / "AppIcon.appiconset"
    appicon.mkdir(parents=True, exist_ok=True)
    icon(1024).save(base / "report-comment-writer-icon-1024.png")
    for size in (512, 256, 180, 120):
        icon(size).save(base / f"report-comment-writer-icon-{size}.png")
    specs = [
        ("20x20", "2x", 40),
        ("20x20", "3x", 60),
        ("29x29", "2x", 58),
        ("29x29", "3x", 87),
        ("40x40", "2x", 80),
        ("40x40", "3x", 120),
        ("60x60", "2x", 120),
        ("60x60", "3x", 180),
        ("1024x1024", "1x", 1024),
    ]
    images = []
    for logical, scale, pixels in specs:
        filename = "icon-1024.png" if pixels == 1024 else f"icon-{logical}@{scale}.png"
        icon(pixels).save(appicon / filename)
        idiom = "ios-marketing" if pixels == 1024 else "iphone"
        images.append({"idiom": idiom, "size": logical, "scale": scale, "filename": filename})
    (appicon / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8")


def save_screenshot(name: str, caption: str) -> None:
    out = ASSETS / "screenshot_drafts_6_9_inch"
    out.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (1320, 2868), PALETTE["paper"])
    d = ImageDraw.Draw(img)
    d.text((90, 100), caption, fill=PALETTE["ink"], font=font(78))
    d.rounded_rectangle([90, 280, 1230, 2600], radius=64, fill=PALETTE["surface"], outline=PALETTE["deep"], width=6)
    d.text((150, 380), "Room 5", fill=PALETTE["ink"], font=font(54))
    d.text((150, 460), "Ava Ng - Year 5 - English", fill=PALETTE["muted"], font=font(38))
    d.rounded_rectangle([150, 590, 1170, 860], radius=28, fill=PALETTE["soft_blue"])
    d.text((190, 640), "Achievement: At Standard", fill=PALETTE["ink"], font=font(42))
    d.text((190, 710), "Evidence from class work", fill=PALETTE["muted"], font=font(34))
    d.rounded_rectangle([150, 960, 1170, 1440], radius=28, fill="#FFFFFF", outline=PALETTE["deep"], width=4)
    d.text((190, 1010), "Draft comment", fill=PALETTE["ink"], font=font(44))
    d.text((190, 1090), "Ava uses evidence from the text to explain ideas.", fill=PALETTE["muted"], font=font(34))
    d.text((190, 1160), "Her next step is to add more detail when comparing texts.", fill=PALETTE["muted"], font=font(34))
    d.rounded_rectangle([150, 1570, 1170, 1740], radius=28, fill=PALETTE["soft_green"])
    d.text((190, 1620), "Checked by teacher before export", fill=PALETTE["green"], font=font(38))
    img.save(out / name)


def main() -> int:
    save_icon_set()
    captions = [
        ("01-write-report-comments-faster.png", "Write report comments faster"),
        ("02-start-with-your-class-list.png", "Start with your class list"),
        ("03-add-achievement-and-evidence.png", "Add achievement and evidence"),
        ("04-create-a-draft-from-your-notes.png", "Create a draft from your notes"),
        ("05-check-every-comment-yourself.png", "Check every comment yourself"),
        ("06-save-or-share-when-ready.png", "Save or share when ready"),
        ("07-no-sign-in-works-without-wifi.png", "No sign-in. Works without Wi-Fi"),
    ]
    for name, caption in captions:
        save_screenshot(name, caption)
    print("Release assets regenerated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
