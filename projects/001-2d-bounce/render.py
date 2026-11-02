"""Paper City: a paper courier bounces down a card stock street.

Everything is drawn from world space at twice the output resolution, then
grain and a vignette are applied at the final size. All motion is a function
of loop time, so the last frame meets the first.
"""

from __future__ import annotations

import argparse
import math
import random
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 2
FPS = 24
FRAMES = 144

VIEW_WIDTH = 7.0
GROUND_FRACTION = 0.86
ANCHOR_FRACTION = 0.40

TILE_FRONT = 8.0
TILE_BACK = 3.2
TILE_FAR = 1.6

BOUNCES = 5
PHASE = 0.0
CONTACT = 0.055
BALL_LEAD = 0.10
BALL_RADIUS = 0.325

SKY_TOP = (252, 246, 234)
SKY_BOTTOM = (244, 230, 209)
INK = (24, 21, 18)
INK_SOFT = (54, 48, 41)
PAPER = (251, 244, 231)
PAPER_LIGHT = (254, 249, 239)
PAPER_MID = (246, 235, 217)
PAPER_DARK = (236, 219, 194)
HAZE = (232, 213, 188)
ACCENT = (198, 91, 54)
ACCENT_DARK = (162, 69, 39)
ACCENT_LIGHT = (224, 128, 86)
WARM = (255, 199, 121)
WARM_PALE = (255, 227, 176)
SAGE = (139, 144, 111)
SAGE_DARK = (110, 116, 86)
SHADOW = (150, 124, 95)
SKIN = (255, 236, 214)
CREAM_SCARF = (250, 239, 220)
BODY = (200, 92, 55)
BODY_DARK = (150, 62, 36)

FACADES = (PAPER, PAPER_MID, (250, 238, 224), (253, 247, 236))
BACK_TONES = ((233, 216, 192), (238, 223, 201), (229, 211, 186))

_GLOWS: dict[tuple[int, tuple[int, int, int], int], Image.Image] = {}
_BACKGROUNDS: dict[tuple[int, int], Image.Image] = {}
_POST: dict[tuple[int, int], tuple[np.ndarray, np.ndarray]] = {}


def _mix(a, b, f: float) -> tuple[int, int, int]:
    return tuple(round(x + (y - x) * f) for x, y in zip(a, b))


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _period(t: float) -> float:
    return t % 1.0


def _smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge1 == edge0:
        return 0.0
    x = _clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


# ---------------------------------------------------------------- motion


def ball_state(t: float) -> dict[str, float]:
    """Height, squash and lean of the courier for one loop time."""
    t = _period(t)
    u = (t * BOUNCES + PHASE) % 1.0
    amplitude = (
        0.72
        + 0.10 * math.sin(2.0 * math.tau * t + 0.6)
        + 0.05 * math.sin(3.0 * math.tau * t + 1.7)
    )
    if u < CONTACT:
        z = 0.0
        vertical = 0.0
        contact = 1.0 - u / CONTACT
    else:
        a = (u - CONTACT) / (1.0 - CONTACT)
        z = 4.0 * a * (1.0 - a) * amplitude
        vertical = 4.0 * (1.0 - 2.0 * a) * amplitude / (1.0 - CONTACT)
        contact = 0.0
    ground = _smoothstep(0.0, 0.12, z)
    stretch = 0.06 * _clamp(abs(vertical) / 2.4, 0.0, 1.0)
    squash = _clamp(1.0 + stretch - 0.24 * (1.0 - ground), 0.72, 1.08)
    lean = 2.0 + 1.6 * math.sin(2.0 * math.tau * t + 0.4) + 2.4 * contact
    return {
        "z": z,
        "vertical": vertical,
        "contact": contact,
        "squash": squash,
        "lean": _clamp(lean, -7.0, 7.0),
    }


def find_apex(start: float = 0.0, end: float = 1.0, steps: int = 240) -> float:
    best_t, best_z = start, -1.0
    for index in range(steps + 1):
        t = start + (end - start) * index / steps
        z = ball_state(t)["z"]
        if z > best_z:
            best_z, best_t = z, t
    return best_t


def ball_world_x(t: float) -> float:
    t = _period(t)
    return t * TILE_FRONT + BALL_LEAD + 0.20 * math.sin(2.0 * math.tau * t + 0.8)


def _impact_light(t: float, x: float, z: float) -> float:
    total = 0.0
    for k in range(BOUNCES):
        moment = k / BOUNCES
        age = (t - moment) % 1.0
        if age > 0.55:
            continue
        ix = ball_world_x(moment)
        dx = (x - ix) / 1.15
        dz = (z - 0.45) / 1.6
        total += math.exp(-(dx * dx + dz * dz)) * (1.0 - age / 0.55)
    return _clamp(total, 0.0, 1.0)


def _recent_impacts(t: float, limit: float = 0.34) -> list[tuple[float, float]]:
    out = []
    for k in range(BOUNCES):
        moment = k / BOUNCES
        age = (t - moment) % 1.0
        if age < limit:
            out.append((age, ball_world_x(moment)))
    return out


# ---------------------------------------------------------------- layout


@dataclass
class Window:
    x: float
    z: float
    w: float
    h: float
    lit: bool
    curtain: bool
    box: bool
    shutter: bool = False


@dataclass
class Facade:
    x: float
    w: float
    h: float
    tone: tuple[int, int, int]
    roof: str
    windows: list[Window] = field(default_factory=list)
    door: float = 0.0
    shop: bool = False
    awning: bool = False
    fire_escape: bool = False
    balcony: float = 0.0
    sign: int = 0
    seed: int = 0
    parapet: float = 0.10
    band: float = 0.0


def _front_tile() -> tuple[list[Facade], list[tuple[float, float, float]]]:
    rng = random.Random(41)
    facades: list[Facade] = []
    x = 0.0
    while x < TILE_FRONT - 0.55:
        width = rng.uniform(1.00, 1.70)
        if x + width > TILE_FRONT:
            width = TILE_FRONT - x
        height = rng.uniform(1.28, 2.34)
        if rng.random() < 0.12:
            height += rng.uniform(0.28, 0.62)
        tone = rng.choice(FACADES)
        facade = Facade(
            x=x,
            w=width,
            h=height,
            tone=tone,
            roof=rng.choice(["tank", "chimney", "antenna", "plants", "cat", "vent"]),
            seed=rng.randrange(10_000),
            parapet=rng.choice([0.07, 0.10, 0.14]),
        )
        margin = 0.19
        usable = facade.w - margin * 2.0
        columns = max(2, int(usable / 0.34))
        rows = max(1, int((height - 1.02) / 0.38))
        for column in range(columns):
            for row in range(rows):
                if rng.random() < 0.08:
                    continue
                cx = facade.x + margin + (column + 0.5) * usable / columns
                cz = 0.92 + row * 0.38
                if cz + 0.13 > height - 0.24:
                    continue
                facade.windows.append(
                    Window(
                        x=cx,
                        z=cz,
                        w=0.13,
                        h=0.18,
                        lit=rng.random() < 0.15,
                        curtain=rng.random() < 0.20,
                        box=rng.random() < 0.20,
                        shutter=rng.random() < 0.18,
                    )
                )
        facade.door = facade.x + rng.uniform(0.16, 0.30)
        facade.shop = facade.w > 1.02 and rng.random() < 0.72
        facade.awning = facade.shop and rng.random() < 0.82
        facade.fire_escape = height > 2.15 and rng.random() < 0.20
        facade.balcony = 0.0
        if height > 1.9 and rng.random() < 0.24:
            facade.balcony = 0.92 + 0.38 * rng.randrange(max(1, rows - 1))
        facade.sign = rng.randrange(3)
        facade.band = rng.uniform(0.55, 0.95) if rng.random() < 0.30 else 0.0
        facades.append(facade)
        x += width + rng.choice([0.0, 0.0, 0.04, 0.09])

    garlands: list[tuple[float, float, float]] = []
    for index in range(len(facades) - 1):
        left, right = facades[index], facades[index + 1]
        if min(left.h, right.h) < 1.65:
            continue
        gap = right.x - (left.x + left.w)
        centre = (left.x + left.w + right.x) / 2.0
        span = 1.50 + gap * 0.5
        shoulder = min(left.h, right.h) - 0.26
        garlands.append((centre - span / 2.0, centre + span / 2.0, min(shoulder, 1.60)))
    last, first = facades[-1], facades[0]
    if min(last.h, first.h) > 1.65:
        centre = (last.x + last.w + TILE_FRONT + first.x) / 2.0
        garlands.append((centre - 0.70, centre + 0.70, 1.56))
    return facades, garlands


def _back_tile() -> list[Facade]:
    rng = random.Random(73)
    facades: list[Facade] = []
    x = 0.0
    while x < TILE_BACK - 0.35:
        width = rng.uniform(0.50, 0.90)
        if x + width > TILE_BACK:
            width = TILE_BACK - x
        height = rng.uniform(1.70, 2.75)
        if rng.random() < 0.16:
            height += rng.uniform(0.35, 0.70)
        facade = Facade(
            x=x,
            w=width,
            h=height,
            tone=rng.choice(BACK_TONES),
            roof=rng.choice(["tank", "chimney", "antenna", "plain", "vent"]),
            seed=rng.randrange(10_000),
            parapet=0.06,
        )
        columns = max(1, int((width - 0.16) / 0.26))
        rows = max(1, int((height - 0.55) / 0.42))
        for column in range(columns):
            for row in range(rows):
                facade.windows.append(
                    Window(
                        x=facade.x + 0.10 + (column + 0.5) * (width - 0.20) / columns,
                        z=0.55 + row * 0.42,
                        w=0.10,
                        h=0.15,
                        lit=False,
                        curtain=False,
                        box=False,
                    )
                )
        facades.append(facade)
        x += width + rng.choice([0.02, 0.06, 0.14])
    return facades


def _far_tile() -> list[tuple[float, float, str]]:
    rng = random.Random(97)
    shapes: list[tuple[float, float, str]] = []
    x = 0.0
    while x < TILE_FAR - 0.12:
        width = rng.uniform(0.16, 0.40)
        if x + width > TILE_FAR:
            width = TILE_FAR - x
        height = rng.uniform(0.35, 1.20)
        kind = "flat"
        roll = rng.random()
        if roll < 0.12:
            kind = "dome"
        elif roll < 0.20:
            kind = "spire"
        shapes.append((x, width, str(round(height, 3)) + ":" + kind))
        x += width + rng.uniform(0.015, 0.08)
    return shapes


