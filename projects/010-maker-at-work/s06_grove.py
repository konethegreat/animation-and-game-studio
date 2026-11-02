"""Shot 06: a grove of hanging lanterns at the last of the light.

Paper trees line a pale path. Lanterns hang from the branches, each one a
piece of work left burning, and the hero lantern leads down the path toward
a low sun behind the trunks.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy

import film_common as film

PAPER = (0.86, 0.80, 0.68)
BARK = (0.28, 0.22, 0.16)
CROWN_A = (0.44, 0.42, 0.24)
CROWN_B = (0.64, 0.38, 0.16)
GROUND = (0.26, 0.20, 0.15)
PATH = (0.62, 0.55, 0.44)
LIME = (0.62, 1.0, 0.18)
BRASS = (0.34, 0.24, 0.11)


def tree(name, x, y, height, trunk, crowns, rng):
    film.cylinder(f"{name}Trunk", 0.034, height * 0.62, (x, y, height * 0.31), trunk, vertices=12)
    base = 0.28 + (height - 2.1) * 0.10
    for level in range(3):
        film.cone(
            f"{name}Crown{level}", base - level * (base * 0.22), 0.0, 0.46,
            (x, y, height * 0.52 + level * 0.30), crowns[level % len(crowns)], vertices=7,
        )


def hanging(name, x, y, top, drop, glass_mat, brass, cord, rng):
    pivot = film.empty(f"{name}Pivot", (x, y, top))
    film.cylinder(f"{name}Cord", 0.0035, drop, (x, y, top - drop / 2), cord, vertices=6)
    film.parent_keep(bpy.data.objects[f"{name}Cord"], pivot)
    film.cylinder(f"{name}Cap", 0.042, 0.020, (x, y, top - drop + 0.045), brass, vertices=12)
    film.parent_keep(bpy.data.objects[f"{name}Cap"], pivot)
    film.cylinder(f"{name}Glass", 0.034, 0.085, (x, y, top - drop - 0.010), glass_mat, vertices=12)
    film.parent_keep(bpy.data.objects[f"{name}Glass"], pivot)
    film.cylinder(f"{name}Base", 0.040, 0.018, (x, y, top - drop - 0.060), brass, vertices=12)
    film.parent_keep(bpy.data.objects[f"{name}Base"], pivot)
    phase = rng.uniform(0.0, math.tau)
    film.keyframe(pivot, "rotation_euler", 1, (0.0, math.radians(2.4), 0.0))
    film.keyframe(pivot, "rotation_euler", 120, (0.0, math.radians(-2.2), 0.0))
    film.keyframe(pivot, "rotation_euler", 240, (0.0, math.radians(2.4), 0.0))
    pivot.rotation_euler = (math.sin(phase) * 0.02, 0.0, math.cos(phase) * 0.02)
    film.ease(pivot)
    return pivot


def build(scene, args):
    rng = random.Random(73)
    paper = film.paper_material("GrovePaper", PAPER)
    bark = film.material("GroveBark", BARK, roughness=0.9)
    crown_a = film.material("GroveCrownA", CROWN_A, roughness=0.87)
    crown_b = film.material("GroveCrownB", CROWN_B, roughness=0.85)
    ground = film.material("GroveGround", GROUND, roughness=0.96)
    path = film.paper_material("GrovePath", PATH)
    brass = film.material("GroveBrass", BRASS, roughness=0.35, metallic=0.8)
    cord = film.material("GroveCord", (0.05, 0.045, 0.04), roughness=0.9)
    lime = film.material("GroveLime", LIME, roughness=0.3, emission=LIME, strength=1.0)
    lime_dim = film.material("GroveLimeDim", LIME, roughness=0.3, emission=LIME, strength=0.75)
    firefly = film.material("GroveFirefly", (1.0, 0.86, 0.45), roughness=1.0, emission=(1.0, 0.55, 0.12), strength=1.6)
    petal = film.paper_material("GrovePetal", (0.93, 0.72, 0.46))

    film.plane("GroveFloor", (60.0, 60.0), (0.0, 12.0, 0.0), ground)
    film.box("GrovePath", (0.94, 24.0, 0.010), (0.0, 7.0, 0.005), path, bevel=0.0)

    for index in range(13):
        side = -1.0 if index % 2 else 1.0
        x = side * rng.uniform(1.15, 2.7)
        y = rng.uniform(1.6, 20.0)
        tree(f"GroveTree{index}", x, y, rng.uniform(2.1, 3.3), bark, (crown_a, crown_b), rng)

    tree("FrameLeft", -3.05, 1.4, 3.9, bark, (crown_a, crown_b), rng)
    tree("FrameRight", 3.15, 2.3, 3.7, bark, (crown_b, crown_a), rng)

    for side in (-1.0, 1.0):
        film.cylinder(
            f"Wire{'Left' if side < 0 else 'Right'}", 0.005, 22.0,
            (side * 0.75, 10.5, 2.45), cord, rotation=(math.radians(90), 0, 0), vertices=6,
        )

    for index in range(16):
        side = -1.0 if index % 2 else 1.0
        x = side * 0.75
        y = 1.8 + index * 1.12
        drop = rng.uniform(0.55, 0.95)
        hanging(f"Hang{index}", x, y, 2.45, drop, lime_dim if index % 3 else lime, brass, cord, rng)

    bpy.ops.mesh.primitive_circle_add(
        vertices=96, radius=1.35, fill_type="NGON",
        location=(1.9, 26.0, 1.55), rotation=(math.radians(90), 0, 0),
    )
    sun = bpy.context.object
    sun.name = "GroveSun"
    sun.data.materials.append(
        film.material("GroveSunFace", (1.0, 0.80, 0.52), roughness=0.5, emission=(1.0, 0.58, 0.24), strength=4.0)
    )

    hero = film.lantern((0.14, 3.2, 1.30))
    for key in ("handle", "cap", "glass", "base"):
        hero[key].scale = (1.45, 1.45, 1.45)
    hero["light"].data.energy = 30
    hero["light"].data.color = (0.66, 1.0, 0.34)
    hero["glass"].data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.3

    hero_pivot = film.empty("HeroDrift", (0.14, 3.2, 1.30))
    for key in ("handle", "cap", "glass", "base", "light"):
        film.parent_keep(hero[key], hero_pivot)
    film.keyframe(hero_pivot, "location", 1, (0.32, 3.0, 1.34))
    film.keyframe(hero_pivot, "location", 120, (0.12, 4.6, 1.30))
    film.keyframe(hero_pivot, "location", 240, (-0.10, 6.4, 1.36))
    film.ease(hero_pivot)

    fly_pivot = film.empty("FireflyDrift", (0.0, 4.0, 1.5))
    for index in range(26):
        point = (
            rng.uniform(-1.4, 1.4),
            rng.uniform(-1.0, 5.5),
            rng.uniform(0.4, 2.0),
        )
        size = rng.uniform(0.004, 0.009)
        mote = film.sphere(f"Firefly{index}", point, (size, size, size), firefly, 8, 6)
        film.parent_keep(mote, fly_pivot)
    film.keyframe(fly_pivot, "location", 1, (0.0, 3.6, 1.4))
    film.keyframe(fly_pivot, "location", 240, (0.25, 4.4, 1.7))
    film.keyframe(fly_pivot, "rotation_euler", 1, (0.0, 0.0, 0.0))
    film.keyframe(fly_pivot, "rotation_euler", 240, (0.0, 0.0, math.radians(4)))
    film.ease(fly_pivot)

    petals = []
    for index in range(12):
        obj = film.plane(
            f"Petal{index}", (rng.uniform(0.05, 0.10), rng.uniform(0.06, 0.12)),
            (rng.uniform(-1.3, 1.3), rng.uniform(1.0, 12.0), rng.uniform(1.4, 3.0)),
            petal, rotation=(math.radians(rng.uniform(50, 110)), 0, math.radians(rng.uniform(0, 360))),
        )
        petals.append((obj, obj.location.copy(), rng.uniform(-0.10, 0.10), rng.uniform(0.015, 0.05)))

    film.area_light(
        "GroveKey", (3.2, -2.0, 4.4), (0.0, 3.4, 1.2),
        energy=120, size=4.0, color=(1.0, 0.90, 0.74),
    )
    film.area_light(
        "GroveRim", (0.0, 18.0, 3.6), (0.0, 6.0, 1.2),
        energy=150, size=4.0, color=(1.0, 0.66, 0.36),
    )
    film.area_light(
        "GroveFill", (-3.0, -1.0, 2.4), (0.0, 3.0, 1.4),
        energy=26, size=3.0, color=(0.70, 0.78, 1.0),
    )
    film.world(scene, color=(0.50, 0.38, 0.32), strength=0.55)
    film.haze(scene, size=(16.0, 24.0, 8.0), center=(0.0, 7.0, 2.4), density=0.0022, color=(1.0, 0.86, 0.70))

    rig = film.camera(
        (0.22, -2.40, 1.26), (0.04, 3.2, 1.38),
        lens=38, fstop=2.4,
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (0.22, -2.40, 1.26))
    film.keyframe(camera, "location", 120, (0.10, -0.55, 1.30))
    film.keyframe(camera, "location", 240, (0.02, 1.10, 1.34))
    film.keyframe(target, "location", 1, (0.04, 3.2, 1.38))
    film.keyframe(target, "location", 120, (0.02, 4.0, 1.34))
    film.keyframe(target, "location", 240, (0.00, 4.8, 1.30))
    film.ease(camera)
    film.ease(target)

    for index, (obj, start, drift, fall) in enumerate(petals):
        film.keyframe(obj, "location", 1, start)
        film.keyframe(obj, "location", 240, (start.x + drift, start.y + 0.4, max(0.05, start.z - 2.4)))
        film.keyframe(obj, "rotation_euler", 1, tuple(obj.rotation_euler))
        film.keyframe(obj, "rotation_euler", 240, (
            obj.rotation_euler.x + math.radians(160),
            obj.rotation_euler.y + math.radians(90),
            obj.rotation_euler.z + math.radians(220),
        ))
        film.ease(obj)

    film.pulse(hero["light"], args.frames_end, base=30.0, amp=3.0, period=72, phase=1.2)
    film.fade(hero["glass"].data.materials[0], "Emission Strength", [(1, 1.1), (120, 1.45), (240, 1.15)])

    film.glow(scene, threshold=0.9, size=10, mix=-0.72)

    return {"camera": camera, "target": target, "hero": hero, "sun": sun}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
