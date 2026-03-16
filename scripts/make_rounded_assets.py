#!/usr/bin/env python3
"""
Generates rounded-corner PNG versions of README assets.
Run once after updating app-view.png or the app icon.
  python3 scripts/make_rounded_assets.py
"""
from PIL import Image, ImageDraw
from pathlib import Path

ROOT = Path(__file__).parent.parent
ASSETS = ROOT / "EZDisplay/EZDisplay/Assets"
XCASSETS = ROOT / "EZDisplay/EZDisplay/Assets.xcassets/AppIcon.appiconset"

def round_image(src: Path, dst: Path, radius: int) -> None:
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), (w - 1, h - 1)], radius=radius, fill=255)
    img.putalpha(mask)
    img.save(dst)
    print(f"  {dst.name}  ({w}×{h}, radius={radius})")

if __name__ == "__main__":
    print("Generating rounded assets...")
    round_image(XCASSETS / "icon_128x128.png", ASSETS / "icon_rounded.png", radius=28)
    round_image(ASSETS / "app-view.png",        ASSETS / "app-view-rounded.png", radius=18)
    print("Done.")
