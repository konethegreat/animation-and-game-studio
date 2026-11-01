"""Shot 03: the sketchbook page becomes a paper city.

Cream card stock buildings with ink windows, one terracotta accent, loose
sheets drifting down the street. The camera walks the street at eye height so
the city keeps opening instead of presenting itself.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy

import film_common as film

PAPER = (0.90, 0.85, 0.74)
FAR_PAPER = (0.94, 0.90, 0.81)
INK = (0.040, 0.040, 0.045)
WARM = (0.82, 0.40, 0.18)


def windows(prefix, face_x, y, span, height, ink, glow, rng, outward):
    """Ink windows pressed onto one street facing wall."""
    columns = max(1, int(span / 0.15))
    rows = max(1, int((height - 0.40) / 0.18))
    for column in range(columns):
        for row in range(rows):
            if rng.random() < 0.10:
                continue
            wy = y - span / 2 + (column + 0.5) * (span / columns)
            wz = 0.30 + (row + 0.5) * ((height - 0.46) / rows)
            mat = glow if rng.random() < 0.10 else ink
            film.box(
                f"{prefix}Win{column}_{row}",
                (0.012, min(0.075, span / columns * 0.58), 0.110),
                (face_x + outward * 0.006, wy, wz), mat, bevel=0.0,
            )


def building(name, side, x, y, width, depth, height, paper, ink, glow, terracotta, rng, detailed=True):
    film.box(name, (width, depth, height), (x, y, height / 2), paper, bevel=0.004)
    film.box(
        f"{name}Rim", (width + 0.014, depth + 0.014, 0.014),
        (x, y, height + 0.007), ink, bevel=0.001,
    )
    outward = -1.0 if side > 0 else 1.0
    face = x - side * (width / 2)
    if detailed:
        windows(name, face, y, depth, height, ink, glow, rng, outward)
        film.box(
            f"{name}Door", (0.012, 0.18, 0.30),
            (face + outward * 0.006, y - depth * 0.18, 0.15), ink, bevel=0.0,
        )
        film.box(
            f"{name}Stoop", (0.10, 0.26, 0.05),
            (face + outward * 0.05, y - depth * 0.18, 0.025), paper, bevel=0.002,
        )

    roof = rng.random()
    if roof < 0.30:
        film.box(
            f"{name}Tank", (0.11, 0.11, 0.15),
            (x, y + rng.uniform(-0.1, 0.1), height + 0.10), ink, bevel=0.004,
        )
    elif roof < 0.55:
        film.box(
            f"{name}Stack", (0.065, 0.065, 0.20),
            (x + rng.uniform(-0.08, 0.08), y, height + 0.13), paper, bevel=0.002,
        )

    if detailed and height > 1.25 and rng.random() < 0.6:
        drop = rng.uniform(0.80, 1.30)
        awning = film.box(
            f"{name}Awning", (0.32, depth * 0.60, 0.018),
            (x + outward * (width / 2 + 0.14), y, drop),
            terracotta, bevel=0.002,
        )
        awning.rotation_euler = (0.0, math.radians(outward * 16.0), 0.0)


def tree(name, x, y, height, trunk_mat, leaf_mat, rng):
    film.cylinder(f"{name}Trunk", 0.022, height * 0.55, (x, y, height * 0.275), trunk_mat, vertices=12)
    for level in range(3):
        radius = 0.16 - level * 0.04
        film.cone(
            f"{name}Crown{level}", radius, 0.0, 0.24,
            (x, y, height * 0.52 + level * 0.16), leaf_mat, vertices=7,
        )
    lean = film.empty(f"{name}Lean", (x, y, 0.0))
    lean.rotation_euler = (math.radians(rng.uniform(-3, 3)), math.radians(rng.uniform(-4, 4)), 0.0)
    for obj in (bpy.data.objects.get(f"{name}Trunk"),):
        if obj:
            film.parent_keep(obj, lean)


def flag(name, x, y, z, width, height, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(
        [(-width / 2, 0.0, 0.0), (width / 2, 0.0, 0.0), (0.0, 0.0, -height)],
        [], [(0, 1, 2)],
    )
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (x, y, z)
    obj.data.materials.append(mat)
    return obj


def bunting(start, end, z, count, mat_a, mat_b, string_mat):
    sx, sy = start
    ex, ey = end
    length = math.hypot(ex - sx, ey - sy)
    angle = math.atan2(ey - sy, ex - sx)
    line = film.cylinder(
        "BuntingLine", 0.0035, length, ((sx + ex) / 2, (sy + ey) / 2, z),
        string_mat, rotation=(math.radians(90), 0, angle), vertices=8,
    )
    for index in range(count):
        t = (index + 0.5) / count
        x = sx + (ex - sx) * t
        y = sy + (ey - sy) * t
        sag = 0.10 * math.sin(math.pi * t)
        flag(
            f"Flag{index}", x, y, z - 0.04 - sag, 0.11, 0.16,
            mat_a if index % 2 == 0 else mat_b,
        )
    return line


def build(scene, args):
    rng = random.Random(23)
    paper = film.paper_material("PaperCard", PAPER)
    far_paper = film.paper_material("PaperCardFar", FAR_PAPER)
    ink = film.material("Ink", INK, roughness=0.9)
    glow = film.material("LitWindow", WARM, roughness=0.6, emission=WARM, strength=1.4)
    terracotta = film.material("PaperTerracotta", (0.66, 0.30, 0.16), roughness=0.8)
    trunk = film.material("PaperBark", (0.30, 0.24, 0.18), roughness=0.9)
    leaf = film.material("PaperLeaf", (0.48, 0.52, 0.30), roughness=0.85)

    film.plane("Street", (12.0, 22.0), (0.0, 4.0, 0.0), paper)
    for side in (-1, 1):
        film.box(
            f"Curb{side}", (0.10, 22.0, 0.03),
            (side * 1.72, 4.0, 0.015), far_paper, bevel=0.002,
        )
    for index in range(12):
        film.box(
            f"StreetDash{index}", (0.02, 0.40, 0.002),
            (0.0, -2.0 + index * 0.9, 0.002), ink, bevel=0.0,
        )

    # Front row, then a taller stepped back row so the skyline has layers.
    for side in (-1, 1):
        y = -1.3
        placed = 0
        while y < 7.8:
            span = rng.uniform(0.60, 1.05)
            depth = rng.uniform(0.70, 1.10)
            height = rng.uniform(0.85, 1.85)
            x = side * (1.80 + depth / 2)
            building(
                f"Front{side}{placed}", side, x, y + span / 2, depth, span,
                height, paper, ink, glow, terracotta, rng,
            )
            placed += 1
            y += span + rng.uniform(0.08, 0.26)

        y = -1.9
        placed = 0
        while y < 8.4:
            span = rng.uniform(0.75, 1.30)
            depth = rng.uniform(0.9, 1.4)
            height = rng.uniform(1.8, 3.2)
            x = side * (2.55 + depth / 2)
            building(
                f"Back{side}{placed}", side, x, y + span / 2, depth, span,
                height, far_paper, ink, glow, terracotta, rng, detailed=False,
            )
            placed += 1
            y += span + rng.uniform(0.20, 0.60)

    film.box("FarBlock", (3.4, 0.6, 1.7), (0.0, 10.2, 0.85), far_paper, bevel=0.004)
    film.box("FarBlockRim", (3.42, 0.62, 0.03), (0.0, 10.2, 1.715), ink, bevel=0.002)
    for column in range(9):
        for row in range(5):
            film.box(
                f"FarWin{column}_{row}", (0.11, 0.012, 0.13),
                (-1.28 + column * 0.32, 9.89, 0.34 + row * 0.28),
                ink, bevel=0.0,
            )
    film.box("FarDoor", (0.30, 0.012, 0.52), (0.0, 9.88, 0.26), ink, bevel=0.0)

    sun_mat = film.material(
        "PaperSun", (1.0, 0.95, 0.82), roughness=0.5,
        emission=(1.0, 0.91, 0.72), strength=2.2,
    )
    bpy.ops.mesh.primitive_circle_add(
        vertices=96, radius=0.72, fill_type="NGON",
        location=(2.05, 16.0, 4.75), rotation=(math.radians(90), 0, 0),
    )
    sun = bpy.context.object
    sun.name = "PaperSunDisc"
    sun.data.materials.append(sun_mat)

    for index, (x, y) in enumerate(((-1.28, 0.4), (1.30, 1.9), (-1.30, 3.6), (1.32, 5.2))):
        tree(f"Tree{index}", x, y, rng.uniform(1.5, 2.0), trunk, leaf, rng)

    for index, y in enumerate((-0.6, 2.1, 6.0)):
        bunting(
            (-1.55, y), (1.55, y + 0.25), rng.uniform(2.15, 2.45), 13,
            terracotta, far_paper, ink,
        )

    for index, (x, y) in enumerate(((1.35, 1.1), (-1.36, 3.1), (1.34, 5.6))):
        film.box(f"Crate{index}", (0.20, 0.20, 0.20), (x, y, 0.10), terracotta, bevel=0.004)
        if index != 1:
            film.box(f"CrateTop{index}", (0.15, 0.15, 0.15), (x, y, 0.275), far_paper, bevel=0.004)

    for index, (x, y) in enumerate(((1.55, -0.2), (-1.55, 2.4), (1.55, 4.6), (-1.5, 6.2))):
        film.cylinder(f"Post{index}", 0.018, 1.9, (x, y, 0.95), ink, vertices=10)
        bulb = film.sphere(
            f"PostGlobe{index}", (x, y, 1.92), (0.06, 0.06, 0.07),
            film.material(f"PostGlow{index}", (1.0, 0.82, 0.55), roughness=0.4,
                          emission=(1.0, 0.78, 0.48), strength=2.0), 20, 12,
        )

    sheets = []
    sheet_mat = film.paper_material("LooseSheet", (0.97, 0.93, 0.84))
    for index in range(14):
        x = rng.uniform(-1.3, 1.3)
        y = rng.uniform(-2.6, 6.0)
        z = rng.uniform(0.45, 2.9)
        obj = film.plane(
            f"Sheet{index}", (rng.uniform(0.10, 0.22), rng.uniform(0.13, 0.28)),
            (x, y, z), sheet_mat,
            rotation=(math.radians(rng.uniform(55, 105)), 0, math.radians(rng.uniform(0, 360))),
        )
        sheets.append(obj)

    film.area_light(
        "SunKey", (-4.5, 2.0, 5.5), (0.0, 2.0, 1.0),
        energy=110, size=3.4, color=(1.0, 0.93, 0.80),
    )
    film.area_light(
        "SkyFill", (5.0, -1.0, 3.4), (0.0, 2.0, 1.4),
        energy=18, size=3.2, color=(0.70, 0.80, 1.0),
    )
    film.area_light(
        "FarRim", (0.0, 10.0, 3.6), (0.0, 4.0, 1.2),
        energy=40, size=2.6, color=(1.0, 0.80, 0.58),
    )
    film.world(scene, color=(0.96, 0.92, 0.84), strength=0.55)
    film.haze(scene, size=(14.0, 20.0, 7.0), center=(0.0, 4.5, 2.6), density=0.003, color=(1.0, 0.94, 0.82))

    motes = film.dust(scene, count=32, center=(0.0, 2.6, 1.6), spread=(2.2, 3.4, 1.6), seed=21)

    rig = film.camera(
        (-0.45, -3.60, 1.20), (-0.05, 3.0, 1.52),
        lens=35, fstop=2.6,
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (-0.45, -3.60, 1.20))
    film.keyframe(camera, "location", 120, (-0.05, -2.25, 1.24))
    film.keyframe(camera, "location", 240, (0.35, -1.05, 1.28))
    film.keyframe(target, "location", 1, (-0.05, 3.0, 1.52))
    film.keyframe(target, "location", 120, (0.25, 3.8, 1.56))
    film.keyframe(target, "location", 240, (0.45, 4.4, 1.60))
    film.ease(camera)
    film.ease(target)

    for index, sheet in enumerate(sheets):
        start = sheet.location.copy()
        end = (
            start.x + rng.uniform(-0.20, 0.20),
            start.y + rng.uniform(0.25, 0.70),
            max(0.16, start.z - rng.uniform(0.35, 0.80)),
        )
        rotation = sheet.rotation_euler.copy()
        film.keyframe(sheet, "location", 1, (start.x, start.y, start.z))
        film.keyframe(sheet, "location", 240, end)
        film.keyframe(sheet, "rotation_euler", 1, (rotation.x, rotation.y, rotation.z))
        film.keyframe(
            sheet, "rotation_euler", 240,
            (
                rotation.x + math.radians(rng.uniform(-25, 25)),
                rotation.y,
                rotation.z + math.radians(rng.uniform(40, 110)),
            ),
        )
        film.ease(sheet)

    film.keyframe(motes, "location", 1, (0.0, 2.6, 1.55))
    film.keyframe(motes, "location", 240, (0.0, 2.8, 1.80))
    film.ease(motes)

    return {"camera": camera, "target": target, "sheets": sheets, "sun": sun}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
