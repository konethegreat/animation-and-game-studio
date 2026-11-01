"""__TITLE__: a minimal Pillow animation starting point.

Every pose is a function of normalized loop time, so the last frame blends
back into the first. Replace ``render_frame`` with your own drawing.
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BG_TOP = (247, 242, 232)
BG_BOTTOM = (238, 229, 212)
INK = (20, 20, 15)
MUTED = (126, 118, 104)
LIME = (201, 242, 78)
LIME_DARK = (150, 196, 40)
CORAL = (255, 90, 60)
GROUND = 0.80
SS = 2


def _gradient(width: int, height: int) -> Image.Image:
    strip = Image.new("RGB", (1, 256))
    for y in range(256):
        f = y / 255
        strip.putpixel(
            (0, y),
            tuple(round(a + (b - a) * f) for a, b in zip(BG_TOP, BG_BOTTOM)),
        )
    return strip.resize((width, height), Image.BILINEAR)


def _font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def render_frame(t: float, width: int, height: int) -> Image.Image:
    t %= 1.0
    big_w, big_h = width * SS, height * SS
    base = _gradient(big_w, big_h)
    overlay = Image.new("RGBA", (big_w, big_h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)

    unit = min(big_w, big_h)
    od.ellipse((big_w * 0.70, -unit * 0.16, big_w * 1.04, unit * 0.34), fill=(*CORAL, 20))

    ground_y = big_h * GROUND
    od.line([(big_w * 0.07, ground_y), (big_w * 0.93, ground_y)], fill=(*INK, 255), width=6 * SS)

    lift = abs(math.sin(math.tau * t)) * big_h * 0.34
    radius = unit * 0.11
    cx = big_w * 0.5 + 26 * SS * math.sin(math.tau * t)
    cy = ground_y - radius - lift
    squash = 1.0 + 0.16 * math.cos(math.tau * 2.0 * t)
    rx, ry = radius * squash, radius / squash

    shadow = 1.0 - lift / (big_h * 0.34) * 0.55
    od.ellipse(
        (cx - rx * 1.4 * shadow, ground_y - 16 * SS * shadow,
         cx + rx * 1.4 * shadow, ground_y + 16 * SS * shadow),
        fill=(20, 20, 15, round(60 * shadow)),
    )

    base = Image.alpha_composite(base.convert("RGBA"), overlay)
    d = ImageDraw.Draw(base)
    d.ellipse((cx - rx, cy - ry + 7 * SS, cx + rx, cy + ry + 7 * SS), fill=LIME_DARK)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=LIME)
    d.ellipse((cx - rx * 0.55, cy - ry * 0.55, cx - rx * 0.05, cy - ry * 0.2), fill=(255, 252, 245))

    d.text((64 * SS, 58 * SS), "__TITLE__", font=_font(34 * SS), fill=INK)
    d.text((64 * SS, 104 * SS), "starter loop", font=_font(19 * SS), fill=MUTED)
    d.text((64 * SS, 140 * SS), "2s / 24 fps", font=_font(17 * SS), fill=CORAL)

    return base.convert("RGB").resize((width, height), Image.LANCZOS)


def render_frames(out: Path, frames: int, width: int, height: int) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for index in range(frames):
        render_frame(index / frames, width, height).save(out / f"frame_{index + 1:04d}.png")
    print(f"  {frames} frames -> {out}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Render __TITLE__")
    parser.add_argument("--out", required=True)
    parser.add_argument("--frames", type=int, default=48)
    parser.add_argument("--width", type=int, default=960)
    parser.add_argument("--height", type=int, default=540)
    args = parser.parse_args()
    render_frames(Path(args.out), args.frames, args.width, args.height)


if __name__ == "__main__":
    main()
