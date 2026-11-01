"""Bounce: a squash and stretch study rendered with Pillow.

Every value derives from normalized loop time, so frame 0 and frame 1 match.
"""

from __future__ import annotations

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

BG_TOP = (247, 242, 232)
BG_BOTTOM = (238, 229, 212)
INK = (20, 20, 15)
MUTED = (126, 118, 104)
LIME = (201, 242, 78)
LIME_DARK = (150, 196, 40)
CORAL = (255, 90, 60)
CHEEK = (255, 156, 132)
CREAM = (255, 252, 245)

GROUND = 0.80
SEGMENTS = ((0.36, 1.00), (0.20, 0.42), (0.30, 0.66))
IDLE = 0.14
IMPACTS: list[float] = []
_acc = 0.0
for _duration, _height in SEGMENTS:
    _acc += _duration
    IMPACTS.append(round(_acc, 6))
IDLE_START = _acc

SS = 2
_GRADIENTS: dict[tuple[int, int], Image.Image] = {}
_FONTS: dict[tuple[str, int], ImageFont.FreeTypeFont] = {}


def _gradient(width: int, height: int) -> Image.Image:
    key = (width, height)
    if key not in _GRADIENTS:
        strip = Image.new("RGB", (1, 256))
        for y in range(256):
            f = y / 255
            strip.putpixel(
                (0, y),
                tuple(round(a + (b - a) * f) for a, b in zip(BG_TOP, BG_BOTTOM)),
            )
        _GRADIENTS[key] = strip.resize((width, height), Image.BILINEAR)
    return _GRADIENTS[key].copy()


def _font(bold: bool, size: int) -> ImageFont.FreeTypeFont:
    name = "seguisb.ttf" if bold else "segoeui.ttf"
    key = (name, size)
    if key not in _FONTS:
        try:
            _FONTS[key] = ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
        except OSError:
            _FONTS[key] = ImageFont.load_default()
    return _FONTS[key]


def bounce_height(t: float) -> float:
    t %= 1.0
    start = 0.0
    for duration, height in SEGMENTS:
        if t < start + duration:
            u = (t - start) / duration
            return 4.0 * u * (1.0 - u) * height
        start += duration
    return 0.0


def velocity(t: float) -> float:
    t %= 1.0
    start = 0.0
    for duration, height in SEGMENTS:
        if t < start + duration:
            u = (t - start) / duration
            return 4.0 * (1.0 - 2.0 * u) * height / duration
        start += duration
    return 0.0


def since_impact(t: float) -> float:
    t %= 1.0
    return min((t - impact) % 1.0 for impact in IMPACTS)


def squash(t: float) -> float:
    t %= 1.0
    height = bounce_height(t)
    speed = velocity(t)
    since = since_impact(t)

    value = 1.0 - min(0.22, abs(speed) * 0.055)
    if height < 0.16 and speed < 0:
        value = max(value, 1.0 + (1.0 - height / 0.16) * min(0.38, abs(speed) * 0.10))
    if since < 0.10:
        value = max(value, 1.50 - 5.5 * since)
    if IDLE_START <= t < 1.0:
        u = (t - IDLE_START) / IDLE
        value = max(value, 1.04 + 0.14 * u)
    return min(1.55, max(0.72, value))


def center_x(t: float, width: float) -> float:
    return width * 0.5 + 26.0 * math.sin(math.tau * t)


def _antenna(draw: ImageDraw.ImageDraw, base, tip, color, ball_color) -> None:
    bx, by = base
    tx, ty = tip
    control = ((bx + tx) / 2 + (tx - bx) * 0.15, (by + ty) / 2 - abs(ty - by) * 0.05)
    points = []
    for i in range(12):
        f = i / 11
        x = (1 - f) ** 2 * bx + 2 * (1 - f) * f * control[0] + f * f * tx
        y = (1 - f) ** 2 * by + 2 * (1 - f) * f * control[1] + f * f * ty
        points.append((x, y))
    draw.line(points, fill=color, width=6 * SS, joint="curve")
    radius = 13 * SS
    draw.ellipse((tx - radius, ty - radius, tx + radius, ty + radius), fill=ball_color)
    draw.ellipse(
        (tx - radius * 0.35, ty - radius * 0.55, tx + radius * 0.10, ty - radius * 0.15),
        fill=CREAM,
    )


