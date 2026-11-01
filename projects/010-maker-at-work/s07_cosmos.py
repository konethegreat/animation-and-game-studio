"""Shot 07: the cosmic library, where the lantern becomes a star.

Shelves drift in a slow orbit over a dark field, lit by a single small sun.
The lantern rises past them, and by the end the lamp has become the light
that stays.
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy

import film_common as film

PAPER = (0.90, 0.86, 0.76)
CREAM = (0.97, 0.93, 0.84)
OLIVE = (0.50, 0.52, 0.32)
TERRACOTTA = (0.66, 0.30, 0.15)
INK = (0.06, 0.06, 0.07)
LIME = (0.62, 1.0, 0.18)


def book(name, location, size, yaw, tilt, cover, pages, ink):
    film.box(f"{name}Cover", size, location, cover, rotation=(tilt, 0, yaw), bevel=0.002)
    film.box(
        f"{name}Pages", (size[0] * 0.93, size[1] * 0.94, size[2] * 0.62),
        location, pages, rotation=(tilt, 0, yaw), bevel=0.001,
    )
    film.box(
        f"{name}Spine", (size[0] * 0.05, size[1] * 1.01, size[2] * 1.02),
        (location[0] - size[0] * 0.475, location[1], location[2]), ink,
        rotation=(tilt, 0, yaw), bevel=0.0,
    )


def glow_plane(name, location, size, color):
    """A camera facing disc whose glow falls off to nothing at the rim."""
    mat = bpy.data.materials.new(f"{name}Mat")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    emission.name = "Emission"
    emission.inputs["Color"].default_value = (*color, 1.0)
    emission.inputs["Strength"].default_value = 0.0

    coords = nodes.new("ShaderNodeTexCoord")
    offset = nodes.new("ShaderNodeVectorMath")
    offset.operation = "SUBTRACT"
    offset.inputs[1].default_value = (0.5, 0.5, 0.0)
    length = nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    falloff = nodes.new("ShaderNodeMapRange")
    falloff.inputs["From Min"].default_value = 0.0
    falloff.inputs["From Max"].default_value = 0.5
    falloff.inputs["To Min"].default_value = 1.0
    falloff.inputs["To Max"].default_value = 0.0
    falloff.clamp = True

    links.new(coords.outputs["UV"], offset.inputs[0])
    links.new(offset.outputs["Vector"], length.inputs[0])
    links.new(length.outputs["Value"], falloff.inputs["Value"])
    links.new(falloff.outputs["Result"], mix.inputs["Fac"])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(emission.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], output.inputs["Surface"])

    bpy.ops.mesh.primitive_plane_add(size=size, location=location, rotation=(math.radians(111), 0, 0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def build(scene, args):
    rng = random.Random(87)
    paper = film.paper_material("CosmicPaper", PAPER)
    cream = film.paper_material("CosmicCream", CREAM)
    olive = film.material("CosmicOlive", OLIVE, roughness=0.82)
    terracotta = film.material("CosmicTerracotta", TERRACOTTA, roughness=0.82)
    ink = film.material("CosmicInk", INK, roughness=0.9)
    board = film.material("ShelfBoard", (0.16, 0.13, 0.11), roughness=0.88)
    star_cool = film.material("CosmicStarCool", (0.80, 0.86, 1.0), roughness=1.0, emission=(0.78, 0.86, 1.0), strength=3.4)
    star_warm = film.material("CosmicStarWarm", (1.0, 0.90, 0.76), roughness=1.0, emission=(1.0, 0.88, 0.72), strength=2.4)

    for index in range(150):
        azimuth = rng.uniform(-1.35, 1.35)
        radius = rng.uniform(26.0, 38.0)
        x = math.sin(azimuth) * radius
        y = 12.0 + math.cos(azimuth) * radius
        z = rng.uniform(2.0, 24.0)
        size = rng.uniform(0.05, 0.16)
        film.sphere(
            f"Star{index}", (x, y, z), (size, size, size),
            star_cool if rng.random() < 0.45 else star_warm, 6, 4,
        )

    covers = (olive, terracotta, paper, olive, cream)
    field = film.empty("BookField", (0.0, 5.0, 2.0))
    shelves = (((0.0, 4.3, 1.30), 16.0), ((0.8, 6.6, 2.45), -13.0), ((-0.8, 8.8, 3.35), 23.0))
    for index, (location, yaw) in enumerate(shelves):
        board_obj = film.box(
            f"Shelf{index}", (2.25, 0.32, 0.05), location, board,
            rotation=(math.radians(6), 0, math.radians(yaw)), bevel=0.003,
        )
        for slot in range(5):
            offset = (slot - 2) * 0.24
            angle = math.radians(yaw)
            bx = location[0] + math.cos(angle) * offset
            by = location[1] + math.sin(angle) * offset
            height = rng.uniform(0.20, 0.28)
            name = f"ShelfBook{index}_{slot}"
            book(
                name, (bx, by, location[2] + height / 2 + 0.05),
                (0.060, rng.uniform(0.16, 0.20), height),
                angle + math.radians(rng.uniform(-4, 4)), 0.0,
                covers[(index * 5 + slot) % len(covers)], cream, ink,
            )
            cover = bpy.data.objects[f"{name}Cover"]
            for part in ("Pages", "Spine"):
                film.parent_keep(bpy.data.objects[f"{name}{part}"], cover)
            film.parent_keep(cover, board_obj)
        film.parent_keep(board_obj, field)

    film.keyframe(field, "rotation_euler", 1, (0.0, 0.0, math.radians(-1.5)))
    film.keyframe(field, "rotation_euler", 240, (0.0, 0.0, math.radians(1.5)))

    for index in range(7):
        angle = rng.uniform(-1.1, 1.1)
        radius = rng.uniform(1.4, 4.0)
        x = math.sin(angle) * radius
        y = 5.0 + math.cos(angle) * radius * 1.3
        z = rng.uniform(0.9, 4.6)
        size = (rng.uniform(0.28, 0.46), rng.uniform(0.20, 0.32), rng.uniform(0.05, 0.09))
        name = f"Book{index}"
        book(name, (x, y, z), size, math.radians(rng.uniform(0, 360)), math.radians(rng.uniform(-30, 30)),
             covers[index % len(covers)], cream, ink)
        cover = bpy.data.objects[f"{name}Cover"]
        for part in ("Pages", "Spine"):
            film.parent_keep(bpy.data.objects[f"{name}{part}"], cover)
        film.parent_keep(cover, field)
        base = cover.rotation_euler.copy()
        film.keyframe(cover, "rotation_euler", 1, base)
        film.keyframe(cover, "rotation_euler", 240, (
            base.x + math.radians(rng.uniform(10, 30)),
            base.y + math.radians(rng.uniform(-14, 14)),
            base.z + math.radians(rng.uniform(6, 18)),
        ))
        film.ease(cover)

    pages = []
    page_mat = film.paper_material("CosmicPage", (0.96, 0.92, 0.82))
    for index in range(16):
        obj = film.plane(
            f"FreePage{index}", (rng.uniform(0.07, 0.15), rng.uniform(0.09, 0.18)),
            (rng.uniform(-2.6, 2.6), rng.uniform(1.0, 12.0), rng.uniform(0.6, 5.2)),
            page_mat, rotation=(math.radians(rng.uniform(20, 160)), math.radians(rng.uniform(-40, 40)), math.radians(rng.uniform(0, 360))),
        )
        film.parent_keep(obj, field)
        pages.append(obj)

    lantern = film.lantern((0.0, 3.4, 1.30))
    for key in ("handle", "cap", "glass", "base"):
        lantern[key].scale = (2.0, 2.0, 2.0)
    lantern["light"].data.energy = 30
    lantern["light"].data.color = (0.66, 1.0, 0.34)
    lantern["glass"].data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.8

    lantern_pivot = film.empty("LanternRise", (0.0, 3.4, 1.30))
    for key in ("handle", "cap", "glass", "base", "light"):
        film.parent_keep(lantern[key], lantern_pivot)
    film.keyframe(lantern_pivot, "location", 1, (0.05, 3.0, 1.35))
    film.keyframe(lantern_pivot, "location", 120, (0.02, 4.8, 2.60))
    film.keyframe(lantern_pivot, "location", 210, (0.00, 6.5, 3.75))
    film.keyframe(lantern_pivot, "location", 240, (0.00, 7.0, 4.05))
    film.ease(lantern_pivot)

    new_star = film.sphere(
        "NewStar", (0.0, 7.4, 5.15), (0.5, 0.5, 0.5),
        film.material("NewStarFace", (1.0, 0.96, 0.82), roughness=0.5, emission=(1.0, 0.94, 0.78), strength=0.0),
        32, 16,
    )
    material = new_star.data.materials[0]
    film.fade(material, "Emission Strength", [(1, 0.0), (170, 0.0), (232, 12.0)])

    halo = glow_plane("NewStarHalo", (0.0, 7.55, 5.15), 1.1, (1.0, 0.90, 0.72))
    emission = halo.data.materials[0].node_tree.nodes["Emission"]
    for frame, value in ((1, 0.0), (176, 0.0), (236, 2.6)):
        emission.inputs["Strength"].default_value = value
        emission.inputs["Strength"].keyframe_insert("default_value", frame=frame)

    spikes = (
        ("NewStarSpikeH", (0.0, 7.52, 5.15), (2.4, 0.075, 1.0)),
        ("NewStarSpikeV", (0.0, 7.52, 5.15), (0.075, 2.4, 1.0)),
    )
    for name, location, scale in spikes:
        spike = glow_plane(name, location, 1.0, (1.0, 0.92, 0.76))
        spike.scale = scale
        node = spike.data.materials[0].node_tree.nodes["Emission"]
        for frame, value in ((1, 0.0), (176, 0.0), (236, 1.8)):
            node.inputs["Strength"].default_value = value
            node.inputs["Strength"].keyframe_insert("default_value", frame=frame)
    film.keyframe(new_star, "scale", 1, (0.10, 0.10, 0.10))
    film.keyframe(new_star, "scale", 170, (0.16, 0.16, 0.16))
    film.keyframe(new_star, "scale", 232, (0.34, 0.34, 0.34))
    film.ease(new_star)

    film.keyframe(field, "location", 1, (0.0, 5.0, 2.0))
    film.keyframe(field, "location", 240, (0.0, 5.2, 2.2))
    film.ease(field)

    for index, obj in enumerate(pages):
        start = obj.location.copy()
        film.keyframe(obj, "location", 1, start)
        film.keyframe(obj, "location", 240, (
            start.x + rng.uniform(-0.6, 0.6), start.y + rng.uniform(0.2, 1.0), start.z + rng.uniform(-0.4, 0.8),
        ))
        film.keyframe(obj, "rotation_euler", 1, tuple(obj.rotation_euler))
        film.keyframe(obj, "rotation_euler", 240, (
            obj.rotation_euler.x + math.radians(rng.uniform(80, 200)),
            obj.rotation_euler.y + math.radians(rng.uniform(40, 120)),
            obj.rotation_euler.z + math.radians(rng.uniform(60, 180)),
        ))
        film.ease(obj)

    film.area_light(
        "CosmicKey", (-4.0, -3.0, 6.0), (0.0, 5.0, 2.4),
        energy=200, size=4.0, color=(0.62, 0.72, 1.0),
    )
    film.area_light(
        "CosmicFill", (0.0, -0.8, 0.6), (0.0, 5.0, 2.6),
        energy=120, size=5.0, color=(1.0, 0.84, 0.66),
    )
    film.area_light(
        "NebulaGlow", (-1.0, 25.0, 9.0), (0.0, 5.0, 2.4),
        energy=260, size=10.0, color=(0.34, 0.44, 0.90),
    )
    film.area_light(
        "ShelfUnder", (0.0, 5.0, 0.0), (0.0, 5.0, 2.0),
        energy=130, size=4.0, color=(1.0, 0.88, 0.72),
    )
    film.area_light(
        "CosmicRim", (4.0, 12.0, 5.0), (0.0, 5.0, 2.0),
        energy=100, size=3.0, color=(1.0, 0.72, 0.44),
    )
    film.world(scene, color=(0.020, 0.028, 0.068), strength=0.55)
    film.haze(scene, size=(20.0, 26.0, 12.0), center=(0.0, 6.0, 3.0), density=0.0012, color=(0.30, 0.38, 0.72), anisotropy=0.5)

    rig = film.camera(
        (-0.30, -3.40, 0.82), (0.10, 5.0, 2.90),
        lens=30, fstop=2.8,
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (-0.30, -3.40, 0.82))
    film.keyframe(camera, "location", 120, (-0.10, -2.10, 0.95))
    film.keyframe(camera, "location", 240, (0.10, -0.75, 1.12))
    film.keyframe(target, "location", 1, (0.10, 5.0, 2.90))
    film.keyframe(target, "location", 120, (0.06, 5.6, 3.35))
    film.keyframe(target, "location", 240, (0.02, 6.4, 3.90))
    film.ease(camera)
    film.ease(target)

    film.pulse(lantern["light"], args.frames_end, base=30.0, amp=4.0, period=80, phase=0.4)
    film.fade(lantern["glass"].data.materials[0], "Emission Strength", [(1, 1.6), (120, 2.2), (180, 1.7), (232, 0.0)])

    return {"camera": camera, "target": target, "lantern": lantern, "star": new_star}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