FRONT, GARLANDS = _front_tile()
BACK = _back_tile()
FAR = _far_tile()

LAMPS = (0.72, 3.28, 5.86)
TREES = ((1.45, 0.95), (4.55, 0.85), (7.12, 0.78))
BENCH = 2.52
CRATES = 6.55
HYDRANT = 3.95
MAILBOX = 5.20

MID_SHEETS = (
    (1.22, 0.34, 0.15, 0.20, -18.0, 0.2, 0.06),
    (2.32, 1.92, 0.14, 0.19, 14.0, 0.5, 0.05),
    (3.98, 0.26, 0.16, 0.21, 24.0, 0.8, 0.04),
    (5.44, 1.78, 0.13, 0.18, -9.0, 0.35, 0.05),
    (6.86, 0.30, 0.15, 0.19, 16.0, 0.65, 0.04),
)

CLOUDS = (
    (0.17, 0.135, 1.00, 0.2),
    (0.52, 0.205, 0.70, 2.1),
    (0.83, 0.105, 0.84, 4.0),
)

BIRDS = (
    (0.24, 0.30, 0.4),
    (0.29, 0.265, 1.7),
    (0.34, 0.315, 3.1),
)


# ---------------------------------------------------------------- sprites


def _glow_sprite(size: int, color: tuple[int, int, int], level: int) -> Image.Image:
    key = (size // 4, color, level)
    cached = _GLOWS.get(key)
    if cached is not None:
        return cached
    side = max(8, size // 4 * 4)
    grid = np.linspace(-1.0, 1.0, side, dtype=np.float32)
    xx, yy = np.meshgrid(grid, grid)
    radius = np.sqrt(xx * xx + yy * yy)
    falloff = np.clip(1.0 - radius, 0.0, 1.0) ** 2.1
    alpha = (falloff * 255.0 * (level / 7.0) * 0.9).astype(np.uint8)
    rgba = np.zeros((side, side, 4), dtype=np.uint8)
    rgba[..., 0] = color[0]
    rgba[..., 1] = color[1]
    rgba[..., 2] = color[2]
    rgba[..., 3] = alpha
    sprite = Image.fromarray(rgba, "RGBA")
    _GLOWS[key] = sprite
    return sprite


def _background(width: int, height: int) -> Image.Image:
    key = (width, height)
    cached = _BACKGROUNDS.get(key)
    if cached is not None:
        return cached
    top = np.array(SKY_TOP, dtype=np.float32)
    bottom = np.array(SKY_BOTTOM, dtype=np.float32)
    ramp = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None, None]
    pixels = top * (1.0 - ramp) + bottom * ramp
    pixels = np.repeat(pixels, width, axis=1)

    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    sun_x, sun_y = width * 0.795, height * 0.175
    distance = np.hypot(xx - sun_x, yy - sun_y) / (width * 0.34)
    glow = np.exp(-(distance ** 1.55)) * 0.78
    sun_tone = np.array((255, 233, 198), dtype=np.float32)
    pixels = pixels + glow[..., None] * (sun_tone - pixels)

    disc = np.hypot(xx - sun_x, yy - sun_y) / (width * 0.050)
    pixels = pixels * (1.0 - np.clip(1.15 - disc[..., None], 0.0, 1.0) * 0.35)
    pixels = np.where(disc[..., None] < 1.0, np.array((255, 250, 236), np.float32), pixels)

    horizon = np.exp(-(((yy - height * 0.55) / (height * 0.20)) ** 2)) * 0.10
    pixels = pixels + horizon[..., None] * (np.array((255, 242, 217), np.float32) - pixels)

    texture = np.random.default_rng(5).random((16, 28)).astype(np.float32)
    texture = np.asarray(
        Image.fromarray((texture * 255).astype(np.uint8)).resize(
            (width, height), Image.BICUBIC
        ),
        dtype=np.float32,
    ) / 255.0 - 0.5
    pixels = pixels + texture[..., None] * 2.4

    image = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8), "RGB")
    draw = ImageDraw.Draw(image, "RGBA")
    ring = width * 0.050 * 1.22
    draw.ellipse(
        (sun_x - ring, sun_y - ring, sun_x + ring, sun_y + ring),
        outline=(255, 243, 222, 52), width=max(1, width // 900),
    )
    _BACKGROUNDS[key] = image
    return image


def _post_maps(width: int, height: int) -> tuple[np.ndarray, np.ndarray]:
    key = (width, height)
    cached = _POST.get(key)
    if cached is not None:
        return cached
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    nx = (xx - width * 0.5) / (width * 0.5)
    ny = (yy - height * 0.5) / (height * 0.5)
    radius = np.sqrt(nx * nx + ny * ny) / 1.25
    vignette = 1.0 - 0.085 * np.clip(radius, 0.0, 1.0) ** 2.2

    fibre = np.random.default_rng(11).random((height // 12 + 2, width // 12 + 2)).astype(np.float32)
    fibre = np.asarray(
        Image.fromarray((fibre * 255).astype(np.uint8)).resize(
            (width, height), Image.BICUBIC
        ),
        dtype=np.float32,
    ) / 255.0 - 0.5
    _POST[key] = (vignette.astype(np.float32), fibre.astype(np.float32))
    return _POST[key]


# ---------------------------------------------------------------- pieces


class Frame:
    def __init__(self, width: int, height: int, t: float) -> None:
        self.w = width
        self.h = height
        self.out_w = max(1, width // SS)
        self.out_h = max(1, height // SS)
        self.t = _period(t)
        self.scale = width / VIEW_WIDTH
        self.ground = height * GROUND_FRACTION
        self.anchor = width * ANCHOR_FRACTION
        self.image = _background(width, height).copy()
        self.draw = ImageDraw.Draw(self.image, "RGBA")
        self.line = max(2, int(self.scale * 0.0075))

    # geometry
    def sx(self, x: float, scroll: float) -> float:
        return self.anchor + (x - scroll) * self.scale

    def sy(self, z: float) -> float:
        return self.ground - z * self.scale

    def unit(self, value: float) -> float:
        return value * self.scale

    # ----------------------------------------------------------------- sky
    def sky(self) -> None:
        for index, (base_x, base_y, size, phase) in enumerate(CLOUDS):
            drift = 0.018 * math.sin(math.tau * self.t + phase)
            cx = (base_x + drift) * self.w
            cy = base_y * self.h
            span = self.h * 0.095 * size
            shadow = (214, 196, 168, 46)
            cream = (255, 251, 242, 232)
            blobs = (
                (-0.55, 0.10, 0.34),
                (-0.18, 0.00, 0.44),
                (0.22, 0.03, 0.38),
                (0.60, 0.12, 0.28),
            )
            for dx, dy, radius in blobs:
                x = cx + dx * span
                y = cy + dy * span
                r = radius * span
                self.draw.ellipse((x - r, y - r + span * 0.10, x + r, y + r + span * 0.10), fill=shadow)
            for dx, dy, radius in blobs:
                x = cx + dx * span
                y = cy + dy * span
                r = radius * span
                self.draw.ellipse((x - r, y - r, x + r, y + r), fill=cream)

        for base_x, base_y, phase in BIRDS:
            drift = 0.010 * math.sin(math.tau * self.t + phase)
            x = (base_x + drift) * self.w
            y = base_y * self.h + self.h * 0.004 * math.sin(math.tau * self.t * 2 + phase)
            span = self.h * 0.011
            lift = span * 0.55
            flap = 0.75 + 0.25 * math.sin(math.tau * self.t * 2 + phase)
            for side in (-1, 1):
                self.draw.arc(
                    (
                        x + side * span - span * 0.5,
                        y - lift * flap,
                        x + side * span + span * 0.5,
                        y + lift * flap,
                    ),
                    start=200 if side < 0 else 290,
                    end=340 if side < 0 else 70,
                    fill=(*INK, 150),
                    width=max(1, self.line // 2),
                )
        self._plane()

    def _plane(self) -> None:
        u = self.t
        fade = _clamp(min(u / 0.10, (1.0 - u) / 0.10), 0.0, 1.0)
        if fade <= 0.01:
            return
        px = self.w * (-0.08 + 1.16 * u)
        py = self.h * (0.215 + 0.028 * math.sin(math.tau * u + 0.9))
        span = self.h * 0.030
        angle = -0.14 + 0.16 * math.sin(math.tau * u + 1.4)
        ca, sa = math.cos(angle), math.sin(angle)

        def point(x: float, y: float) -> tuple[float, float]:
            return (px + (x * ca - y * sa) * span, py + (x * sa + y * ca) * span)

        nose = point(1.18, 0.0)
        fold = point(-0.52, 0.06)
        tail_top = point(-0.96, -0.44)
        tail_bottom = point(-0.58, 0.48)
        alpha = int(238 * fade)
        self.draw.polygon(
            (nose, tail_top, fold), fill=(*PAPER_LIGHT, alpha),
            outline=(*INK, min(215, alpha)), width=max(1, self.line - 1),
        )
        self.draw.polygon(
            (nose, tail_bottom, fold), fill=(*PAPER_MID, alpha),
            outline=(*INK, min(195, alpha)), width=1,
        )
        self.draw.line((nose, fold), fill=(*INK, int(95 * fade)), width=1)
        for index in range(4):
            tx = px - span * (1.55 + index * 0.92)
            ty = py + span * 0.42 + span * 0.10 * index
            self.draw.line(
                (tx, ty, tx - span * 0.34, ty + span * 0.03),
                fill=(*INK, int((58 - index * 11) * fade)), width=1,
            )

    # ----------------------------------------------------------------- far
    def far(self) -> None:
        scroll = self.t * TILE_FAR
        base = self.sy(0.62)
        tone = (221, 201, 174)
        for k in (-1, 0, 1, 2):
            for x, width, payload in FAR:
                height_text, kind = payload.split(":")
                height = float(height_text)
                x0 = self.sx(x + k * TILE_FAR, scroll)
                x1 = self.sx(x + width + k * TILE_FAR, scroll)
                if x1 < -20 or x0 > self.w + 20:
                    continue
                top = self.sy(0.62 + height)
                self.draw.rectangle((x0, top, x1, base), fill=tone)
                rng = random.Random(int(x * 100) + int(width * 10))
                cols = max(1, int(width / 0.30))
                rows = max(1, int((height - 0.24) / 0.30))
                for row in range(rows):
                    z = 0.20 + row * 0.30
                    if z > height - 0.20:
                        break
                    for col in range(cols):
                        cx = x + width * (col + 0.5) / cols
                        if rng.random() < 0.26:
                            continue
                        wx0 = self.sx(cx - 0.045 + k * TILE_FAR, scroll)
                        wx1 = self.sx(cx + 0.045 + k * TILE_FAR, scroll)
                        wz0 = self.sy(0.62 + z + 0.07)
                        wz1 = self.sy(0.62 + z - 0.07)
                        self.draw.rectangle((wx0, wz0, wx1, wz1), fill=(*SHADOW, 58))
                if kind == "dome":
                    radius = (x1 - x0) / 2.0
                    self.draw.ellipse((x0, top - radius, x1, top + radius), fill=tone)
                elif kind == "spire":
                    middle = (x0 + x1) / 2.0
                    self.draw.polygon(
                        ((x0, top), (x1, top), (middle, top - self.unit(0.16))), fill=tone
                    )
                self.draw.line((x0, top, x1, top), fill=(*PAPER_LIGHT, 60), width=1)
        veil = self.sy(1.45)
        self.draw.rectangle(
            (0, veil, self.w, self.sy(0.42)),
            fill=(247, 235, 216, 26),
        )

    # ----------------------------------------------------------------- back
    def back(self) -> None:
        scroll = self.t * TILE_BACK
        for k in (-1, 0, 1, 2):
            for facade in BACK:
                x0 = self.sx(facade.x + k * TILE_BACK, scroll)
                x1 = self.sx(facade.x + facade.w + k * TILE_BACK, scroll)
                if x1 < -20 or x0 > self.w + 20:
                    continue
                top = self.sy(0.20 + facade.h)
                base = self.sy(0.18)
                fill = _mix(facade.tone, HAZE, 0.30)
                self.draw.rectangle((x0, top, x1, base), fill=(*fill, 255))
                self.draw.rectangle(
                    (x0, top, x1, base), outline=(*INK, 118), width=max(1, self.line - 1)
                )
                self.draw.rectangle(
                    (x0, top, x1, top + self.unit(0.05)), fill=(*PAPER_LIGHT, 90)
                )
                for window in facade.windows:
                    wz0 = self.sy(0.20 + window.z + window.h / 2.0)
                    wz1 = self.sy(0.20 + window.z - window.h / 2.0)
                    wx0 = self.sx(window.x - window.w / 2.0 + k * TILE_BACK, scroll)
                    wx1 = self.sx(window.x + window.w / 2.0 + k * TILE_BACK, scroll)
                    self.draw.rectangle((wx0, wz0, wx1, wz1), fill=(*INK_SOFT, 82))
                self._roof(facade, x0, x1, top, simple=True, u=0.0, impact=0.0)

    # ----------------------------------------------------------------- front
    def front(self) -> None:
        scroll = self.t * TILE_FRONT
        for k in (-1, 0, 1, 2):
            for facade in FRONT:
                x0 = self.sx(facade.x + k * TILE_FRONT, scroll)
                x1 = self.sx(facade.x + facade.w + k * TILE_FRONT, scroll)
                if x1 < -30 or x0 > self.w + 30:
                    continue
                self._facade(facade, x0, x1, k)
        for start, end, z in GARLANDS:
            for k in (-1, 0, 1):
                self._garland(start + k * TILE_FRONT, end + k * TILE_FRONT, z, scroll, k)

    def _facade(self, facade: Facade, x0: float, x1: float, copy: int) -> None:
        top = self.sy(facade.h)
        base = self.sy(0.0)
        rng = random.Random(facade.seed)
        shadow = self.unit(0.05)
        self.draw.rectangle(
            (x0 - shadow, top + shadow * 0.6, x1 - shadow, base + shadow * 0.6),
            fill=(*SHADOW, 34),
        )
        self.draw.rectangle((x0, top, x1, base), fill=facade.tone)
        self.draw.rectangle(
            (x0, top, x1, top + (base - top) * 0.20),
            fill=(*PAPER_LIGHT, 22),
        )
        self.draw.rectangle(
            (x0, base - (base - top) * 0.24, x1, base),
            fill=(*SHADOW, 10),
        )
        self.draw.rectangle(
            (x0, top, x1, top + self.unit(facade.parapet)),
            fill=_mix(facade.tone, PAPER_LIGHT, 0.35),
        )
        band_y = top + self.unit(facade.parapet)
        self.draw.rectangle(
            (x0, band_y - self.unit(0.028), x1, band_y),
            fill=_mix(facade.tone, SHADOW, 0.14),
        )
        self.draw.line(
            (x0, band_y, x1, band_y), fill=(*INK, 210), width=self.line,
        )
        self.draw.rectangle((x0, top, x1, base), outline=INK, width=self.line)
        self.draw.rectangle((x0, top, x1, top + self.unit(0.026)), fill=(*PAPER_LIGHT, 210))
        self.draw.line(
            (x0 + self.line * 0.5, base, x1 - self.line * 0.5, base),
            fill=INK, width=self.line,
        )

        seam_alpha = 5
        for index in range(2):
            sx = x0 + (x1 - x0) * (0.30 + index * 0.38)
            self.draw.line((sx, top + self.unit(0.2), sx, base - self.unit(0.05)),
                           fill=(*INK, seam_alpha), width=1)
        for index in range(3):
            sy = top + (base - top) * rng.uniform(0.16, 0.9)
            self.draw.line((x0 + 2, sy, x1 - 2, sy), fill=(*INK, seam_alpha), width=1)

        for row in range(-1, 8):
            z = 0.92 + row * 0.38
            if z <= 0.40 or z >= facade.h - 0.20:
                continue
            self.draw.line(
                (x0 + self.line, self.sy(z), x1 - self.line, self.sy(z)),
                fill=(*INK, 9 if row % 2 else 14), width=1,
            )

        if facade.band:
            band_top = self.sy(facade.band)
            self.draw.rectangle(
                (x0, band_top, x1, base),
                fill=_mix(facade.tone, ACCENT_LIGHT, 0.11),
            )
            self.draw.rectangle(
                (x0, band_top, x1, band_top + self.unit(0.016)),
                fill=(*ACCENT, 88),
            )
            self.draw.line((x0, band_top, x1, band_top), fill=(*INK, 55), width=1)

        plinth = self.unit(0.14)
        self.draw.rectangle(
            (x0, base - plinth, x1, base),
            fill=_mix(facade.tone, SHADOW, 0.16),
        )
        self.draw.line(
            (x0, base - plinth, x1, base - plinth), fill=(*INK, 70), width=1
        )

        self._door(facade, x0, base)
        if facade.shop:
            self._shop(facade, x0, base)
        for window in facade.windows:
            self._window(facade, window, x0, copy)
        if facade.balcony:
            self._balcony(facade, x0, facade.balcony)
        if facade.fire_escape:
            self._fire_escape(facade, x0)
        self._roof(
            facade,
            x0,
            x1,
            top,
            simple=False,
            u=(facade.x + copy * TILE_FRONT),
            impact=0.0,
        )

    def _window(self, facade: Facade, window: Window, x0: float, copy: int) -> None:
        scroll = self.t * TILE_FRONT
        world_x = window.x + copy * TILE_FRONT
        left = self.sx(window.x - window.w / 2.0 + copy * TILE_FRONT, scroll)
        right = self.sx(window.x + window.w / 2.0 + copy * TILE_FRONT, scroll)
        top = self.sy(window.z + window.h / 2.0)
        bottom = self.sy(window.z - window.h / 2.0)
        light = 0.08 + _impact_light(self.t, world_x, window.z) * 1.05
        if window.lit:
            light = max(light, 0.85)
        light = _clamp(light, 0.0, 1.0)

        if light > 0.20:
            level = _clamp(int(round(light * 7.0)), 1, 7)
            size = int(self.unit(0.78))
            sprite = _glow_sprite(size, WARM, level)
            cx = (left + right) / 2.0
            cy = (top + bottom) / 2.0
            self.image.paste(sprite, (int(cx - size / 2), int(cy - size / 2)), sprite)

        frame = max(1, self.line - 2)
        if window.shutter:
            shutter_w = (right - left) * 0.52
            shutter_tone = ACCENT_DARK if facade.seed % 3 == 0 else SAGE_DARK
            for side in (-1, 1):
                outer = left - frame - shutter_w if side < 0 else right + frame
                self.draw.rectangle(
                    (outer, top, outer + shutter_w, bottom),
                    fill=shutter_tone, outline=(*INK, 205), width=1,
                )
                for slat in range(4):
                    sy = top + (bottom - top) * (slat + 1) / 5.0
                    self.draw.line(
                        (outer + 1, sy, outer + shutter_w - 1, sy),
                        fill=(*INK, 62), width=1,
                    )
        self.draw.rectangle(
            (left - frame, top - frame, right + frame, bottom + frame),
            fill=INK,
        )
        pane = _mix((96, 73, 53), WARM, _clamp(light, 0.0, 1.0))
        if light > 0.55:
            pane = _mix(pane, WARM_PALE, (light - 0.55) * 0.7)
        self.draw.rectangle((left, top, right, bottom), fill=pane)
        middle_x = (left + right) / 2.0
        middle_y = (top + bottom) / 2.0
        self.draw.polygon(
            ((left + (right - left) * 0.22, bottom),
             (left + (right - left) * 0.53, top),
             (left + (right - left) * 0.67, top),
             (left + (right - left) * 0.36, bottom)),
            fill=(255, 250, 240, 16),
        )
        mullion = _mix(INK, PAPER_LIGHT, 0.55 if light < 0.5 else 0.35)
        self.draw.line((middle_x, top, middle_x, bottom), fill=(*mullion, 210), width=max(1, frame))
        self.draw.line((left, middle_y, right, middle_y), fill=(*mullion, 210), width=max(1, frame))
        if window.curtain and light < 0.5:
            self.draw.rectangle(
                (left, top, left + (right - left) * 0.35, bottom),
                fill=(*PAPER_LIGHT, 70),
            )
        sill = self.unit(0.022)
        self.draw.rectangle(
            (left - frame, bottom + frame, right + frame, bottom + frame + sill),
            fill=(*PAPER_LIGHT, 235),
        )
        self.draw.line(
            (left - frame, bottom + frame + sill, right + frame, bottom + frame + sill),
            fill=(*INK, 120), width=1,
        )
        if window.box:
            box_top = bottom + frame + sill * 0.4
            self.draw.rectangle(
                (left - frame * 2, box_top, right + frame * 2, box_top + self.unit(0.045)),
                fill=ACCENT, outline=INK, width=1,
            )
            for offset in (-0.3, 0.05, 0.4):
                bx = (left + right) / 2.0 + (right - left) * offset
                self.draw.ellipse(
                    (bx - self.unit(0.016), box_top - self.unit(0.035),
                     bx + self.unit(0.016), box_top),
                    fill=SAGE_DARK,
                )

    def _door(self, facade: Facade, x0: float, base: float) -> None:
        scroll = self.t * TILE_FRONT
        origin = self.sx(facade.x, scroll)
        left = origin + self.unit(facade.door - facade.x - 0.11)
        right = origin + self.unit(facade.door - facade.x + 0.11)
        top = self.sy(0.48)
        self.draw.rectangle(
            (left - self.unit(0.012), top - self.unit(0.012),
             right + self.unit(0.012), base),
            fill=PAPER_LIGHT, outline=(*INK, 200), width=1,
        )
        self.draw.rectangle((left, top, right, base), fill=INK)
        self.draw.rectangle(
            (left + self.unit(0.016), top + self.unit(0.016),
             right - self.unit(0.016), base - self.unit(0.02)),
            fill=_mix(ACCENT_DARK, INK, 0.55),
        )
        mid = (left + right) / 2.0
        for panel in range(2):
            py0 = top + self.unit(0.09 + panel * 0.18)
            py1 = py0 + self.unit(0.14)
            self.draw.rectangle(
                (left + self.unit(0.035), py0, right - self.unit(0.035), py1),
                outline=(*INK, 200), width=1,
            )
        self.draw.line((mid, top + self.unit(0.03), mid, base - self.unit(0.03)),
                       fill=(*INK, 160), width=1)
        knob_y = self.sy(0.25)
        self.draw.ellipse(
            (right - self.unit(0.055), knob_y - self.unit(0.012),
             right - self.unit(0.035), knob_y + self.unit(0.012)),
            fill=WARM,
        )
        self.draw.rectangle(
            (left - self.unit(0.055), base - self.unit(0.045),
             right + self.unit(0.055), base),
            fill=PAPER_LIGHT, outline=(*INK, 190), width=1,
        )
        lamp_x = left - self.unit(0.10)
        lamp_y = self.sy(0.60)
        size = int(self.unit(0.6))
        glow = _glow_sprite(size, WARM, 4)
        self.image.paste(glow, (int(lamp_x - size / 2), int(lamp_y - size / 2)), glow)
        self.draw.rectangle(
            (lamp_x - self.unit(0.018), lamp_y - self.unit(0.022),
             lamp_x + self.unit(0.018), lamp_y + self.unit(0.022)),
            fill=WARM, outline=INK, width=1,
        )

    def _shop(self, facade: Facade, x0: float, base: float) -> None:
        scroll = self.t * TILE_FRONT
        origin = self.sx(facade.x, scroll)
        left_world = facade.door + 0.24
        width = min(0.56, facade.x + facade.w - 0.16 - left_world)
        if width < 0.26:
            return
        left = origin + self.unit(left_world - facade.x)
        right = origin + self.unit(left_world - facade.x + width)
        top = self.sy(0.52)
        bottom = self.sy(0.08)
        self.draw.rectangle((left, top, right, bottom), fill=(*INK, 240))
        light = 0.62 + 0.18 * math.sin(2.0 * math.tau * self.t + facade.seed)
        self.draw.rectangle(
            (left + self.unit(0.014), top + self.unit(0.014),
             right - self.unit(0.014), bottom - self.unit(0.012)),
            fill=_mix(WARM, WARM_PALE, light * 0.5),
        )
        for split in (1, 2):
            xx = left + (right - left) * split / 3.0
            self.draw.line((xx, top, xx, bottom), fill=(*INK, 180), width=max(1, self.line - 1))
        self.draw.line(
            ((left + right) / 2.0, top, (left + right) / 2.0, bottom),
            fill=(*INK, 110), width=1,
        )
        if facade.awning:
            self._awning(left, right, top - self.unit(0.03), facade.seed)
        sign_top = self.sy(0.68)
        sign_cx = (left + right) / 2.0
        self.draw.rectangle(
            (sign_cx - self.unit(0.20), sign_top,
             sign_cx + self.unit(0.20), sign_top + self.unit(0.14)),
            fill=PAPER_LIGHT, outline=(*INK, 210), width=1,
        )
        self._shop_mark(facade.sign, sign_cx, sign_top + self.unit(0.07))

    def _shop_mark(self, kind: int, cx: float, cy: float) -> None:
        if kind == 0:
            cup = self.unit(0.043)
            self.draw.rounded_rectangle(
                (cx - cup, cy - cup * 0.55, cx + cup, cy + cup * 0.95),
                radius=cup * 0.35, fill=CREAM_SCARF, outline=INK, width=1,
            )
            self.draw.arc(
                (cx + cup * 0.55, cy - cup * 0.45, cx + cup * 1.75, cy + cup * 0.65),
                start=270, end=90, fill=INK, width=1,
            )
            for steam_x in (-0.45, 0.35):
                sx = cx + cup * steam_x
                self.draw.arc(
                    (sx - cup * 0.26, cy - cup * 2.0, sx + cup * 0.26, cy - cup * 1.05),
                    start=280, end=80, fill=(*ACCENT, 200), width=1,
                )
            self.draw.rectangle(
                (cx - cup * 1.35, cy + cup * 0.95, cx + cup * 1.35, cy + cup * 1.15),
                fill=ACCENT, outline=INK, width=1,
            )
        elif kind == 1:
            bread_w = self.unit(0.075)
            bread_h = self.unit(0.034)
            self.draw.ellipse(
                (cx - bread_w, cy - bread_h, cx + bread_w, cy + bread_h),
                fill=CREAM_SCARF, outline=INK, width=1,
            )
            for offset in (-0.5, 0.0, 0.5):
                bx = cx + bread_w * offset
                self.draw.line(
                    (bx - bread_w * 0.10, cy - bread_h * 0.45,
                     bx + bread_w * 0.10, cy + bread_h * 0.45),
                    fill=(*ACCENT_DARK, 210), width=1,
                )
        else:
            petal = self.unit(0.016)
            for index in range(5):
                angle = math.tau * index / 5.0 - math.pi / 2.0
                px = cx + math.cos(angle) * petal * 0.95
                py = cy + math.sin(angle) * petal * 0.95 - petal * 0.25
                self.draw.ellipse(
                    (px - petal, py - petal, px + petal, py + petal),
                    fill=ACCENT_LIGHT, outline=(*INK, 170), width=1,
                )
            self.draw.ellipse(
                (cx - petal * 0.75, cy - petal * 1.0,
                 cx + petal * 0.75, cy + petal * 0.5),
                fill=ACCENT, outline=INK, width=1,
            )
            self.draw.line(
                (cx, cy + petal * 0.3, cx, cy + self.unit(0.045)),
                fill=SAGE_DARK, width=1,
            )

    def _awning(self, left: float, right: float, top: float, seed: int) -> None:
        height = self.unit(0.16)
        width = right - left
        stripes = max(5, int(width / self.unit(0.13)))
        for index in range(stripes):
            x0 = left + width * index / stripes
            x1 = left + width * (index + 1) / stripes
            color = ACCENT if index % 2 == 0 else PAPER_LIGHT
            self.draw.rectangle((x0, top, x1, top + height), fill=color)
        self.draw.rectangle((left, top, right, top + height), outline=(*INK, 225), width=self.line)
        for index in range(stripes):
            cx = left + width * (index + 0.5) / stripes
            radius = width / stripes / 2.0
            self.draw.ellipse(
                (cx - radius, top + height - radius * 0.2, cx + radius, top + height + radius * 1.0),
                fill=ACCENT if index % 2 == 0 else PAPER_LIGHT,
                outline=(*INK, 210), width=1,
            )
        self.draw.rectangle(
            (left, top + height + self.unit(0.10), right, top + height + self.unit(0.125)),
            fill=(*SHADOW, 44),
        )

    def _balcony(self, facade: Facade, origin: float, z: float) -> None:
        cx = origin + self.unit(facade.w / 2.0)
        width = self.unit(min(0.58, facade.w * 0.56))
        deck = self.sy(z)
        self.draw.rectangle((cx - width / 2, deck, cx + width / 2, deck + self.unit(0.03)),
                            fill=PAPER_LIGHT, outline=(*INK, 210), width=1)
        for index in range(7):
            bx = cx - width / 2 + width * index / 6.0
            self.draw.line((bx, deck, bx, deck - self.unit(0.16)), fill=(*INK, 210), width=1)
        self.draw.line(
            (cx - width / 2, deck - self.unit(0.16), cx + width / 2, deck - self.unit(0.16)),
            fill=(*INK, 210), width=max(1, self.line - 1),
        )

    def _fire_escape(self, facade: Facade, origin: float) -> None:
        x = origin + self.unit(facade.w * 0.64)
        width = self.unit(0.34)
        levels = [1.40, 2.15, 2.90]
        for index, z in enumerate(levels):
            if z > facade.h - 0.25:
                break
            y = self.sy(z)
            self.draw.rectangle((x, y, x + width, y + self.unit(0.025)),
                                fill=(*INK, 205))
            self.draw.line((x, y - self.unit(0.12), x + width, y - self.unit(0.12)),
                           fill=(*INK, 180), width=1)
            for tick in range(5):
                tx = x + width * tick / 4.0
                self.draw.line((tx, y, tx, y - self.unit(0.12)), fill=(*INK, 180), width=1)
            if index < len(levels) - 1 and levels[index + 1] <= facade.h - 0.25:
                lower = self.sy(levels[index + 1])
                self.draw.line((x + width * 0.2, y, x + width * 0.8, lower),
                               fill=(*INK, 165), width=max(1, self.line - 1))

    def _roof(self, facade: Facade, x0: float, x1: float, top: float,
              simple: bool, u: float, impact: float) -> None:
        rng = random.Random(facade.seed + 7)
        kind = facade.roof
        width = x1 - x0
        if width < self.unit(0.12):
            return
        if kind == "tank":
            cx = x0 + width * 0.66
            body_w = self.unit(0.22)
            body_h = self.unit(0.26 if not simple else 0.20)
            body_top = top - body_h
            self.draw.rectangle(
                (cx - body_w / 2, body_top + self.unit(0.03), cx + body_w / 2, top),
                fill=_mix(facade.tone, PAPER_LIGHT, 0.35) if not simple else _mix(facade.tone, HAZE, 0.4),
                outline=(*INK, 150 if simple else 220), width=1,
            )
            self.draw.ellipse(
                (cx - body_w / 2, body_top, cx + body_w / 2, body_top + self.unit(0.07)),
                fill=PAPER_LIGHT if not simple else HAZE,
                outline=(*INK, 150 if simple else 220), width=1,
            )
            self.draw.line((cx - body_w * 0.32, body_top + self.unit(0.05),
                            cx - body_w * 0.32, top - self.unit(0.06)),
                           fill=(*INK, 90), width=1)
        elif kind == "chimney":
            cx = x0 + width * 0.30
            self.draw.rectangle(
                (cx - self.unit(0.07), top - self.unit(0.24), cx + self.unit(0.07), top),
                fill=_mix(facade.tone, PAPER_LIGHT, 0.3), outline=(*INK, 200), width=1,
            )
            self.draw.rectangle(
                (cx - self.unit(0.085), top - self.unit(0.27), cx + self.unit(0.085), top - self.unit(0.22)),
                fill=ACCENT if not simple else HAZE, outline=(*INK, 180), width=1,
            )
            if not simple:
                for index in range(2):
                    puff_x = cx + self.unit(0.12 + index * 0.10)
                    puff_y = top - self.unit(0.30 + index * 0.10)
                    self.draw.arc(
                        (puff_x - self.unit(0.06), puff_y - self.unit(0.05),
                         puff_x + self.unit(0.06), puff_y + self.unit(0.05)),
                        start=200, end=340, fill=(*INK, 70), width=2,
                    )
        elif kind == "antenna":
            cx = x0 + width * 0.48
            self.draw.line(
                (cx, top, cx, top - self.unit(0.40)), fill=(*INK, 200), width=max(1, self.line - 1)
            )
            self.draw.line(
                (cx - self.unit(0.09), top - self.unit(0.28), cx + self.unit(0.09), top - self.unit(0.28)),
                fill=(*INK, 180), width=1,
            )
            self.draw.line(
                (cx - self.unit(0.06), top - self.unit(0.36), cx + self.unit(0.06), top - self.unit(0.36)),
                fill=(*INK, 160), width=1,
            )
            if not simple:
                self.draw.polygon(
                    ((cx + self.unit(0.01), top - self.unit(0.40)),
                     (cx + self.unit(0.14), top - self.unit(0.375)),
                     (cx + self.unit(0.01), top - self.unit(0.35))),
                    fill=ACCENT, outline=INK,
                )
        elif kind == "plants":
            for index in range(3):
                px = x0 + width * (0.30 + index * 0.16)
                radius = self.unit(0.055 if index != 1 else 0.07)
                self.draw.rectangle(
                    (px - self.unit(0.05), top - self.unit(0.06), px + self.unit(0.05), top),
                    fill=ACCENT_DARK, outline=(*INK, 190), width=1,
                )
                self.draw.ellipse(
                    (px - radius, top - self.unit(0.06) - radius * 2,
                     px + radius, top - self.unit(0.06)),
                    fill=SAGE, outline=(*INK, 160), width=1,
                )
        elif kind == "cat" and not simple:
            cx = x0 + width * 0.70
            body_w = self.unit(0.11)
            body_h = self.unit(0.15)
            self.draw.ellipse(
                (cx - body_w / 2, top - body_h, cx + body_w / 2, top),
                fill=INK,
            )
            self.draw.ellipse(
                (cx - self.unit(0.045), top - body_h - self.unit(0.075),
                 cx + self.unit(0.045), top - body_h + self.unit(0.015)),
                fill=INK,
            )
            self.draw.polygon(
                ((cx - self.unit(0.04), top - body_h - self.unit(0.06)),
                 (cx - self.unit(0.012), top - body_h - self.unit(0.105)),
                 (cx - self.unit(0.004), top - body_h - self.unit(0.045))),
                fill=INK,
            )
            self.draw.polygon(
                ((cx + self.unit(0.04), top - body_h - self.unit(0.06)),
                 (cx + self.unit(0.012), top - body_h - self.unit(0.105)),
                 (cx + self.unit(0.004), top - body_h - self.unit(0.045))),
                fill=INK,
            )
            self.draw.arc(
                (cx + body_w * 0.3, top - body_h * 0.9, cx + body_w * 1.2, top - body_h * 0.1),
                start=250, end=80, fill=INK, width=max(1, self.line - 1),
            )
        else:
            cx = x0 + width * 0.5
            self.draw.rectangle(
                (cx - self.unit(0.05), top - self.unit(0.12), cx + self.unit(0.05), top),
                fill=_mix(facade.tone, PAPER_LIGHT, 0.3), outline=(*INK, 170), width=1,
            )
            self.draw.ellipse(
                (cx - self.unit(0.075), top - self.unit(0.16), cx + self.unit(0.075), top - self.unit(0.10)),
                fill=PAPER_LIGHT, outline=(*INK, 160), width=1,
            )

    def _garland(self, start: float, end: float, z: float, scroll: float, copy: int) -> None:
        left = self.sx(start, scroll)
        right = self.sx(end, scroll)
        if right < -20 or left > self.w + 20:
            return
        sway = math.sin(math.tau * self.t + start) * self.unit(0.010)
        top = self.sy(z) + sway
        span = right - left
        sag = self.unit(0.13)
        points = []
        for index in range(19):
            f = index / 18.0
            x = left + span * f
            y = top + sag * math.sin(math.pi * f)
            points.append((x, y))
        self.draw.line(points, fill=(*INK, 200), width=max(1, self.line - 2), joint="curve")
        for end in (left, right):
            self.draw.ellipse(
                (end - self.unit(0.008), top - self.unit(0.008),
                 end + self.unit(0.008), top + self.unit(0.008)),
                fill=INK,
            )
        flags = 8
        for index in range(flags):
            f = (index + 0.5) / flags
            x = left + span * f
            y = top + sag * math.sin(math.pi * f)
            width = self.unit(0.078)
            height = self.unit(0.105)
            color = ACCENT if index % 2 == 0 else PAPER_LIGHT
            self.draw.polygon(
                ((x - width / 2, y), (x + width / 2, y), (x, y + height)),
                fill=color, outline=(*INK, 215),
            )

    # ----------------------------------------------------------------- street
    def street(self) -> None:
        scroll = self.t * TILE_FRONT
        top = self.sy(0.0)
        self.draw.rectangle((0, top, self.w, self.h), fill=(238, 225, 204))
        sidewalk = self.sy(-0.24)
        self.draw.rectangle((0, top, self.w, sidewalk), fill=PAPER_LIGHT)
        for k in (-1, 0, 1, 2):
            for facade in FRONT:
                x0 = self.sx(facade.x + k * TILE_FRONT, scroll)
                x1 = self.sx(facade.x + facade.w + k * TILE_FRONT, scroll)
                if x1 < -self.unit(0.5) or x0 > self.w + self.unit(0.5):
                    continue
                for step in range(3):
                    width = self.unit(0.05 + step * 0.055)
                    self.draw.rectangle(
                        (x0 - width, top, x0, sidewalk),
                        fill=(*SHADOW, 8),
                    )
        for x in LAMPS:
            for k in (-1, 0, 1):
                px = self.sx(x + k * TILE_FRONT, scroll)
                if -self.unit(0.4) < px < self.w + self.unit(0.4):
                    for layer, (span, alpha) in enumerate(
                        ((0.34, 7), (0.23, 9), (0.13, 12))
                    ):
                        pad = self.unit(0.02 * layer)
                        self.draw.ellipse(
                            (px - self.unit(span), top + self.unit(0.02) + pad,
                             px + self.unit(span), sidewalk - self.unit(0.01) - pad),
                            fill=(*WARM, alpha),
                        )
                    self.draw.ellipse(
                        (px - self.unit(0.045), top, px + self.unit(0.045), top + self.unit(0.014)),
                        fill=(*INK, 38),
                    )
        for k in (-1, 0, 1, 2):
            for facade in FRONT:
                if not facade.shop:
                    continue
                left_world = facade.door + 0.24
                width = min(0.56, facade.x + facade.w - 0.16 - left_world)
                if width < 0.26:
                    continue
                cx = self.sx(left_world + width / 2.0 + k * TILE_FRONT, scroll)
                if cx < -self.unit(0.5) or cx > self.w + self.unit(0.5):
                    continue
                for layer in range(3):
                    spread = self.unit(0.22 + layer * 0.09)
                    depth = self.unit(0.035 + layer * 0.018)
                    self.draw.ellipse(
                        (cx - spread, top + self.unit(0.03) - depth,
                         cx + spread, top + self.unit(0.03) + depth),
                        fill=(*WARM, 9),
                    )
        self.draw.line((0, top, self.w, top), fill=INK, width=self.line)
        for joint in range(-2, 12):
            jx = self.sx(joint * 0.9 + 0.2, scroll)
            self.draw.line((jx, top, jx, sidewalk), fill=(*INK, 22), width=1)
        drain_x = self.sx(4.72, scroll)
        if -self.unit(0.2) < drain_x < self.w + self.unit(0.2):
            self.draw.rounded_rectangle(
                (drain_x - self.unit(0.065), top + self.unit(0.08),
                 drain_x + self.unit(0.065), top + self.unit(0.17)),
                radius=self.unit(0.008), fill=(*INK, 125),
            )
            for slat in range(4):
                gy = top + self.unit(0.093 + slat * 0.017)
                self.draw.line(
                    (drain_x - self.unit(0.046), gy, drain_x + self.unit(0.046), gy),
                    fill=(*PAPER_LIGHT, 165), width=1,
                )
        self.draw.rectangle((0, sidewalk, self.w, sidewalk + self.unit(0.04)), fill=ACCENT)
        self.draw.line((0, sidewalk, self.w, sidewalk), fill=(*INK, 200), width=1)
        self.draw.line(
            (0, sidewalk + self.unit(0.04), self.w, sidewalk + self.unit(0.04)),
            fill=(*INK, 210), width=1,
        )
        road_top = sidewalk + self.unit(0.055)
        self.draw.rectangle((0, road_top, self.w, self.h), fill=(233, 220, 198))
        for band in range(4):
            by = road_top + (self.h - road_top) * (band + 1) / 5.0
            self.draw.line((0, by, self.w, by), fill=(*INK, 12), width=1)
        dash_y = self.sy(-0.40)
        for dash in range(-2, 14):
            dx = self.sx(dash * 0.62 + 0.15, scroll)
            self.draw.rectangle(
                (dx, dash_y - self.unit(0.007), dx + self.unit(0.24), dash_y + self.unit(0.007)),
                fill=(*INK, 110),
            )
        manhole_x = self.sx(3.30, scroll)
        self.draw.ellipse(
            (manhole_x - self.unit(0.09), self.sy(-0.34) - self.unit(0.028),
             manhole_x + self.unit(0.09), self.sy(-0.34) + self.unit(0.028)),
            fill=(*INK, 34), outline=(*INK, 75), width=1,
        )
        rng = random.Random(3)
        for index in range(7):
            sx = self.sx(rng.uniform(0, TILE_FRONT), scroll)
            sy = self.sy(rng.uniform(-0.26, -0.02))
            size = self.unit(rng.uniform(0.015, 0.035))
            self.draw.polygon(
                ((sx, sy), (sx + size, sy - size * 0.5), (sx + size * 0.4, sy + size * 0.4)),
                fill=(*ACCENT_DARK, 80),
            )
        rng = random.Random(9)
        for index in range(5):
            lx = self.sx(rng.uniform(0, TILE_FRONT), scroll)
            ly = self.sy(rng.uniform(-0.21, -0.03))
            size = self.unit(rng.uniform(0.018, 0.032))
            self.draw.ellipse(
                (lx - size, ly - size * 0.55, lx + size, ly + size * 0.55),
                fill=(*SAGE_DARK, 110),
            )

    def props(self) -> None:
        scroll = self.t * TILE_FRONT
        for k in (-1, 0, 1):
            for x in LAMPS:
                px = self.sx(x + k * TILE_FRONT, scroll)
                if -self.unit(0.4) < px < self.w + self.unit(0.4):
                    self._lamp(px)
            for x, size in TREES:
                px = self.sx(x + k * TILE_FRONT, scroll)
                if -self.unit(0.5) < px < self.w + self.unit(0.5):
                    self._tree(px, size, x)
            px = self.sx(BENCH + k * TILE_FRONT, scroll)
            if -self.unit(0.5) < px < self.w + self.unit(0.5):
                self._bench(px)
            px = self.sx(CRATES + k * TILE_FRONT, scroll)
            if -self.unit(0.4) < px < self.w + self.unit(0.4):
                self._crates(px)
            px = self.sx(HYDRANT + k * TILE_FRONT, scroll)
            if -self.unit(0.3) < px < self.w + self.unit(0.3):
                self._hydrant(px)
            px = self.sx(MAILBOX + k * TILE_FRONT, scroll)
            if -self.unit(0.3) < px < self.w + self.unit(0.3):
                self._mailbox(px)

    def _lamp(self, x: float) -> None:
        base = self.sy(0.0)
        height = self.unit(1.62)
        self.draw.rectangle((x - self.unit(0.012), base - height, x + self.unit(0.012), base),
                            fill=INK)
        self.draw.rectangle(
            (x - self.unit(0.045), base - self.unit(0.03), x + self.unit(0.045), base),
            fill=INK,
        )
        arm = self.unit(0.16)
        self.draw.line((x, base - height, x + arm, base - height), fill=INK,
                       width=max(2, self.line - 1))
        globe_x = x + arm
        globe_y = base - height + self.unit(0.01)
        size = int(self.unit(0.95))
        glow = _glow_sprite(size, WARM, 4)
        self.image.paste(glow, (int(globe_x - size / 2), int(globe_y - size / 2)), glow)
        self.draw.ellipse(
            (globe_x - self.unit(0.045), globe_y - self.unit(0.055),
             globe_x + self.unit(0.045), globe_y + self.unit(0.055)),
            fill=WARM, outline=INK, width=1,
        )
        self.draw.polygon(
            ((globe_x - self.unit(0.06), globe_y - self.unit(0.045)),
             (globe_x, globe_y - self.unit(0.12)),
             (globe_x + self.unit(0.06), globe_y - self.unit(0.045))),
            fill=ACCENT, outline=INK,
        )
        self.draw.polygon(
            ((x + self.unit(0.018), base - height * 0.78),
             (x + self.unit(0.15), base - height * 0.74),
             (x + self.unit(0.018), base - height * 0.70)),
            fill=ACCENT, outline=(*INK, 200),
        )

    def _tree(self, x: float, size: float, seed: float) -> None:
        base = self.sy(0.0)
        sway = math.sin(math.tau * self.t + seed) * self.unit(0.010)
        self.draw.ellipse(
            (x - self.unit(0.22 * size), base - self.unit(0.02),
             x + self.unit(0.22 * size), base + self.unit(0.032)),
            fill=(*SHADOW, 26),
        )
        pot_h = self.unit(0.15)
        self.draw.polygon(
            ((x - self.unit(0.085), base), (x + self.unit(0.085), base),
             (x + self.unit(0.065), base - pot_h), (x - self.unit(0.065), base - pot_h)),
            fill=ACCENT, outline=INK,
        )
        self.draw.rectangle(
            (x - self.unit(0.078), base - pot_h, x + self.unit(0.078),
             base - pot_h + self.unit(0.018)),
            fill=ACCENT_DARK, outline=(*INK, 170), width=1,
        )
        canopy_x = x + sway
        canopy_y = base - self.unit(0.94 * size)
        radius = self.unit(0.31 * size)
        self.draw.line(
            (x, base - pot_h, canopy_x, canopy_y + radius * 0.55),
            fill=(*INK_SOFT, 255), width=max(2, int(self.unit(0.028))),
        )
        self.draw.line(
            (x + sway * 0.5, base - self.unit(0.40 * size),
             canopy_x - radius * 0.55, canopy_y + radius * 0.10),
            fill=(*INK_SOFT, 210), width=max(1, int(self.unit(0.016))),
        )
        self.draw.line(
            (x + sway * 0.5, base - self.unit(0.46 * size),
             canopy_x + radius * 0.50, canopy_y + radius * 0.22),
            fill=(*INK_SOFT, 190), width=1,
        )

        def lobes(center_x: float, center_y: float, reach: float, phase: float) -> list[tuple[float, float]]:
            shape = []
            for index in range(22):
                angle = math.tau * index / 22.0
                wobble = (
                    0.88
                    + 0.10 * math.sin(3.0 * angle + phase)
                    + 0.06 * math.sin(5.0 * angle + phase * 1.7)
                )
                shape.append(
                    (center_x + math.cos(angle) * reach * wobble,
                     center_y + math.sin(angle) * reach * wobble * 0.94)
                )
            return shape

        self.draw.polygon(
            lobes(canopy_x, canopy_y, radius, seed),
            fill=SAGE, outline=(*INK, 205),
        )
        self.draw.ellipse(
            (canopy_x - radius * 0.66, canopy_y + radius * 0.04,
             canopy_x + radius * 0.24, canopy_y + radius * 0.60),
            fill=(*SAGE_DARK, 74),
        )
        self.draw.ellipse(
            (canopy_x + radius * 0.18, canopy_y - radius * 0.52,
             canopy_x + radius * 0.68, canopy_y - radius * 0.02),
            fill=(*SAGE_DARK, 46),
        )
        self.draw.polygon(
            lobes(canopy_x - radius * 0.26, canopy_y - radius * 0.28, radius * 0.42, seed + 1.4),
            fill=_mix(SAGE, PAPER_LIGHT, 0.15),
        )
        for index in range(6):
            angle = math.tau * index / 6.0 + 0.35
            lx = canopy_x + math.cos(angle) * radius * 0.74
            ly = canopy_y + math.sin(angle) * radius * 0.70
            self.draw.arc(
                (lx - self.unit(0.032), ly - self.unit(0.022),
                 lx + self.unit(0.032), ly + self.unit(0.022)),
                start=200, end=340, fill=(*SAGE_DARK, 150), width=1,
            )

    def _bench(self, x: float) -> None:
        base = self.sy(0.0) - self.unit(0.04)
        seat = base - self.unit(0.115)
        width = self.unit(0.38)
        left = x - width / 2
        right = x + width / 2
        self.draw.ellipse(
            (left + self.unit(0.01), base - self.unit(0.015),
             right - self.unit(0.01), base + self.unit(0.028)),
            fill=(*SHADOW, 34),
        )
        post = self.unit(0.026)
        top = seat - self.unit(0.105)
        for side in (-1, 1):
            lx = x + side * width * 0.42
            self.draw.rectangle((lx - post / 2, seat, lx + post / 2, base), fill=INK)
            self.draw.rectangle((lx - post / 2, top, lx + post / 2, seat), fill=INK)
        for index in range(3):
            by = seat - self.unit(0.105) + index * self.unit(0.036)
            self.draw.rectangle(
                (left + self.unit(0.015), by, right - self.unit(0.015), by + self.unit(0.024)),
                fill=ACCENT_DARK, outline=(*INK, 230), width=1,
            )
            self.draw.line(
                (left + self.unit(0.03), by + self.unit(0.008),
                 right - self.unit(0.03), by + self.unit(0.008)),
                fill=(*WARM, 90), width=1,
            )
        self.draw.rectangle(
            (left, seat, right, seat + self.unit(0.032)),
            fill=ACCENT, outline=INK, width=max(1, self.line - 1),
        )
        self.draw.line(
            (left + self.unit(0.012), seat + self.unit(0.010),
             right - self.unit(0.012), seat + self.unit(0.010)),
            fill=(*WARM, 110), width=1,
        )
        paper_w = self.unit(0.13)
        paper_h = self.unit(0.045)
        px = x + width * 0.22
        py = base - self.unit(0.012)
        self.draw.polygon(
            ((px - paper_w / 2, py - paper_h * 0.55),
             (px + paper_w / 2, py - paper_h * 0.35),
             (px + paper_w / 2 - paper_w * 0.05, py + paper_h * 0.45),
             (px - paper_w / 2 + paper_w * 0.05, py + paper_h * 0.65)),
            fill=PAPER_LIGHT, outline=(*INK, 195), width=1,
        )
        for index in range(2):
            ly = py - paper_h * 0.18 + index * paper_h * 0.28
            self.draw.line(
                (px - paper_w * 0.36, ly, px + paper_w * 0.36, ly),
                fill=(*INK, 42), width=1,
            )

    def _crates(self, x: float) -> None:
        base = self.sy(0.0)
        for index, (dx, dz, size) in enumerate(((0.0, 0.0, 0.17), (0.18, 0.0, 0.13), (0.03, 0.17, 0.11))):
            x0 = x + self.unit(dx - size / 2)
            x1 = x + self.unit(dx + size / 2)
            y0 = base - self.unit(dz + size)
            y1 = base - self.unit(dz)
            self.draw.rectangle((x0, y0, x1, y1), fill=PAPER_MID, outline=INK, width=1)
            self.draw.line((x0, y0, x1, y1), fill=(*INK, 120), width=1)
            self.draw.line((x1, y0, x0, y1), fill=(*INK, 120), width=1)

    def _hydrant(self, x: float) -> None:
        base = self.sy(0.0)
        self.draw.rectangle(
            (x - self.unit(0.035), base - self.unit(0.17), x + self.unit(0.035), base),
            fill=ACCENT, outline=INK, width=1,
        )
        self.draw.ellipse(
            (x - self.unit(0.05), base - self.unit(0.21), x + self.unit(0.05), base - self.unit(0.14)),
            fill=ACCENT, outline=INK, width=1,
        )
        for side in (-1, 1):
            self.draw.rectangle(
                (x + side * self.unit(0.035) - (self.unit(0.02) if side > 0 else 0),
                 base - self.unit(0.13),
                 x + side * self.unit(0.035) + (self.unit(0.02) if side < 0 else 0),
                 base - self.unit(0.10)),
                fill=ACCENT_DARK, outline=INK, width=1,
            )

    def _mailbox(self, x: float) -> None:
        base = self.sy(0.0)
        half = self.unit(0.085)
        height = self.unit(0.40)
        self.draw.ellipse(
            (x - half * 1.3, base - self.unit(0.015), x + half * 1.3, base + self.unit(0.02)),
            fill=(*SHADOW, 30),
        )
        self.draw.rounded_rectangle(
            (x - half, base - height, x + half, base),
            radius=half * 0.55, fill=ACCENT, outline=INK, width=self.line,
        )
        self.draw.ellipse(
            (x - half, base - height - half * 0.35, x + half, base - height + half * 0.55),
            fill=ACCENT, outline=INK, width=self.line,
        )
        self.draw.rounded_rectangle(
            (x - half * 0.55, base - height * 0.72, x + half * 0.55, base - height * 0.64),
            radius=self.unit(0.006), fill=INK,
        )
        self.draw.ellipse(
            (x - half * 0.34, base - height * 0.48, x + half * 0.34, base - height * 0.18),
            fill=CREAM_SCARF, outline=INK, width=1,
        )
        self.draw.line(
            (x - half * 0.20, base - height * 0.33, x + half * 0.20, base - height * 0.33),
            fill=(*ACCENT_DARK, 190), width=1,
        )
        for side in (-1, 1):
            self.draw.line(
                (x + side * half * 0.55, base, x + side * half * 0.55, base - self.unit(0.028)),
                fill=INK, width=max(1, self.line - 1),
            )

    # ----------------------------------------------------------------- sheets
    def sheets(self) -> None:
        scroll = self.t * TILE_FRONT
        for x, z, w, h, angle, phase, bob in MID_SHEETS:
            px = self.sx(x + 0.22 * math.sin(math.tau * self.t + phase), scroll)
            py = self.sy(z + 0.10 * math.sin(math.tau * self.t + phase * 3.0))
            self._sheet(px, py, w, h, angle + 9.0 * math.sin(math.tau * self.t + phase),
                        fill=PAPER_LIGHT, alpha=246, width=1)

    def _sheet(self, cx: float, cy: float, w: float, h: float, angle: float,
               fill, alpha: int, width: int, blur: bool = False) -> None:
        size_w = int(self.unit(w) * 2.4)
        size_h = int(self.unit(h) * 2.4)
        if size_w < 4 or size_h < 4:
            return
        layer = Image.new("RGBA", (size_w, size_h), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer, "RGBA")
        pad = size_w * 0.2
        draw.rectangle(
            (pad, pad, size_w - pad, size_h - pad),
            fill=(*fill, alpha), outline=(*INK, min(255, alpha)), width=width,
        )
        body_h = size_h - pad * 2.0
        for index in range(3):
            ly = pad + body_h * (0.26 + index * 0.17)
            draw.line(
                (pad + size_w * 0.09, ly, size_w - pad - size_w * 0.15, ly),
                fill=(*INK, 32), width=1,
            )
        fold = (size_w - pad * 2.0) * 0.20
        draw.polygon(
            ((size_w - pad - fold, pad), (size_w - pad, pad), (size_w - pad, pad + fold)),
            fill=(*PAPER_MID, alpha), outline=(*INK, 75),
        )
        layer = layer.rotate(angle, resample=Image.BICUBIC, expand=False)
        if blur:
            layer = layer.filter(ImageFilter.GaussianBlur(1.6))
        self.image.paste(layer, (int(cx - size_w / 2), int(cy - size_h / 2)), layer)

    # ----------------------------------------------------------------- ball
    def ball(self) -> None:
        state = ball_state(self.t)
        scroll = self.t * TILE_FRONT
        x = ball_world_x(self.t)
        cx = self.sx(x, scroll)
        base = self.sy(state["z"])
        radius = self.unit(BALL_RADIUS)
        squash = state["squash"]
        rx = radius / squash
        ry = radius * squash
        cy = base - ry

        height_fade = 1.0 - min(0.70, state["z"] * 0.58)
        spread = 1.04 + 0.20 * min(1.0, state["z"] * 2.0)
        for layer in range(9):
            f = layer / 8.0
            shadow_w = rx * spread * (0.46 + 0.54 * f)
            shadow_h = radius * 0.10 * (0.40 + 0.60 * f)
            alpha = int((11.0 * (1.0 - f) + 2.0) * height_fade)
            self.draw.ellipse(
                (cx - shadow_w, self.ground - shadow_h, cx + shadow_w, self.ground + shadow_h),
                fill=(118, 98, 79, alpha),
            )

        self._dust()

        pad = int(radius * 2.75)
        side = pad * 2
        layer = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer, "RGBA")
        mask = Image.new("L", (side, side), 0)
        md = ImageDraw.Draw(mask)
        md.ellipse((pad - rx, pad - ry, pad + rx, pad + ry), fill=255)

        ink_w = max(2, int(radius * 0.019) + 1)
        scarf_len = radius * (1.28 + 0.10 * math.sin(math.tau * self.t * 2.0))
        self._ribbon(
            ld, (pad - rx * 0.92, pad + ry * 0.54), scarf_len, radius * 0.25,
            radius * 0.50, self.t * 2.0 + 0.4, CREAM_SCARF, ink_w, accent=ACCENT,
        )
        self._ribbon(
            ld, (pad - rx * 0.99, pad + ry * 0.62), scarf_len * 0.80, radius * 0.20,
            radius * 0.40, self.t * 2.0 + 2.3, CREAM_SCARF, ink_w, accent=ACCENT_LIGHT,
        )

        grounded = state["contact"] > 0.0
        feet_y = pad + ry * (0.95 if not grounded else 0.91)
        feet_spread = rx * (0.30 if not grounded else 0.44)
        for side_sign in (-1, 1):
            fw = rx * 0.30
            fh = ry * (0.10 if not grounded else 0.07)
            ld.rounded_rectangle(
                (pad + side_sign * feet_spread - fw / 2, feet_y - fh,
                 pad + side_sign * feet_spread + fw / 2, feet_y + fh),
                radius=fh, fill=CREAM_SCARF, outline=INK, width=ink_w,
            )

        ld.ellipse((pad - rx, pad - ry, pad + rx, pad + ry), fill=BODY)
        shade = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sd = ImageDraw.Draw(shade, "RGBA")
        sd.ellipse(
            (pad - rx * 1.06, pad + ry * 0.02, pad + rx * 1.06, pad + ry * 1.25),
            fill=(*BODY_DARK, 120),
        )
        clipped = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        clipped.paste(shade, (0, 0), mask)
        layer.alpha_composite(clipped)

        highlight = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        hd = ImageDraw.Draw(highlight, "RGBA")
        hd.ellipse(
            (pad - rx * 0.50, pad - ry * 0.78, pad + rx * 0.48, pad - ry * 0.08),
            fill=(255, 246, 228, 58),
        )
        clipped.paste(highlight, (0, 0), mask)
        layer.alpha_composite(clipped)

        ld.ellipse((pad - rx, pad - ry, pad + rx, pad + ry), outline=INK, width=ink_w)
        ld.arc(
            (pad - rx * 0.86, pad + ry * 0.02, pad + rx * 0.86, pad + ry * 0.90),
            start=205, end=335, fill=(*INK, 60), width=1,
        )

        rim = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        rd = ImageDraw.Draw(rim, "RGBA")
        rd.arc(
            (pad - rx * 0.99, pad - ry * 0.99, pad + rx * 0.99, pad + ry * 0.99),
            start=298, end=62, fill=(255, 248, 234, 150),
            width=max(3, int(radius * 0.065)),
        )
        clipped.paste(rim, (0, 0), mask)
        layer.alpha_composite(clipped)

        strap_w = max(2, int(radius * 0.058))
        strap = (
            (pad + rx * 0.72, pad + ry * 0.50),
            (pad + rx * 0.90, pad + ry * 0.22),
            (pad + rx * 0.92, pad - ry * 0.02),
        )
        ld.line(strap, fill=INK_SOFT, width=strap_w, joint="curve")
        ld.line([(x, y - 1) for x, y in strap], fill=(*CREAM_SCARF, 165), width=1, joint="curve")

        band = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        bd = ImageDraw.Draw(band, "RGBA")
        band_box = (pad - rx * 1.02, pad + ry * 0.50, pad + rx * 1.02, pad + ry * 0.72)
        bd.ellipse(band_box, fill=CREAM_SCARF)
        bd.arc(band_box, 188, 352, fill=INK, width=ink_w)
        bd.arc(band_box, 8, 172, fill=INK, width=ink_w)
        clipped.paste(band, (0, 0), mask)
        layer.alpha_composite(clipped)
        stripe = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sd2 = ImageDraw.Draw(stripe, "RGBA")
        sd2.arc(
            (band_box[0] + rx * 0.05, band_box[1] + ry * 0.05,
             band_box[2] - rx * 0.05, band_box[3] - ry * 0.05),
            start=200, end=340, fill=(*ACCENT, 235), width=max(2, int(radius * 0.024)),
        )
        clipped.paste(stripe, (0, 0), mask)
        layer.alpha_composite(clipped)

        knot_x, knot_y = pad - rx * 0.88, pad + ry * 0.61
        ld.ellipse(
            (knot_x - rx * 0.12, knot_y - ry * 0.10, knot_x + rx * 0.12, knot_y + ry * 0.10),
            fill=CREAM_SCARF, outline=INK, width=ink_w,
        )
        ld.ellipse(
            (knot_x - rx * 0.045, knot_y - ry * 0.038, knot_x + rx * 0.045, knot_y + ry * 0.038),
            fill=ACCENT,
        )

        bag_x, bag_y = pad + rx * 0.62, pad + ry * 0.62
        bag_w, bag_h = rx * 0.44, ry * 0.28
        ld.rounded_rectangle(
            (bag_x - bag_w / 2, bag_y - bag_h / 2, bag_x + bag_w / 2, bag_y + bag_h / 2),
            radius=radius * 0.035, fill=INK_SOFT, outline=INK, width=ink_w,
        )
        ld.rounded_rectangle(
            (bag_x - bag_w / 2, bag_y - bag_h / 2, bag_x + bag_w / 2, bag_y - bag_h * 0.08),
            radius=radius * 0.03, fill=ACCENT, outline=INK, width=max(1, ink_w - 1),
        )
        ld.ellipse(
            (bag_x - rx * 0.032, bag_y - bag_h * 0.14,
             bag_x + rx * 0.032, bag_y + bag_h * 0.02),
            fill=CREAM_SCARF, outline=INK, width=1,
        )
        env_cx = bag_x + rx * 0.05
        env_cy = bag_y + ry * 0.05
        env_w, env_h = rx * 0.12, ry * 0.088
        angle = math.radians(-12.0)
        ca, sa = math.cos(angle), math.sin(angle)
        corners = []
        for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            corners.append(
                (env_cx + dx * env_w * ca - dy * env_h * sa,
                 env_cy + dx * env_w * sa + dy * env_h * ca)
            )
        ld.polygon(corners, fill=CREAM_SCARF, outline=INK, width=max(1, ink_w - 1))
        apex = (env_cx, env_cy + env_h * 0.30)
        ld.line((corners[0], apex), fill=INK, width=1)
        ld.line((corners[1], apex), fill=INK, width=1)

        eye_y = pad - ry * 0.20
        eye_dx = rx * 0.27
        blink = 0.40 <= self.t % 0.5 <= 0.435 or 0.78 <= self.t <= 0.805
        if state["contact"] > 0.0:
            for sign in (-1, 1):
                ex = pad + sign * eye_dx
                ld.arc(
                    (ex - rx * 0.10, eye_y - ry * 0.05, ex + rx * 0.10, eye_y + ry * 0.10),
                    start=180, end=360, fill=INK, width=ink_w,
                )
            ld.ellipse(
                (pad - rx * 0.05, pad + ry * 0.02, pad + rx * 0.05, pad + ry * 0.12),
                fill=INK,
            )
        elif blink:
            for sign in (-1, 1):
                ex = pad + sign * eye_dx
                ld.line((ex - rx * 0.09, eye_y, ex + rx * 0.09, eye_y), fill=INK, width=ink_w)
        else:
            for sign in (-1, 1):
                ex = pad + sign * eye_dx
                ld.ellipse(
                    (ex - rx * 0.085, eye_y - ry * 0.115, ex + rx * 0.085, eye_y + ry * 0.115),
                    fill=INK,
                )
                ld.ellipse(
                    (ex - rx * 0.032, eye_y - ry * 0.085, ex + rx * 0.012, eye_y - ry * 0.030),
                    fill=(*PAPER_LIGHT, 245),
                )
            ld.arc(
                (pad - rx * 0.14, pad - ry * 0.01, pad + rx * 0.14, pad + ry * 0.13),
                start=18, end=162, fill=INK, width=ink_w,
            )

        for sign in (-1, 1):
            cheek_x = pad + sign * rx * 0.49
            ld.ellipse(
                (cheek_x - rx * 0.09, pad - ry * 0.04,
                 cheek_x + rx * 0.09, pad + ry * 0.08),
                fill=(*ACCENT_LIGHT, 95),
            )

        cap_base = pad - ry * 0.90
        ld.pieslice(
            (pad - rx * 0.68, cap_base - ry * 0.46, pad + rx * 0.62, cap_base + ry * 0.20),
            start=180, end=360, fill=CREAM_SCARF, outline=INK, width=ink_w,
        )
        ld.arc(
            (pad - rx * 0.50, cap_base - ry * 0.36, pad + rx * 0.44, cap_base + ry * 0.06),
            start=200, end=330, fill=(*INK, 70), width=1,
        )
        brim = (
            (pad + rx * 0.10, cap_base + ry * 0.02),
            (pad + rx * 1.02, cap_base + ry * 0.10),
            (pad + rx * 0.98, cap_base + ry * 0.23),
            (pad + rx * 0.14, cap_base + ry * 0.14),
        )
        ld.polygon(brim, fill=CREAM_SCARF, outline=INK, width=max(1, ink_w - 1))
        ld.line(
            (pad + rx * 0.20, cap_base + ry * 0.11, pad + rx * 0.92, cap_base + ry * 0.17),
            fill=(*INK, 55), width=1,
        )
        ld.rectangle(
            (pad - rx * 0.66, cap_base + ry * 0.02, pad + rx * 0.60, cap_base + ry * 0.10),
            fill=ACCENT, outline=INK, width=max(1, ink_w - 1),
        )
        ld.ellipse(
            (pad - rx * 0.10, cap_base - ry * 0.48, pad + rx * 0.06, cap_base - ry * 0.40),
            fill=ACCENT, outline=INK, width=1,
        )

        layer = layer.rotate(state["lean"], resample=Image.BICUBIC, center=(pad, pad))
        self.image.paste(layer, (int(cx - pad), int(cy - pad)), layer)

    def _ribbon(self, draw: ImageDraw.ImageDraw, start: tuple[float, float], length: float,
                width: float, amplitude: float, phase: float, color, ink_w: int,
                accent=None) -> None:
        points = []
        steps = 14
        for index in range(steps + 1):
            f = index / steps
            x = start[0] - f * length
            y = start[1] + amplitude * math.sin(phase + f * 3.0) * f + length * 0.10 * f * f
            points.append((x, y))
        upper = []
        lower = []
        for index, (x, y) in enumerate(points):
            f = index / steps
            if index == 0:
                dx, dy = points[1][0] - x, points[1][1] - y
            elif index == steps:
                dx, dy = x - points[-2][0], y - points[-2][1]
            else:
                dx = points[index + 1][0] - points[index - 1][0]
                dy = points[index + 1][1] - points[index - 1][1]
            scale = math.hypot(dx, dy) or 1.0
            nx, ny = -dy / scale, dx / scale
            half = width * (1.0 - 0.58 * f) / 2.0
            upper.append((x + nx * half, y + ny * half))
            lower.append((x - nx * half, y - ny * half))
        end_x, end_y = points[-1]
        prev_x, prev_y = points[-2]
        tail = math.hypot(end_x - prev_x, end_y - prev_y) or 1.0
        notch = (
            end_x - (end_x - prev_x) / tail * width * 0.62,
            end_y - (end_y - prev_y) / tail * width * 0.62,
        )
        draw.polygon(upper + [notch] + lower[::-1], fill=color, outline=INK, width=ink_w)
        if accent:
            draw.line(points[1:-1], fill=(*accent, 220), width=max(2, int(width * 0.20)))

    def _dust(self) -> None:
        for age, world_x in _recent_impacts(self.t):
            if age > 0.30:
                continue
            ix = self.sx(world_x, self.t * TILE_FRONT)
            fade = 1.0 - age / 0.30
            for puff in range(3):
                px = ix + self.unit((puff - 1) * (0.10 + age * 0.55))
                py = self.ground - self.unit(0.03 + age * 0.12)
                radius = self.unit(0.045 + age * 0.28)
                self.draw.ellipse(
                    (px - radius, py - radius * 0.62, px + radius, py + radius * 0.62),
                    fill=(*PAPER_LIGHT, int(170 * fade)),
                    outline=(*INK, int(95 * fade)), width=1,
                )
            ring = self.unit(0.14 + 0.55 * age / 0.30)
            self.draw.ellipse(
                (ix - ring, self.ground - ring * 0.13, ix + ring, self.ground + ring * 0.13),
                outline=(*INK, int(95 * fade)), width=max(1, self.line - 1),
            )
            seed = int(round(world_x * 1000))
            rng = random.Random(seed)
            for particle in range(13):
                angle = math.pi * (1.02 + 0.96 * rng.random())
                speed = 0.35 + 0.85 * rng.random()
                vx = math.cos(angle) * speed
                vy = math.sin(angle) * speed
                px = ix + vx * age * self.scale
                py = self.ground + vy * age * self.scale + 0.5 * 2.4 * (age ** 2) * self.scale
                size = self.unit(0.012 + 0.022 * rng.random()) * fade
                tone = ACCENT_DARK if particle % 4 == 0 else INK
                self.draw.polygon(
                    ((px, py), (px + size, py - size * 0.6), (px + size * 0.5, py + size * 0.5)),
                    fill=(*tone, int(190 * fade)),
                )

    # ----------------------------------------------------------------- finish
    def finish(self) -> Image.Image:
        small = self.image.convert("RGB").resize((self.out_w, self.out_h), Image.LANCZOS)
        compact = np.asarray(small, dtype=np.float32)
        vignette, fibre = _post_maps(self.out_w, self.out_h)
        rng = np.random.default_rng(17)
        grain = rng.normal(0.0, 1.35, (self.out_h, self.out_w, 1)).astype(np.float32)
        compact = compact * vignette[..., None] + fibre[..., None] * 1.4 + grain
        return Image.fromarray(np.clip(compact, 0, 255).astype(np.uint8), "RGB")


def render_frame(t: float, width: int, height: int) -> Image.Image:
    frame = Frame(width * SS, height * SS, t)
    frame.sky()
    frame.far()
    frame.back()
    frame.front()
    frame.street()
    frame.props()
    frame.ball()
    frame.sheets()
    return frame.finish()


def render_frames(out: Path, frames: int, width: int, height: int) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for index in range(frames):
        render_frame(index / frames, width, height).save(out / f"frame_{index + 1:04d}.png")
        if (index + 1) % 24 == 0:
            print(f"  frame {index + 1}/{frames}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Render the Paper City animation")
    parser.add_argument("--out", required=True)
    parser.add_argument("--frames", type=int, default=FRAMES)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    args = parser.parse_args()
    render_frames(Path(args.out), args.frames, args.width, args.height)


if __name__ == "__main__":
    main()
