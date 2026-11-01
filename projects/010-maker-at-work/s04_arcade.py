"""Shot 04: the city at night, neon on wet stone.

Tall dark blocks, vertical tube signs, one arch over the street. The street
is wet enough to carry colour, the air is thick enough to hold glow, and one
sign stutters so the frame never feels like a still.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy

import film_common as film

MAGENTA = (1.0, 0.03, 0.40)
CYAN = (0.02, 0.72, 1.0)
AMBER = (1.0, 0.52, 0.12)
STONE = (0.052, 0.055, 0.070)
ASPHALT = (0.020, 0.022, 0.030)


def tube(name, location, rotation, length, radius, mat):
    return film.cylinder(name, radius, length, location, mat, rotation=rotation, vertices=16, bevel=0.0)


def sign_panel(name, face_x, y, z, width, height, outward, back_mat, tube_mat, rng):
    film.box(f"{name}Back", (0.06, width, height), (face_x + outward * 0.03, y, z), back_mat, bevel=0.002)
    film.box(
        f"{name}Inner", (0.012, width * 0.90, height * 0.86),
        (face_x + outward * 0.062, y, z), film.material(f"{name}Dark", (0.006, 0.007, 0.010), roughness=0.5),
        bevel=0.0,
    )
    for edge in (-1, 1):
        film.box(
            f"{name}Edge{edge}", (0.014, width * 0.92, 0.016),
            (face_x + outward * 0.07, y, z + edge * height * 0.44), tube_mat, bevel=0.0,
        )
    bars = max(2, int(height / 0.11))
    for index in range(bars):
        if rng.random() < 0.30:
            continue
        film.box(
            f"{name}Bar{index}", (0.014, width * rng.uniform(0.22, 0.62), 0.014),
            (face_x + outward * 0.072, y + rng.uniform(-width * 0.18, width * 0.18),
             z - height / 2 + (index + 0.5) * (height / bars)),
            tube_mat, bevel=0.0,
        )


def build(scene, args):
    rng = random.Random(41)
    stone = film.material("NightStone", STONE, roughness=0.82)
    asphalt = film.material("WetAsphalt", ASPHALT, roughness=0.10, metallic=0.55)
    back = film.material("SignBack", (0.010, 0.011, 0.016), roughness=0.6, metallic=0.4)
    magenta = film.material("NeonMagenta", MAGENTA, roughness=0.4, emission=MAGENTA, strength=3.6)
    cyan = film.material("NeonCyan", CYAN, roughness=0.4, emission=CYAN, strength=3.0)
    amber = film.material("NeonAmber", AMBER, roughness=0.4, emission=AMBER, strength=2.6)
    window = film.material("LitRoom", (1.0, 0.74, 0.44), roughness=0.7, emission=(1.0, 0.72, 0.42), strength=0.9)

    film.plane("Street", (14.0, 24.0), (0.0, 4.0, 0.0), asphalt)
    for side in (-1, 1):
        film.box(f"Curb{side}", (0.14, 24.0, 0.08), (side * 1.78, 4.0, 0.04), stone, bevel=0.002)

    facade_lamps = []
    for side in (-1, 1):
        y = -1.6
        placed = 0
        while y < 8.2:
            span = rng.uniform(0.9, 1.5)
            depth = rng.uniform(0.8, 1.2)
            height = rng.uniform(2.6, 4.4)
            x = side * (1.95 + depth / 2)
            face = x - side * (depth / 2)
            outward = -side
            film.box(f"Tower{side}{placed}", (depth, span, height), (x, y + span / 2, height / 2), stone, bevel=0.004)
            film.box(
                f"TowerRim{side}{placed}", (depth + 0.02, span + 0.02, 0.04),
                (x, y + span / 2, height + 0.02), back, bevel=0.002,
            )
            if rng.random() < 0.7:
                sign_panel(
                    f"Sign{side}{placed}", face, y + span / 2, rng.uniform(1.4, 2.5),
                    rng.uniform(0.30, 0.55), rng.uniform(0.45, 0.85), outward,
                    back, magenta if side < 0 else cyan, rng,
                )
            for index in range(3):
                if rng.random() < 0.4:
                    tube(
                        f"Tube{side}{placed}{index}", (face + outward * 0.05, y + 0.2 + index * 0.35, height * 0.62),
                        (0.0, 0.0, 0.0), rng.uniform(0.6, 1.4), 0.012,
                        cyan if side < 0 else magenta,
                    )
            if rng.random() < 0.5:
                lit = window
                film.box(
                    f"Room{side}{placed}", (0.01, 0.12, 0.10),
                    (face + outward * 0.006, y + span * 0.65, rng.uniform(2.4, height - 0.4)),
                    lit, bevel=0.0,
                )
            if rng.random() < 0.6:
                film.box(
                    f"Unit{side}{placed}", (0.16, 0.22, 0.16),
                    (face + outward * 0.08, y + span * 0.3, rng.uniform(2.2, 3.4)),
                    stone, bevel=0.004,
                )
            placed += 1
            y += span + rng.uniform(0.15, 0.4)

    arch_y = 6.0
    tube("ArchTube", (0.0, arch_y, 3.40), (0.0, math.radians(90), 0.0), 4.0, 0.028, amber)
    for side in (-1, 1):
        tube(
            f"ArchPost{side}", (side * 1.98, arch_y, 1.70),
            (0.0, 0.0, 0.0), 3.40, 0.024, amber,
        )
    film.box("ArchSign", (1.30, 0.06, 0.42), (0.0, arch_y, 3.05), back, bevel=0.004)
    film.box("ArchGlow", (1.10, 0.012, 0.26), (0.0, arch_y - 0.04, 3.05), magenta, bevel=0.0)
    for index in range(5):
        film.box(
            f"ArchBar{index}", (0.16, 0.014, 0.02),
            (-0.40 + index * 0.20, arch_y - 0.05, 3.05), back, bevel=0.0,
        )

    for side, color in ((-1, magenta), (1, cyan)):
        film.cylinder(
            f"KerbTube{side}", 0.020, 8.6, (side * 1.66, 2.4, 0.035), color,
            rotation=(math.radians(90), 0.0, 0.0), vertices=12, bevel=0.0,
        )

    for index, y in enumerate((-0.4, 2.2, 4.8, 7.2)):
        film.cylinder(f"Post{index}", 0.026, 2.2, (1.62, y, 1.1), stone, vertices=12)
        film.sphere(
            f"PostGlobe{index}", (1.60, y, 2.22), (0.07, 0.07, 0.08),
            amber, 20, 12,
        )
        data = bpy.data.lights.new(f"StreetPool{index}", type="POINT")
        data.energy = 45
        data.color = (1.0, 0.62, 0.30)
        data.shadow_soft_size = 0.10
        lamp = bpy.data.objects.new(f"StreetPool{index}", data)
        bpy.context.scene.collection.objects.link(lamp)
        lamp.location = (1.58, y, 2.18)

    for index, (x, y, color, energy) in enumerate((
        (-1.55, 0.6, MAGENTA, 260.0),
        (1.55, 1.8, CYAN, 220.0),
        (-1.55, 3.9, MAGENTA, 200.0),
        (1.55, 5.4, CYAN, 160.0),
    )):
        data = bpy.data.lights.new(f"NeonBounce{index}", type="POINT")
        data.energy = energy
        data.color = color
        data.shadow_soft_size = 0.25
        lamp = bpy.data.objects.new(f"NeonBounce{index}", data)
        bpy.context.scene.collection.objects.link(lamp)
        lamp.location = (x, y, 1.9)

    puddle = film.material("Puddle", (0.010, 0.012, 0.020), roughness=0.04, metallic=0.9)
    for index in range(6):
        bpy.ops.mesh.primitive_circle_add(
            vertices=48, radius=rng.uniform(0.35, 0.85), fill_type="NGON",
            location=(rng.uniform(-1.2, 1.2), rng.uniform(-2.0, 6.0), 0.004),
        )
        obj = bpy.context.object
        obj.name = f"Puddle{index}"
        obj.scale = (1.0, rng.uniform(1.2, 2.2), 1.0)
        obj.data.materials.append(puddle)

    film.area_light(
        "MoonRim", (-3.0, 6.0, 6.0), (0.0, 3.0, 1.0),
        energy=90, size=4.0, color=(0.45, 0.55, 1.0),
    )
    film.world(scene, color=(0.010, 0.014, 0.030), strength=0.30)
    film.haze(scene, size=(12.0, 20.0, 8.0), center=(0.0, 3.0, 2.4), density=0.008, color=(0.55, 0.62, 1.0), anisotropy=0.55)

    rig = film.camera(
        (-0.25, -3.60, 1.25), (0.05, 3.2, 1.45),
        lens=32, fstop=2.0,
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (-0.25, -3.60, 1.25))
    film.keyframe(camera, "location", 120, (0.05, -2.20, 1.35))
    film.keyframe(camera, "location", 240, (0.25, -0.90, 1.45))
    film.keyframe(target, "location", 1, (0.05, 3.2, 1.45))
    film.keyframe(target, "location", 120, (0.10, 3.2, 1.55))
    film.keyframe(target, "location", 240, (0.15, 3.6, 1.75))
    film.ease(camera)
    film.ease(target)

    film.fade(magenta, "Emission Strength", [
        (1, 3.6), (58, 3.6), (61, 0.9), (64, 4.2), (126, 4.2),
        (129, 0.6), (132, 3.8), (240, 3.6),
    ])
    film.fade(cyan, "Emission Strength", [(1, 3.0), (120, 3.3), (240, 2.8)])

    return {"camera": camera, "target": target, "arch": bpy.data.objects.get("ArchSign")}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
