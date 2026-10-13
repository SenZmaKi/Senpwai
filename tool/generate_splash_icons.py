"""Generate Android splash artwork from the current app icon.

Requires Pillow. Run after branding so Nightly uses its moon clip too.
Resource names match the flutter_native_splash configuration in pubspec.yaml.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def generate():
    with Image.open(ROOT / "assets/images/senpwai-icon.png") as source:
        icon = source.convert("RGBA")
    # Fit the entire portrait inside Android 12's 192dp circular safe area
    # within its 288dp canvas, following Sentorr's splash generator pattern.
    for theme, background in (("", "#F5F0F1"), ("night-", "#080A0F")):
        for density, scale in DENSITIES.items():
            directory = ROOT / "android/app/src/main/res" / f"drawable-{theme}{density}"
            directory.mkdir(parents=True, exist_ok=True)
            size = round(288 * scale)
            canvas = Image.new("RGBA", (size, size), background)
            side = round(192 * scale / (2 ** 0.5))
            tile = icon.resize((side, side), Image.Resampling.NEAREST)
            offset = (size - side) // 2
            canvas.alpha_composite(tile, (offset, offset))
            canvas.convert("RGB").save(directory / "android12splash.png")
            icon.resize((round(192 * scale), round(192 * scale)),
                        Image.Resampling.NEAREST).save(directory / "splash.png")
    print("Generated Android splash icons from the current Senpwai artwork.")


if __name__ == "__main__":
    generate()
