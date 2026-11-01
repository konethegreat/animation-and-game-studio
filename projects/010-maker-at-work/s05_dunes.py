"""Shot 05: the lantern crossing the dunes under a cold sky.

The desert is a low, slow sea. Moonlight rakes the sand ridges, a lantern
drifts across the frame with a tail of embers, and the sky holds a small
field of stars.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy
from mathutils import Vector

import film_common as film

SAND = (0.52, 0.31, 0.16)
SAND_FAR = (0.32, 0.22, 0.14)
LIME = (0.55, 1.0, 0.12)


def terrain(mat, phase=0.4):
    bpy.ops.mesh.primitive_grid_add(
        x_subdivisions=240, y_subdivisions=240, size=1.0, location=(0.0, 25.0, 0.0),
    )
    obj = bpy.context.object
    obj.name = "Dunes"
    obj.scale = (120.0, 70.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for vertex in obj.data.vertices:
        x, y = vertex.co.x, vertex.co.y
        far = min(1.0, max(0.0, (y + 5.0) / 50.0))
        amplitude = 0.6 + 6.0 * far ** 1.2
        ridge = (
            0.55 * abs(math.sin(x * 0.26 + y * 0.31 + phase)) ** 0.75
            + 0.22 * math.sin(y * 0.20 + x * 0.06 + phase * 0.7)
            + 0.18 * math.sin(y * 0.44 - x * 0.16 + phase * 1.3)
            + 0.04 * math.sin(x * 2.6 + y * 1.9 + phase * 2.0)
        )
        vertex.co.z = amplitude * ridge
    obj.data.update()
    film.smooth(obj, 70.0)
    obj.data.materials.append(mat)
    return obj


def sun(name, location, target, energy, color, angle=0.02):
    data = bpy.data.lights.new(name, type="SUN")
    data.energy = energy
    data.color = color
    data.angle = angle
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    aim = Vector(target) - Vector(location)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = aim.to_track_quat("-Z", "Y")
    return obj


def build(scene, args):
    rng = random.Random(59)
    sand = film.material("DuneSand", SAND, roughness=0.94)
    far_sand = film.material("DuneSandFar", SAND_FAR, roughness=0.96)
    lime = film.material("LanternLime", LIME, roughness=0.3, emission=LIME, strength=4.0)
    brass = film.material("LanternBrass", (0.30, 0.22, 0.10), roughness=0.32, metallic=0.85)
    star_cool = film.material("StarCool", (0.75, 0.85, 1.0), roughness=1.0, emission=(0.72, 0.82, 1.0), strength=2.6)
    star_warm = film.material("StarWarm", (1.0, 0.90, 0.74), roughness=1.0, emission=(1.0, 0.88, 0.70), strength=1.8)
    ember = film.material("Ember", (1.0, 0.55, 0.18), roughness=1.0, emission=(1.0, 0.48, 0.14), strength=2.6)

    terrain(sand, phase=0.4)

    bpy.ops.mesh.primitive_circle_add(
        vertices=96, radius=1.45, fill_type="NGON",
        location=(-7.5, 42.0, 6.0), rotation=(math.radians(90), 0, 0),
    )
    moon = bpy.context.object
    moon.name = "Moon"
    moon.data.materials.append(
        film.material("MoonFace", (0.92, 0.94, 1.0), roughness=0.8, emission=(0.82, 0.88, 1.0), strength=6.0)
    )

    for index in range(90):
        azimuth = rng.uniform(-1.25, 1.25)
        radius = rng.uniform(40.0, 50.0)
        x = math.sin(azimuth) * radius
        y = 25.0 + math.cos(azimuth) * radius
        z = rng.uniform(0.8, 13.0)
        size = rng.uniform(0.03, 0.07)
        film.sphere(
            f"Star{index}", (x, y, z), (size, size, size),
            star_cool if rng.random() < 0.35 else star_warm, 6, 4,
        )

    lantern = film.lantern((0.10, 2.6, 1.10))
    for key in ("handle", "cap", "glass", "base"):
        lantern[key].scale = (1.6, 1.6, 1.6)
    lantern["light"].data.energy = 22
    lantern["light"].data.color = (0.62, 1.0, 0.30)
    lantern["glass"].data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.4

    lantern_pivot = film.empty("LanternDrift", (0.10, 2.6, 1.10))
    for key in ("handle", "cap", "glass", "base"):
        film.parent_keep(lantern[key], lantern_pivot)
    film.parent_keep(lantern["light"], lantern_pivot)

    film.keyframe(lantern_pivot, "location", 1, (0.25, 2.4, 1.72))
    film.keyframe(lantern_pivot, "location", 90, (0.05, 3.1, 1.80))
    film.keyframe(lantern_pivot, "location", 170, (0.16, 3.8, 1.76))
    film.keyframe(lantern_pivot, "location", 240, (0.02, 4.5, 1.86))
    film.ease(lantern_pivot)

    ember_pivot = film.empty("EmberDrift", (0.10, 2.6, 1.10))
    for index in range(22):
        point = (
            0.10 + rng.uniform(-0.35, 0.35),
            2.35 + rng.uniform(-0.50, 0.95),
            1.62 + rng.uniform(-0.10, 0.45),
        )
        size = rng.uniform(0.003, 0.005)
        mote = film.sphere(f"Ember{index}", point, (size, size, size), ember, 8, 6)
        film.parent_keep(mote, ember_pivot)
    film.keyframe(ember_pivot, "location", 1, (0.13, 2.55, 1.62))
    film.keyframe(ember_pivot, "location", 240, (0.02, 3.55, 1.80))
    film.keyframe(ember_pivot, "rotation_euler", 1, (0.0, 0.0, 0.0))
    film.keyframe(ember_pivot, "rotation_euler", 240, (0.0, 0.0, math.radians(6)))
    film.ease(ember_pivot)

    sun("Moonlight", (-18.0, -9.0, 11.0), (0.0, 7.0, 0.0), energy=1.2, color=(0.74, 0.72, 0.88), angle=0.07)
    film.area_light(
        "MoonRim", (-8.0, 18.0, 9.0), (0.0, 6.0, 0.6),
        energy=150, size=6.0, color=(0.55, 0.68, 1.0),
    )
    film.area_light(
        "LanternPool", (0.35, 2.9, 0.95), (0.1, 3.2, 0.2),
        energy=45, size=1.6, color=(1.0, 0.70, 0.38),
    )
    film.world(scene, color=(0.018, 0.028, 0.062), strength=0.45)
    film.haze(scene, size=(24.0, 30.0, 10.0), center=(0.0, 6.0, 2.0), density=0.0006, color=(0.55, 0.62, 0.85), anisotropy=0.35)

    rig = film.camera(
        (-0.10, -1.20, 1.70), (0.12, 3.0, 1.62),
        lens=42, fstop=2.0,
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (-0.10, -1.20, 1.70))
    film.keyframe(camera, "location", 120, (0.05, -0.20, 1.74))
    film.keyframe(camera, "location", 240, (0.20, 0.75, 1.78))
    film.keyframe(target, "location", 1, (0.12, 3.0, 1.60))
    film.keyframe(target, "location", 120, (0.08, 3.6, 1.68))
    film.keyframe(target, "location", 240, (0.05, 4.2, 1.76))
    film.ease(camera)
    film.ease(target)

    film.pulse(lantern["light"], args.frames_end, base=22.0, amp=3.0, period=64, phase=0.8)
    film.fade(lantern["glass"].data.materials[0], "Emission Strength", [(1, 1.2), (120, 1.6), (240, 1.3)])

    return {"camera": camera, "target": target, "lantern": lantern, "moon": moon}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
