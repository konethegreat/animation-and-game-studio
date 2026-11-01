"""Shared scene kit for The Maker at Work.

Every shot script imports this module, builds its set, then lets run_shot
handle render settings, stills and the animation loop.
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

PROJECT = Path(__file__).resolve().parent
ROOT = PROJECT.parents[1]
PRIVATE = ROOT / "assets" / "private"
FONT = ROOT / "assets" / "repo" / "fonts" / "Fraunces.ttf"
FPS = 24

CREAM = (0.90, 0.84, 0.72)
INK = (0.030, 0.032, 0.038)
BRASS = (0.55, 0.38, 0.16)
WALNUT = (0.20, 0.115, 0.065)
SKIN = (0.30, 0.19, 0.13)


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--frames-start", type=int, default=1)
    parser.add_argument("--frames-end", type=int, default=168)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=800)
    parser.add_argument("--samples", type=int, default=128)
    parser.add_argument("--engine", default="CYCLES")
    parser.add_argument("--device", default="GPU")
    parser.add_argument("--stills", default="")
    parser.add_argument("--stills-dir", default="qa")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--title", default="The Maker at Work")
    return parser.parse_args(argv)


def reset() -> bpy.types.Scene:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def _input(node, names, value):
    for name in names:
        socket = node.inputs.get(name)
        if socket is not None:
            socket.default_value = value
            return
    raise KeyError(f"none of {names} on {node.name}")


def material(
    name: str,
    color: tuple[float, float, float],
    roughness: float = 0.5,
    metallic: float = 0.0,
    emission: tuple[float, float, float] | None = None,
    strength: float = 0.0,
    subsurface: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    _input(bsdf, ["Base Color"], (*color, 1.0))
    _input(bsdf, ["Roughness"], roughness)
    _input(bsdf, ["Metallic"], metallic)
    if subsurface:
        _input(bsdf, ["Subsurface Weight", "Subsurface"], subsurface)
        _input(bsdf, ["Subsurface Radius"], (1.0, 0.35, 0.2))
    if emission:
        _input(bsdf, ["Emission Color", "Emission"], (*emission, 1.0))
        _input(bsdf, ["Emission Strength"], strength)
    return mat


def textured_material(
    name: str,
    image_path: Path,
    emission_strength: float = 0.0,
    roughness: float = 0.55,
    non_color: bool = False,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(image_path), check_existing=True)
    if non_color:
        tex.image.colorspace_settings.name = "Non-Color"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    _input(bsdf, ["Roughness"], roughness)
    if emission_strength:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        _input(bsdf, ["Emission Strength"], emission_strength)
    return mat


def wood_material(name: str, color=WALNUT) -> bpy.types.Material:
    mat = material(name, color, roughness=0.38, metallic=0.0)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 24.0
    noise.inputs["Detail"].default_value = 8.0
    noise.inputs["Roughness"].default_value = 0.62
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0, 0.12, 8.0)
    coord = nodes.new("ShaderNodeTexCoord")
    links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (color[0] * 0.55, color[1] * 0.55, color[2] * 0.55, 1.0)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (*color, 1.0)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.06
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def paper_material(name: str, color=CREAM) -> bpy.types.Material:
    mat = material(name, color, roughness=0.82)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 140.0
    noise.inputs["Detail"].default_value = 4.0
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08
    links.new(noise.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def smooth(obj, angle: float = 35.0) -> None:
    try:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        try:
            bpy.ops.object.shade_smooth()
        except Exception:
            pass
    finally:
        obj.select_set(False)


def _finish(obj, name, mat, smooth_angle=30.0, bevel=0.0):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    smooth(obj, smooth_angle)
    return obj


def box(name, size, location, mat, rotation=(0, 0, 0), bevel=0.002):
    bpy.ops.mesh.primitive_cube_add(size=2, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, name, mat, 20.0, bevel)


def plane(name, size, location, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_plane_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = (size[0], size[1], 1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, name, mat, 20.0)


def cylinder(name, radius, depth, location, mat, rotation=(0, 0, 0), vertices=48, bevel=0.001):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation
    )
    return _finish(bpy.context.object, name, mat, 35.0, bevel)


def cone(name, bottom, top, depth, location, mat, rotation=(0, 0, 0), vertices=64):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=bottom, radius2=top, depth=depth,
        location=location, rotation=rotation,
    )
    return _finish(bpy.context.object, name, mat, 35.0)


def sphere(name, location, scale, mat, segments=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=location
    )
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(obj, name, mat, 40.0)


def track_to(obj, target):
    constraint = obj.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    return constraint


def empty(name, location) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.empty_display_size = 0.05
    obj.location = location
    return obj


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge1 == edge0:
        return 0.0 if value < edge0 else 1.0
    t = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def mix(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def room(scene, width=5.4, depth=4.0, height=2.6, wall_color=(0.155, 0.135, 0.115)):
    wall = material("Wall", wall_color, roughness=0.92)
    floor_mat = wood_material("FloorWood", (0.16, 0.10, 0.07))
    floor = plane("Floor", (width, depth), (0, 0.6, 0), floor_mat)
    back = box("BackWall", (width, 0.06, height), (0, 1.05, height / 2), wall, bevel=0.0)
    left = box("LeftWall", (0.06, depth, height), (-width / 2, 0.6, height / 2), wall, bevel=0.0)
    ceiling = box("Ceiling", (width, depth, 0.04), (0, 0.6, height), wall, bevel=0.0)
    return {"floor": floor, "back": back, "left": left, "ceiling": ceiling}


def desk(origin=(0.0, 0.02, 0.0)):
    top_mat = wood_material("DeskWalnut", (0.22, 0.125, 0.07))
    wood = wood_material("DeskLegs", (0.14, 0.08, 0.05))
    ox, oy, oz = origin
    top = box("DeskTop", (1.72, 0.80, 0.045), (ox, oy, 0.78 + oz), top_mat, bevel=0.008)
    legs = []
    for sx in (-0.78, 0.78):
        for sy in (-0.32, 0.32):
            legs.append(box("DeskLeg", (0.05, 0.05, 0.76), (ox + sx, oy + sy, 0.38 + oz), wood, bevel=0.003))
    return {"top": top, "legs": legs}


def chair(location=(0.18, 0.52, 0.0), yaw: float = 0.0):
    fabric = material("ChairFabric", (0.10, 0.085, 0.08), roughness=0.88)
    frame = wood_material("ChairFrame", (0.12, 0.07, 0.045))
    x, y, z = location
    root = empty("Chair", (x, y, z))
    root.rotation_euler = (0.0, 0.0, math.radians(yaw))
    seat = box("ChairSeat", (0.48, 0.46, 0.06), (x, y, 0.45 + z), fabric, bevel=0.02)
    back = box("ChairBack", (0.46, 0.06, 0.56), (x, y + 0.24, 0.78 + z), fabric, bevel=0.02)
    parts = [seat, back]
    for sx in (-0.2, 0.2):
        for sy in (-0.18, 0.18):
            parts.append(box("ChairLeg", (0.035, 0.035, 0.44), (x + sx, y + sy, 0.22 + z), frame, bevel=0.002))
    for part in parts:
        parent_keep(part, root)
    return {"root": root, "seat": seat, "back": back}


def lamp(location=(0.56, 0.12, 0.78)):
    x, y, z = location
    brass = material("Brass", BRASS, roughness=0.28, metallic=0.9)
    shade_inside = material("ShadeInner", (0.95, 0.80, 0.58), roughness=0.55, emission=(1.0, 0.62, 0.32), strength=0.35)
    base = cylinder("LampBase", 0.075, 0.022, (x, y, z + 0.011), brass)
    stem = cylinder("LampStem", 0.011, 0.40, (x, y, z + 0.22), brass)
    elbow = sphere("LampElbow", (x, y, z + 0.42), (0.022, 0.022, 0.022), brass, 24, 12)
    arm = cylinder("LampArm", 0.011, 0.20, (x - 0.08, y - 0.03, z + 0.45), brass, rotation=(0.0, math.radians(64), 0.0))
    shade = cone("LampShade", 0.155, 0.045, 0.15, (x - 0.17, y - 0.05, z + 0.38), brass)
    inner = cone("LampShadeInner", 0.148, 0.042, 0.14, (x - 0.17, y - 0.05, z + 0.375), shade_inside)
    bulb = sphere("Bulb", (x - 0.17, y - 0.05, z + 0.315), (0.034, 0.034, 0.038), material("Bulb", (1.0, 0.86, 0.62), roughness=0.2, emission=(1.0, 0.66, 0.36), strength=18.0), 24, 12)
    data = bpy.data.lights.new("Practical", type="POINT")
    data.energy = 42
    data.color = (1.0, 0.66, 0.38)
    data.shadow_soft_size = 0.06
    practical = bpy.data.objects.new("Practical", data)
    bpy.context.scene.collection.objects.link(practical)
    practical.location = (x - 0.17, y - 0.05, z + 0.31)
    return {"base": base, "shade": shade, "inner": inner, "bulb": bulb, "light": practical, "stem": stem, "arm": arm, "elbow": elbow}


def portrait_print() -> Path:
    # portrait.py grades the full photograph for the desk print so it sits in
    # the same warm world as the film; the raw source is the fallback.
    graded = PRIVATE / "portrait_graded.png"
    return graded if graded.exists() else PRIVATE / "portrait.png"


def portrait_frame(location=(-0.52, 0.12, 0.79), size=(0.34, 0.44), tilt=12.0):
    x, y, z = location
    pivot = empty("PortraitPivot", (x, y, z))
    pivot.rotation_euler = (math.radians(tilt), 0, 0)
    brass = material("FrameBrass", (0.36, 0.25, 0.12), roughness=0.35, metallic=0.75)
    w, h = size
    border = 0.018
    box("FrameLeft", (border, 0.014, h), (-w / 2 + border / 2, 0, h / 2), brass, bevel=0.002).parent = pivot
    box("FrameRight", (border, 0.014, h), (w / 2 - border / 2, 0, h / 2), brass, bevel=0.002).parent = pivot
    box("FrameTop", (w, 0.014, border), (0, 0, h - border / 2), brass, bevel=0.002).parent = pivot
    box("FrameBottom", (w, 0.014, border), (0, 0, border / 2), brass, bevel=0.002).parent = pivot
    photo = plane(
        "PortraitPhoto", (w - border * 2, h - border * 2), (0, -0.002, h / 2),
        textured_material("PortraitPhotoMat", portrait_print(), emission_strength=0.15, roughness=0.62),
        rotation=(math.radians(90), 0, 0),
    )
    photo.parent = pivot
    glass = plane(
        "PortraitGlass", (w - border * 2 - 0.004, h - border * 2 - 0.004), (0, -0.004, h / 2),
        material("Glass", (0.9, 0.92, 0.95), roughness=0.02), rotation=(math.radians(90), 0, 0),
    )
    glass.parent = pivot
    _input(glass.data.materials[0].node_tree.nodes["Principled BSDF"], ["Transmission Weight", "Transmission"], 1.0)
    _input(glass.data.materials[0].node_tree.nodes["Principled BSDF"], ["IOR"], 1.45)

    foot = box("FrameFoot", (w * 0.55, 0.05, 0.014), (0, 0.028, 0.007), brass, bevel=0.002)
    foot.parent = pivot
    for side in (-1, 1):
        leg = box("FrameStand", (0.012, 0.05, 0.09), (side * w * 0.22, 0.055, 0.045), brass, bevel=0.001)
        leg.parent = pivot
    return {"pivot": pivot, "photo": photo, "glass": glass, "foot": foot, "w": w, "h": h}


def sketchbook(location=(0.02, -0.10, 0.805)):
    cover = material("BookCover", (0.09, 0.06, 0.05), roughness=0.7)
    page = paper_material("BookPage", (0.94, 0.90, 0.80))
    ink = material("Pencil", (0.20, 0.19, 0.17), roughness=0.9)
    x, y, z = location
    box("BookCoverGeo", (0.46, 0.32, 0.012), (x, y, z - 0.012), cover, bevel=0.003)
    left = plane("PageLeft", (0.215, 0.30), (x - 0.112, y, z + 0.001), page, rotation=(0, math.radians(-2.5), 0))
    right = plane("PageRight", (0.215, 0.30), (x + 0.112, y, z + 0.001), page, rotation=(0, math.radians(2.5), 0))
    strokes = []
    rng = random.Random(11)
    for index in range(14):
        base_x = x + rng.uniform(-0.19, 0.19)
        base_y = y + rng.uniform(-0.12, 0.12)
        length = rng.uniform(0.04, 0.14)
        angle = rng.uniform(-0.9, 0.9)
        curve = bpy.data.curves.new(f"Stroke{index}", type="CURVE")
        curve.dimensions = "3D"
        curve.bevel_depth = 0.0007
        curve.bevel_resolution = 1
        spline = curve.splines.new("BEZIER")
        spline.bezier_points.add(2)
        for point_index, t in enumerate((0.0, 0.5, 1.0)):
            point = spline.bezier_points[point_index]
            point.co = (
                base_x + math.cos(angle) * length * (t - 0.5),
                base_y + math.sin(angle) * length * (t - 0.5) + math.sin(t * math.pi) * 0.008,
                z + 0.0025,
            )
            point.handle_left_type = "AUTO"
            point.handle_right_type = "AUTO"
        obj = bpy.data.objects.new(f"Stroke{index}", curve)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(ink)
        strokes.append(obj)
    return {"left": left, "right": right, "strokes": strokes}


def mug(location=(0.34, -0.20, 0.80)):
    ceramic = material("Ceramic", (0.58, 0.52, 0.43), roughness=0.32)
    x, y, z = location
    body = cylinder("Mug", 0.045, 0.095, (x, y, z + 0.047), ceramic, bevel=0.003)
    handle = bpy.ops.mesh.primitive_torus_add(
        major_radius=0.032, minor_radius=0.009, major_segments=32, minor_segments=8,
        location=(x + 0.05, y, z + 0.055), rotation=(math.radians(90), 0, 0),
    )
    handle_obj = bpy.context.object
    _finish(handle_obj, "MugHandle", ceramic, 40.0)
    return {"body": body, "handle": handle_obj}


def dust(scene, count=70, center=(0.0, 0.0, 1.05), spread=(1.5, 0.8, 0.9), seed=5):
    rng = random.Random(seed)
    grain = material("DustGrain", (1.0, 0.88, 0.68), roughness=1.0, emission=(1.0, 0.85, 0.62), strength=0.9)
    pivot = empty("Dust", center)
    for index in range(count):
        point = (
            rng.uniform(-spread[0] / 2, spread[0] / 2),
            rng.uniform(-spread[1] / 2, spread[1] / 2),
            rng.uniform(-spread[2] / 2, spread[2] / 2),
        )
        radius = rng.uniform(0.0009, 0.0024)
        mote = sphere(f"Dust{index}", point, (radius, radius, radius), grain, 8, 6)
        mote.parent = pivot
    return pivot


def parent_keep(obj, pivot) -> None:
    obj.parent = pivot
    obj.matrix_parent_inverse = pivot.matrix_world.inverted()


def seated_double(location=(0.18, 0.56, 0.0), yaw: float = 0.0):
    sweater = material("Sweater", (0.055, 0.06, 0.075), roughness=0.86)
    skin = material("Skin", SKIN, roughness=0.52, subsurface=0.035)
    beard = material("Beard", (0.035, 0.028, 0.024), roughness=0.92)
    hair = material("Hair", (0.025, 0.020, 0.018), roughness=0.78)
    x, y, z = location
    root = empty("Maker", (x, y, z))
    root.rotation_euler = (0.0, 0.0, math.radians(yaw))
    torso = sphere("MakerTorso", (0, 0, 0.97), (0.215, 0.165, 0.245), sweater, 64, 32)
    torso.parent = root
    chest = sphere("MakerChest", (0, -0.085, 1.06), (0.18, 0.115, 0.14), sweater, 48, 24)
    chest.parent = root
    neck = cylinder("MakerNeck", 0.058, 0.12, (0, -0.03, 1.215), skin, vertices=24)
    neck.parent = root

    look = empty("MakerLook", (0, -0.03, 1.25))
    look.parent = root
    head = sphere("MakerHead", (0, -0.04, 1.32), (0.112, 0.118, 0.132), skin, 64, 40)
    parent_keep(head, look)
    cap = sphere("MakerHair", (0, -0.012, 1.332), (0.118, 0.112, 0.132), hair, 48, 28)
    parent_keep(cap, look)
    for side in (-1, 1):
        ear = sphere(f"MakerEar{side}", (side * 0.108, -0.03, 1.30), (0.024, 0.030, 0.042), skin, 24, 16)
        parent_keep(ear, look)
    jaw = sphere("MakerJaw", (0, -0.102, 1.255), (0.083, 0.062, 0.062), beard, 32, 20)
    parent_keep(jaw, look)
    for side in (-1, 1):
        shoulder = sphere(f"MakerShoulder{side}", (side * 0.195, -0.02, 1.08), (0.075, 0.08, 0.08), sweater, 32, 16)
        shoulder.parent = root
        upper = cylinder(
            f"MakerUpperArm{side}", 0.048, 0.28, (side * 0.225, -0.06, 1.00), sweater,
            rotation=(math.radians(14), math.radians(side * 10), 0), vertices=24,
        )
        upper.parent = root
        fore = cylinder(
            f"MakerForearm{side}", 0.040, 0.24, (side * 0.255, -0.20, 0.90), sweater,
            rotation=(math.radians(72), 0, math.radians(side * -6)), vertices=24,
        )
        fore.parent = root
        hand = sphere(f"MakerHand{side}", (side * 0.235, -0.32, 0.845), (0.042, 0.058, 0.032), skin, 24, 16)
        hand.parent = root
    return {"root": root, "look": look, "head": head, "neck": neck, "torso": torso}


def lantern(location=(0.30, -0.24, 0.80)):
    x, y, z = location
    brass = material("LanternBrass", (0.30, 0.22, 0.10), roughness=0.32, metallic=0.85)
    lime = material("LanternLime", (0.55, 1.0, 0.12), roughness=0.3, emission=(0.55, 1.0, 0.12), strength=3.0)
    ring = bpy.ops.mesh.primitive_torus_add(
        major_radius=0.075, minor_radius=0.008, major_segments=48, minor_segments=10,
        location=(x, y, z + 0.24), rotation=(math.radians(90), 0, 0),
    )
    handle = _finish(bpy.context.object, "LanternHandle", brass, 40.0)
    cap = cylinder("LanternCap", 0.062, 0.026, (x, y, z + 0.20), brass, vertices=32)
    glass = cylinder("LanternGlass", 0.055, 0.13, (x, y, z + 0.12), lime, vertices=32)
    base = cylinder("LanternBase", 0.065, 0.026, (x, y, z + 0.045), brass, vertices=32)
    data = bpy.data.lights.new("LanternGlow", type="POINT")
    data.energy = 6
    data.color = (0.62, 1.0, 0.30)
    data.shadow_soft_size = 0.05
    light = bpy.data.objects.new("LanternGlow", data)
    bpy.context.scene.collection.objects.link(light)
    light.location = (x, y, z + 0.12)
    return {"handle": handle, "cap": cap, "glass": glass, "base": base, "light": light}


def camera(location, target, lens=40, fstop=2.2, focus=None):
    scene = bpy.context.scene
    target_obj = empty("CameraTarget", target)
    data = bpy.data.cameras.new("Camera")
    obj = bpy.data.objects.new("Camera", data)
    scene.collection.objects.link(obj)
    data.lens = lens
    data.sensor_width = 36
    data.dof.use_dof = True
    data.dof.aperture_fstop = fstop
    data.dof.focus_object = focus if focus is not None else target_obj
    obj.location = location
    track_to(obj, target_obj)
    scene.camera = obj
    return {"camera": obj, "target": target_obj}


def area_light(name, location, target, energy, size, color):
    data = bpy.data.lights.new(name, type="AREA")
    data.energy = energy
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    if isinstance(target, bpy.types.Object):
        track_to(obj, target)
    else:
        aim = Vector(target) - Vector(location)
        obj.rotation_mode = "QUATERNION"
        obj.rotation_quaternion = aim.to_track_quat("-Z", "Y")
    return obj


def world(scene, color=(0.012, 0.014, 0.020), strength=0.35):
    data = bpy.data.worlds.new("NightWorld")
    scene.world = data
    data.use_nodes = True
    background = data.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (*color, 1.0)
    background.inputs[1].default_value = strength


def title_text(body: str, location, size=0.12, color=(0.93, 0.87, 0.74), strength=1.4):
    curve = bpy.data.curves.new("TitleCurve", type="FONT")
    curve.body = body
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    if FONT.exists():
        curve.font = bpy.data.fonts.load(str(FONT), check_existing=True)
    obj = bpy.data.objects.new("Title", curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (math.radians(90), 0, 0)
    mat = material("TitleCream", color, roughness=0.4, emission=color, strength=strength)
    obj.data.materials.append(mat)
    return obj


def keyframe(obj, path, frame, value):
    if "." in path:
        head, tail = path.split(".", 1)
        target = getattr(obj, head)
    else:
        target = obj
        tail = path
    setattr(target, tail, value)
    obj.keyframe_insert(data_path=path, frame=frame)


def ease(obj) -> None:
    data = getattr(obj, "animation_data", None)
    action = data.action if data else None
    if action is None:
        return
    curves = list(getattr(action, "fcurves", []))
    if not curves:
        for layer in getattr(action, "layers", []):
            for strip in layer.strips:
                for bag in getattr(strip, "channelbags", []):
                    curves.extend(bag.fcurves)
    for fcurve in curves:
        for point in fcurve.keyframe_points:
            point.interpolation = "BEZIER"
            point.handle_left_type = "AUTO_CLAMPED"
            point.handle_right_type = "AUTO_CLAMPED"


def pulse(light, frames: int, base: float, amp: float, period: float, phase: float = 0.0, step: int = 6):
    for frame in range(1, frames + 1, step):
        value = base + amp * math.sin(2 * math.pi * frame / period + phase)
        keyframe(light.data, "energy", frame, max(0.0, value))


def fade(mat, socket: str, points: list[tuple[int, float]]) -> None:
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    node = bsdf.inputs[socket]
    for frame, value in points:
        node.default_value = value
        node.keyframe_insert("default_value", frame=frame)


def haze(
    scene,
    size=(5.0, 6.0, 3.0),
    center=(0.0, 0.4, 1.3),
    density: float = 0.008,
    color=(1.0, 0.84, 0.64),
    anisotropy: float = 0.35,
):
    mat = bpy.data.materials.new("Haze")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    volume = nodes.new("ShaderNodeVolumePrincipled")
    _input(volume, ["Color"], (*color, 1.0))
    _input(volume, ["Density"], density)
    _input(volume, ["Anisotropy"], anisotropy)
    links.new(volume.outputs["Volume"], output.inputs["Volume"])
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = "Haze"
    obj.scale = size
    obj.data.materials.append(mat)
    return obj


def setup_render(scene, args) -> None:
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = args.frames_end
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.use_persistent_data = True
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        scene.view_settings.view_transform = "Filmic"
    scene.view_settings.exposure = -0.15

    if args.engine.upper().startswith("CYCLES"):
        scene.render.engine = "CYCLES"
        scene.cycles.samples = args.samples
        scene.cycles.use_denoising = True
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
        scene.cycles.use_adaptive_sampling = True
        scene.cycles.adaptive_threshold = 0.015
        scene.cycles.max_bounces = 8
        scene.cycles.diffuse_bounces = 4
        scene.cycles.glossy_bounces = 5
        scene.cycles.transmission_bounces = 8
        scene.cycles.volume_bounces = 1
        if args.device.upper() == "GPU":
            prefs = bpy.context.preferences.addons["cycles"].preferences
            prefs.compute_device_type = "OPTIX"
            prefs.get_devices()
            for device in prefs.devices:
                device.use = device.type == "OPTIX"
            scene.cycles.device = "GPU"
        else:
            scene.cycles.device = "CPU"
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        try:
            scene.eevee.taa_render_samples = args.samples
        except Exception:
            pass


def run_shot(args, build) -> None:
    scene = reset()
    rig = build(scene, args)
    setup_render(scene, args)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    print(
        f"CHECK meshes={len(meshes)} lights={len(lights)} "
        f"camera={scene.camera.name} frames={scene.frame_end} "
        f"engine={scene.render.engine} {args.width}x{args.height}"
    )
    if args.check:
        return

    if args.stills:
        out = Path(args.stills_dir).resolve()
        out.mkdir(parents=True, exist_ok=True)
        for raw in args.stills.split(","):
            frame = int(raw.strip())
            if not frame:
                continue
            scene.frame_set(frame)
            scene.render.filepath = str(out / f"qa_{frame:04d}.png")
            bpy.ops.render.render(write_still=True)
            print(f"STILL {frame} -> {scene.render.filepath}")
        return

    if not args.out:
        raise SystemExit("--out is required unless --check or --stills is used")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    scene.frame_start = args.frames_start
    scene.frame_end = args.frames_end
    scene.render.filepath = str(out / "frame_")
    bpy.ops.render.render(animation=True)
    print(f"RENDERED {args.frames_end - args.frames_start + 1} frames to {out}")
    _ = rig