def _draw_dust(overlay: ImageDraw.ImageDraw, t: float, width: float, height: float) -> None:
    ground_y = height * GROUND
    for impact in IMPACTS:
        age = (t - impact) % 1.0
        if age > 0.35:
            continue
        fade = 1.0 - age / 0.35
        ix = center_x(impact, width)
        ring_w = 18 + 150 * (age / 0.35)
        overlay.ellipse(
            (ix - ring_w, ground_y - ring_w * 0.16, ix + ring_w, ground_y + ring_w * 0.16),
            outline=(20, 20, 15, round(70 * fade)),
            width=3,
        )
        rng = random.Random(int(impact * 10_000) + 7)
        for _ in range(10):
            angle = math.pi * (1.05 + 0.9 * rng.random())
            speed = 150 + 220 * rng.random()
            vx, vy = math.cos(angle) * speed, math.sin(angle) * speed
            x = ix + vx * age
            y = ground_y + vy * age + 0.5 * 900 * age * age
            radius = (6 + 9 * rng.random()) * fade
            overlay.ellipse(
                (x - radius, y - radius, x + radius, y + radius),
                fill=(20, 20, 15, round(150 * fade)),
            )


def render_frame(t: float, width: int, height: int) -> Image.Image:
    t %= 1.0
    big_w, big_h = width * SS, height * SS
    base = _gradient(big_w, big_h)
    overlay = Image.new("RGBA", (big_w, big_h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)

    unit = min(big_w, big_h)
    od.ellipse(
        (big_w * 0.70, -unit * 0.16, big_w * 1.04, unit * 0.34),
        fill=(*CORAL, 20),
    )
    od.ellipse(
        (-unit * 0.14, big_h * 0.68, unit * 0.28, big_h * 1.06),
        fill=(*LIME, 34),
    )

    ground_y = big_h * GROUND
    od.line(
        [(big_w * 0.07, ground_y), (big_w * 0.93, ground_y)],
        fill=(*INK, 255),
        width=6 * SS,
    )
    for i in range(17):
        x = big_w * 0.09 + i * (big_w * 0.82 / 16)
        od.line(
            [(x, ground_y + 10 * SS), (x, ground_y + 20 * SS)],
            fill=(*INK, 45),
            width=2 * SS,
        )

    h = bounce_height(t)
    v = velocity(t)
    s = squash(t)
    cx = center_x(t, big_w)
    rx = unit * 0.118 * s
    ry = unit * 0.128 / s
    lift = h * big_h * 0.36
    cy = ground_y - ry - lift - 2 * SS

    shadow_w = rx * 1.5 * (1.0 - h * 0.35)
    shadow_h = 20 * SS * (1.0 - h * 0.45)
    od.ellipse(
        (cx - shadow_w, ground_y + 8 * SS - shadow_h, cx + shadow_w, ground_y + 8 * SS + shadow_h),
        fill=(20, 20, 15, round(58 * (1.0 - h * 0.55))),
    )

    _draw_dust(od, t, big_w, big_h)

    if abs(v) > 2.2:
        side = 1 if v > 0 else -1
        for i in range(2):
            y = cy + side * (ry + 26 * SS + i * 22 * SS)
            x0 = cx - rx * 0.35 + i * 10 * SS
            od.line(
                [(x0, y), (x0 + rx * 0.42, y)],
                fill=(20, 20, 15, 46),
                width=3 * SS,
            )

    base = Image.alpha_composite(base.convert("RGBA"), overlay)
    d = ImageDraw.Draw(base)

    body_box = (cx - rx, cy - ry, cx + rx, cy + ry)
    d.ellipse(
        (cx - rx, cy - ry + 7 * SS, cx + rx, cy + ry + 7 * SS),
        fill=LIME_DARK,
    )
    d.ellipse(body_box, fill=LIME)
    d.ellipse(
        (cx - rx * 0.62, cy - ry * 0.60, cx - rx * 0.02, cy - ry * 0.24),
        fill=CREAM,
    )

    base_point = (cx + rx * 0.02, cy - ry * 0.91)
    reach = ry * (0.85 + max(-0.18, min(0.18, -v * 0.02)))
    sway = max(-rx * 0.5, min(rx * 0.5, -v * 2.2)) + math.sin(math.tau * 3.0 * t) * rx * 0.06
    _antenna(d, base_point, (base_point[0] + sway, base_point[1] - reach), INK, CORAL)

    eye_dx = rx * 0.30
    eye_y = cy - ry * 0.10
    eye_rx = rx * 0.13
    eye_ry = ry * 0.17
    blinking = 0.60 <= t <= 0.645
    look = max(-8.0, min(8.0, v * 0.5)) * SS
    for sign in (-1, 1):
        ex = cx + sign * eye_dx
        if blinking:
            d.line(
                [(ex - eye_rx, eye_y), (ex + eye_rx, eye_y)],
                fill=INK,
                width=6 * SS,
            )
        else:
            d.ellipse(
                (ex - eye_rx, eye_y - eye_ry, ex + eye_rx, eye_y + eye_ry),
                fill=INK,
            )
            d.ellipse(
                (
                    ex - eye_rx * 0.36,
                    eye_y - eye_ry * 0.52 - look * 0.4,
                    ex + eye_rx * 0.10,
                    eye_y - eye_ry * 0.10 - look * 0.4,
                ),
                fill=CREAM,
            )
        d.ellipse(
            (
                cx + sign * rx * 0.56 - rx * 0.10,
                cy + ry * 0.22 - rx * 0.06,
                cx + sign * rx * 0.56 + rx * 0.10,
                cy + ry * 0.22 + rx * 0.06,
            ),
            fill=CHEEK,
        )

    mouth_w = rx * 0.24
    mouth_y = cy + ry * 0.36
    d.arc(
        (cx - mouth_w, mouth_y - mouth_w * 0.7, cx + mouth_w, mouth_y + mouth_w * 0.7),
        start=18,
        end=162,
        fill=INK,
        width=5 * SS,
    )

    tag_x, tag_y = 64 * SS, 58 * SS
    d.rectangle(
        (tag_x, tag_y, tag_x + 18 * SS, tag_y + 18 * SS),
        fill=LIME,
        outline=INK,
        width=2 * SS,
    )
    d.text((tag_x + 32 * SS, tag_y - 6 * SS), "BOUNCE", font=_font(True, 34 * SS), fill=INK)
    d.text(
        (tag_x + 32 * SS, tag_y + 32 * SS),
        "squash + stretch study",
        font=_font(False, 19 * SS),
        fill=MUTED,
    )
    d.text(
        (tag_x, tag_y + 62 * SS),
        "001",
        font=_font(True, 15 * SS),
        fill=CORAL,
    )

    info = "6s loop / 24 fps"
    info_font = _font(False, 17 * SS)
    info_w = d.textlength(info, font=info_font)
    d.text((big_w - 64 * SS - info_w, big_h - 62 * SS), info, font=info_font, fill=MUTED)

    return base.convert("RGB").resize((width, height), Image.LANCZOS)


def render_frames(out: Path, frames: int, width: int, height: int) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for index in range(frames):
        t = index / frames
        render_frame(t, width, height).save(out / f"frame_{index + 1:04d}.png")
        if (index + 1) % 24 == 0:
            print(f"  frame {index + 1}/{frames}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render the Bounce animation")
    parser.add_argument("--out", required=True)
    parser.add_argument("--frames", type=int, default=144)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    args = parser.parse_args()
    render_frames(Path(args.out), args.frames, args.width, args.height)


if __name__ == "__main__":
    main()
