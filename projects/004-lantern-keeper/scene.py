"""The Lantern Keeper: a rigged humanoid walks a paper bridge to a waking city.

Usage (after --):
  --out DIR --frames-start 1 --frames-end 144 --width 1920 --height 1080
  --stills 1,48,96,132 --stills-dir qa
  --check
  --export-glb PATH
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

FPS = 24
FILM_FRAMES = 144
WALK_END = 96
LIFT_START = 104
LIFT_END = 128
WAKE_START = 110
WAKE_END = 140
START_Y = 4.2
WALK_DISTANCE = 3.2
STEPS = 6

CAMERA_KEYS = [
    (1, (4.6, 9.0, 1.80)),
    (48, (4.1, 7.7, 2.20)),
    (96, (3.4, 6.2, 2.50)),
    (120, (3.0, 5.5, 2.72)),
    (144, (2.85, 5.15, 2.86)),
]

TARGET_KEYS = [
    (1, (0.0, 4.1, 1.15)),
    (48, (0.0, 3.0, 1.30)),
    (96, (0.0, 1.5, 1.45)),
    (120, (0.05, 1.0, 1.65)),
    (144, (0.10, 0.95, 1.76)),
]


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--frames-start", type=int, default=1)
    parser.add_argument("--frames-end", type=int, default=FILM_FRAMES)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--stills", default="")
    parser.add_argument("--stills-dir", default="qa")
    parser.add_argument("--samples", type=int, default=48)
    parser.add_argument("--export-glb", default="")
    parser.add_argument("--engine", default="EEVEE")
    return parser.parse_args(argv)


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------


def material(name, color, roughness=0.55, metallic=0.0, emission=None, strength=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if socket:
            socket.default_value = (*emission, 1.0)
        strength_socket = bsdf.inputs.get("Emission Strength")
        if strength_socket:
            strength_socket.default_value = strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except AttributeError:
            mat.blend_method = "BLEND"
        try:
            mat.use_transparent_shadow = False
        except AttributeError:
            pass
    return mat


def smooth(obj, angle=35.0):
    try:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        bpy.ops.object.shade_smooth()
    finally:
        obj.select_set(False)


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_transform(obj):
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge1 == edge0:
        return 0.0 if value < edge0 else 1.0
    t = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def catmull(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    return tuple(
        0.5
        * (
            2.0 * b
            + (-a + c) * t
            + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2
            + (-a + 3.0 * b - 3.0 * c + d) * t3
        )
        for a, b, c, d in zip(p0, p1, p2, p3)
    )


def spline_sample(keys, frame: float):
    if frame <= keys[0][0]:
        return keys[0][1]
    if frame >= keys[-1][0]:
        return keys[-1][1]
    for index in range(len(keys) - 1):
        fa, va = keys[index]
        fb, vb = keys[index + 1]
        if fa <= frame <= fb:
            before = keys[max(0, index - 1)][1]
            after = keys[min(len(keys) - 1, index + 2)][1]
            t = (frame - fa) / (fb - fa)
            return catmull(before, va, vb, after, t)
    return keys[-1][1]


def deck_z(y: float) -> float:
    return 0.16 + 0.34 * max(0.0, math.cos(math.pi * y / 12.0))


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def pose_world_rotation(arm, name: str) -> Quaternion:
    chain = []
    bone = arm.data.bones[name]
    while bone is not None:
        chain.append(bone)
        bone = bone.parent
    world = Quaternion()
    previous = None
    for bone in reversed(chain):
        rest = bone.matrix_local.to_quaternion()
        relative = rest if previous is None else previous.inverted() @ rest
        world = world @ relative @ arm.pose.bones[bone.name].rotation_euler.to_quaternion()
        previous = rest
    return world


def hang_lantern(arm, swing: float = 0.0) -> None:
    hand = pose_world_rotation(arm, "hand_L")
    hand_rest = arm.data.bones["hand_L"].matrix_local.to_quaternion()
    lantern_rest = arm.data.bones["lantern"].matrix_local.to_quaternion()
    base = hand @ (hand_rest.inverted() @ lantern_rest)
    target = Vector((0.09 * swing, -0.04, -1.0)).normalized()
    local = Vector((0.0, 1.0, 0.0)).rotation_difference(base.inverted() @ target)
    arm.pose.bones["lantern"].rotation_euler = local.to_euler("XYZ")


def aim_bone(arm, name: str, direction) -> Quaternion:
    rest = arm.data.bones[name].matrix_local.to_3x3()
    local = rest.inverted() @ Vector(direction).normalized()
    return Vector((0.0, 1.0, 0.0)).rotation_difference(local)


# ---------------------------------------------------------------------------
# Meshes
# ---------------------------------------------------------------------------


def bind(obj, name, mat, weights, angle=35.0):
    obj.name = name
    apply_transform(obj)
    if mat:
        obj.data.materials.append(mat)
    smooth(obj, angle)
    if weights is None:
        return obj
    if callable(weights):
        weights(obj)
    else:
        for bone, weight in weights.items():
            group = obj.vertex_groups.new(name=bone)
            group.add(list(range(len(obj.data.vertices))), weight, "REPLACE")
    obj.parent = ARM
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = ARM
    obj["keeper"] = True
    return obj


def sphere(name, location, scale, mat, bone, segments=32, rings=16, rotation=None, weights=None):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=location
    )
    obj = bpy.context.object
    obj.scale = scale
    if rotation:
        obj.rotation_euler = rotation
    resolved = weights if weights is not None else ({bone: 1.0} if bone else None)
    return bind(obj, name, mat, resolved)


def box(name, location, size, mat, bone, rotation=(0, 0, 0), bevel=0.02, weights=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = size
    apply_transform(obj)
    if bevel > 0:
        activate(obj)
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    resolved = weights if weights is not None else ({bone: 1.0} if bone else None)
    return bind(obj, name, mat, resolved)


def capsule(name, head, tail, radius, mat, bone, segments=24, weights=None):
    a = Vector(head)
    b = Vector(tail)
    mid = (a + b) * 0.5
    length = (b - a).length
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=max(8, segments // 2), location=mid
    )
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    obj.scale = (radius, radius * 0.92, length * 0.5 + radius * 0.35)
    resolved = weights if weights is not None else ({bone: 1.0} if bone else None)
    return bind(obj, name, mat, resolved)


def ribbon(name, points, widths, mat, groups):
    verts = []
    for (x, y, z), width in zip(points, widths):
        verts.append((x - width * 0.5, y, z))
        verts.append((x + width * 0.5, y, z))
    faces = [(index * 2, index * 2 + 1, index * 2 + 3, index * 2 + 2) for index in range(len(points) - 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    smooth(obj, 30.0)
    for bone in sorted({bone for weights in groups for bone in weights}):
        obj.vertex_groups.new(name=bone)
    for index, weights in enumerate(groups):
        for bone, weight in weights.items():
            obj.vertex_groups[bone].add([index * 2, index * 2 + 1], weight, "REPLACE")
    obj.parent = ARM
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = ARM
    obj["keeper"] = True
    return obj


def cylinder(name, location, radius, depth, mat, bone, rotation=(0, 0, 0), vertices=32, weights=None):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation
    )
    resolved = weights if weights is not None else ({bone: 1.0} if bone else None)
    return bind(bpy.context.object, name, mat, resolved, 30.0)


def torus(name, location, major, minor, mat, bone, rotation=(0, 0, 0), weights=None):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=48,
        minor_segments=10,
        location=location,
        rotation=rotation,
    )
    resolved = weights if weights is not None else ({bone: 1.0} if bone else None)
    return bind(bpy.context.object, name, mat, resolved, 40.0)


def cone(name, location, radius1, radius2, depth, mat, bone, rotation=(0, 0, 0), vertices=32, weights=None):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    resolved = weights if weights is not None else ({bone: 1.0} if bone else None)
    return bind(bpy.context.object, name, mat, resolved, 30.0)


def torso_weights(obj):
    hips = obj.vertex_groups.new(name="hips")
    spine = obj.vertex_groups.new(name="spine")
    chest = obj.vertex_groups.new(name="chest")
    for vert in obj.data.vertices:
        z = vert.co.z
        index = [vert.index]
        if z <= 1.10:
            hips.add(index, 1.0, "REPLACE")
        elif z < 1.28:
            t = (z - 1.10) / 0.18
            hips.add(index, 1.0 - t, "REPLACE")
            spine.add(index, t, "REPLACE")
        elif z < 1.42:
            t = (z - 1.28) / 0.14
            spine.add(index, 1.0 - t, "REPLACE")
            chest.add(index, t, "REPLACE")
        else:
            chest.add(index, 1.0, "REPLACE")


def coat_weights(bone: str):
    def assign(obj):
        chest = obj.vertex_groups.new(name="chest")
        lower = obj.vertex_groups.new(name=bone)
        for vert in obj.data.vertices:
            z = vert.co.z
            index = [vert.index]
            if z >= 1.30:
                chest.add(index, 1.0, "REPLACE")
            elif z > 1.08:
                t = (z - 1.08) / 0.22
                lower.add(index, 1.0 - t, "REPLACE")
                chest.add(index, t, "REPLACE")
            else:
                lower.add(index, 1.0, "REPLACE")

    return assign


# ---------------------------------------------------------------------------
# Armature
# ---------------------------------------------------------------------------


def build_armature():
    armature = bpy.data.armatures.new("KeeperArmature")
    arm = bpy.data.objects.new("KeeperRig", armature)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bones = armature.edit_bones

    def bone(name, head, tail, parent=None):
        item = bones.new(name)
        item.head = head
        item.tail = tail
        if parent:
            item.parent = bones[parent]
            item.use_connect = False
        return item

    bone("root", (0, 0, 0), (0, 0, 0.3))
    bone("hips", (0, 0, 0.96), (0, 0, 1.10), "root")
    bone("spine", (0, 0, 1.10), (0, 0, 1.30), "hips")
    bone("chest", (0, 0, 1.30), (0, 0, 1.47), "spine")
    bone("neck", (0, 0, 1.47), (0, 0, 1.56), "chest")
    bone("head", (0, 0, 1.56), (0, 0, 1.82), "neck")
    bone("shoulder_L", (0.03, 0, 1.44), (0.19, 0, 1.45), "chest")
    bone("shoulder_R", (-0.03, 0, 1.44), (-0.19, 0, 1.45), "chest")
    bone("upper_arm_L", (0.20, 0, 1.43), (0.25, 0, 1.17), "shoulder_L")
    bone("upper_arm_R", (-0.20, 0, 1.43), (-0.25, 0, 1.17), "shoulder_R")
    bone("forearm_L", (0.25, 0, 1.17), (0.27, 0, 0.95), "upper_arm_L")
    bone("forearm_R", (-0.25, 0, 1.17), (-0.27, 0, 0.95), "upper_arm_R")
    bone("hand_L", (0.27, 0, 0.95), (0.28, 0, 0.87), "forearm_L")
    bone("hand_R", (-0.27, 0, 0.95), (-0.28, 0, 0.87), "forearm_R")
    bone("thigh_L", (0.10, 0, 0.94), (0.11, 0, 0.55), "hips")
    bone("thigh_R", (-0.10, 0, 0.94), (-0.11, 0, 0.55), "hips")
    bone("shin_L", (0.11, 0, 0.55), (0.11, 0, 0.15), "thigh_L")
    bone("shin_R", (-0.11, 0, 0.55), (-0.11, 0, 0.15), "thigh_R")
    bone("foot_L", (0.11, 0, 0.15), (0.11, -0.17, 0.035), "shin_L")
    bone("foot_R", (-0.11, 0, 0.15), (-0.11, -0.17, 0.035), "shin_R")
    bone("coat_back", (0, 0.02, 0.98), (0, 0.05, 0.55), "hips")
    bone("coat_L", (0.10, 0.0, 0.97), (0.16, 0.0, 0.55), "hips")
    bone("coat_R", (-0.10, 0.0, 0.97), (-0.16, 0.0, 0.55), "hips")
    bone("scarf_1", (0, 0.05, 1.47), (0, 0.17, 1.40), "neck")
    bone("scarf_2", (0, 0.17, 1.40), (0, 0.30, 1.30), "scarf_1")
    bone("scarf_3", (0, 0.30, 1.30), (0, 0.42, 1.18), "scarf_2")
    bone("lantern", (0.28, 0, 0.90), (0.28, 0, 0.66), "hand_L")

    bpy.ops.object.mode_set(mode="OBJECT")
    for pose_bone in arm.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    arm.name = "KeeperRig"
    arm["keeper"] = True
    return arm


# ---------------------------------------------------------------------------
# Keeper
# ---------------------------------------------------------------------------


def build_keeper(mats, mode):
    cream = mats["cream"]
    paper = mats["paper"]
    ink = mats["ink"]
    ink_soft = mats["ink_soft"]
    coat = mats["coat"]
    leather = mats["leather"]
    lime = mats["lime"]

    # Torso and coat
    sphere("Torso", (0, 0, 1.24), (0.178, 0.118, 0.27), coat, None, 48, 24, weights=torso_weights)
    sphere("Chest", (0, 0, 1.38), (0.192, 0.125, 0.16), coat, None, 48, 24, weights=torso_weights)
    box("Shirt", (0, -0.118, 1.27), (0.15, 0.03, 0.34), cream, None, bevel=0.02, weights=torso_weights)
    for index, z in enumerate((1.16, 1.26, 1.36)):
        sphere(f"Button{index}", (0.0, -0.138, z), (0.012, 0.008, 0.012), leather, None, 16, 8,
               weights=torso_weights)

    torus("Belt", (0, 0, 1.055), 0.185, 0.028, leather, "hips")
    box("Buckle", (0, -0.154, 1.055), (0.05, 0.014, 0.038), lime, "hips", bevel=0.008)

    # Pleated coat skirt. Seven panels leave the front open over the shirt.
    for angle_deg in (0, 45, -45, 90, -90, 135, -135):
        angle = math.radians(angle_deg)
        radius = 0.235
        x = radius * math.sin(angle)
        y = radius * math.cos(angle)
        bone = "coat_back" if abs(angle_deg) < 90 else ("coat_L" if angle_deg > 0 else "coat_R")
        box(
            f"Coat{angle_deg:+04d}", (x, y, 0.92), (0.16, 0.035, 0.72),
            coat if abs(angle_deg) <= 45 else ink_soft, None,
            rotation=(0.14, 0, -angle), bevel=0.012, weights=coat_weights(bone),
        )

    torus("Collar", (0, 0, 1.47), 0.108, 0.030, cream, "chest")
    box("LapelL", (0.10, -0.125, 1.40), (0.09, 0.022, 0.14), cream, "chest", rotation=(0, 0, 0.30), bevel=0.008)
    box("LapelR", (-0.10, -0.125, 1.40), (0.09, 0.022, 0.14), cream, "chest", rotation=(0, 0, -0.30), bevel=0.008)

    # Head and wide hat
    capsule("Neck", (0, 0, 1.44), (0, 0, 1.58), 0.052, cream, "neck", 20)
    sphere("Head", (0, -0.015, 1.69), (0.118, 0.108, 0.125), cream, "head", 40, 20)
    sphere("Hair", (0, 0.028, 1.708), (0.126, 0.112, 0.120), ink, "head", 36, 18)
    sphere("EyeL", (0.048, -0.112, 1.715), (0.016, 0.012, 0.018), lime, "head", 20, 10)
    sphere("EyeR", (-0.048, -0.112, 1.715), (0.016, 0.012, 0.018), lime, "head", 20, 10)
    sphere("Nose", (0.0, -0.125, 1.675), (0.018, 0.022, 0.025), cream, "head", 20, 10)
    cylinder("HatBrim", (0, -0.01, 1.805), 0.210, 0.022, ink, "head", vertices=64)
    cone("HatCrown", (0, -0.01, 1.885), 0.135, 0.055, 0.15, ink, "head", vertices=48)
    torus("HatBand", (0, -0.01, 1.823), 0.142, 0.013, cream, "head")

    # Shoulders and arms
    for side, sign in (("L", 1.0), ("R", -1.0)):
        sphere(f"Shoulder.{side}", (0.195 * sign, 0, 1.435), (0.092, 0.086, 0.080), ink, "chest", 28, 14)
        capsule(
            f"UpperArm.{side}", (0.205 * sign, 0, 1.42), (0.25 * sign, 0, 1.16),
            0.065, ink_soft, f"upper_arm_{side}", 24,
        )
        capsule(
            f"Forearm.{side}", (0.25 * sign, 0, 1.16), (0.272 * sign, 0, 0.96),
            0.052, ink, f"forearm_{side}", 24,
        )
        cylinder(
            f"Cuff.{side}", (0.274 * sign, 0, 0.985), 0.056, 0.04, cream,
            f"forearm_{side}", vertices=24,
        )
        sphere(f"Hand.{side}", (0.28 * sign, -0.005, 0.925), (0.052, 0.048, 0.06), cream, f"hand_{side}", 22, 12)

    # Legs and boots
    for side, sign in (("L", 1.0), ("R", -1.0)):
        capsule(
            f"Thigh.{side}", (0.10 * sign, 0, 0.94), (0.11 * sign, 0, 0.56),
            0.088, ink, f"thigh_{side}", 26,
        )
        capsule(
            f"Shin.{side}", (0.11 * sign, 0, 0.55), (0.11 * sign, 0, 0.16),
            0.062, ink_soft, f"shin_{side}", 24,
        )
        sphere(f"Knee.{side}", (0.11 * sign, -0.04, 0.555), (0.066, 0.06, 0.062), ink, f"shin_{side}", 22, 12)
        box(
            f"Boot.{side}", (0.11 * sign, -0.055, 0.085), (0.14, 0.29, 0.12),
            leather, f"foot_{side}", bevel=0.045,
        )
        box(
            f"Sole.{side}", (0.11 * sign, -0.055, 0.025), (0.145, 0.30, 0.03),
            ink, f"foot_{side}", bevel=0.01,
        )
        box(
            f"BootCuff.{side}", (0.11 * sign, 0.015, 0.16), (0.12, 0.145, 0.045),
            cream, f"shin_{side}", bevel=0.012,
        )

    # Scarf: a flat cream ribbon with a waving tail.
    ribbon(
        "Scarf",
        [
            (0.000, 0.045, 1.475),
            (0.015, 0.135, 1.425),
            (0.025, 0.235, 1.350),
            (0.015, 0.325, 1.255),
            (-0.010, 0.395, 1.155),
            (-0.025, 0.430, 1.070),
        ],
        [0.072, 0.082, 0.090, 0.088, 0.075, 0.055],
        cream,
        [
            {"scarf_1": 1.0},
            {"scarf_1": 0.6, "scarf_2": 0.4},
            {"scarf_2": 1.0},
            {"scarf_2": 0.35, "scarf_3": 0.65},
            {"scarf_3": 1.0},
            {"scarf_3": 1.0},
        ],
    )

    # Lantern
    torus("LanternHandle", (0.28, 0, 0.862), 0.062, 0.012, ink, "lantern", rotation=(math.pi / 2, 0, 0), weights={"lantern": 1.0})
    cylinder("LanternCap", (0.28, 0, 0.80), 0.066, 0.032, ink, "lantern", vertices=24)
    cylinder("LanternGlass", (0.28, 0, 0.732), 0.06, 0.11, lime, "lantern", vertices=24)
    cylinder("LanternBase", (0.28, 0, 0.668), 0.07, 0.032, ink, "lantern", vertices=24)
    for angle in (0, math.pi / 2, math.pi, 3 * math.pi / 2):
        x = 0.28 + 0.064 * math.cos(angle)
        y = 0.064 * math.sin(angle)
        box(
            f"LanternBar{int(math.degrees(angle))}", (x, y, 0.732), (0.008, 0.008, 0.11),
            ink, "lantern", bevel=0.002,
        )

    # A tiny satchel on the right hip
    box("Satchel", (-0.22, 0.055, 1.0), (0.13, 0.09, 0.15), leather, "hips", rotation=(0, 0, -0.12), bevel=0.02)
    box("SatchelFlap", (-0.22, 0.11, 1.045), (0.135, 0.02, 0.07), ink_soft, "hips", rotation=(0, 0, -0.12), bevel=0.012)


# ---------------------------------------------------------------------------
# World
# ---------------------------------------------------------------------------


def build_sky(mats):
    sky = mats["sky"]
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=80)
    dome = bpy.context.object
    dome.name = "SkyDome"
    dome.data.materials.append(sky)
    bpy.ops.object.shade_smooth()

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=2.6, depth=0.04, location=(-12.5, -24.0, 8.2), rotation=(math.pi / 2, 0, 0))
    moon = bpy.context.object
    moon.name = "Moon"
    moon.data.materials.append(mats["moon"])
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=3.4, depth=0.02, location=(-12.45, -23.95, 8.2), rotation=(math.pi / 2, 0, 0))
    halo = bpy.context.object
    halo.name = "MoonHalo"
    halo.data.materials.append(mats["moon_halo"])


def build_water(mats):
    river = mats["river"]
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, -0.02))
    plane = bpy.context.object
    plane.name = "River"
    plane.scale = (26, 7.5, 1)
    plane.data.materials.append(river)
    apply_transform(plane)

    # Moon path and city reflections on the water.
    for index, (x, width, length) in enumerate(
        [(7.5, 1.4, 12.0), (4.4, 0.5, 7.0), (10.2, 0.4, 6.0), (-3.2, 0.35, 5.0), (-8.5, 0.4, 6.0)]
    ):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(x, -8.5 - index * 0.4, 0.0))
        strip = bpy.context.object
        strip.name = f"Reflection{index}"
        strip.scale = (width, length, 1)
        strip.data.materials.append(mats["reflection"])
        apply_transform(strip)

    # Soft paper banks either side of the river.
    for name, y in (("NearBank", 8.4), ("FarBank", -8.2)):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, y, 0.14))
        bank = bpy.context.object
        bank.name = name
        bank.scale = (26, 3.2, 1)
        bank.data.materials.append(mats["bank"])
        apply_transform(bank)

    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -14.5, 0.12))
    ground = bpy.context.object
    ground.name = "CityGround"
    ground.scale = (28, 7.0, 1)
    ground.data.materials.append(mats["bank"])
    apply_transform(ground)


def build_bridge(mats):
    paper = mats["bank"]
    ink = mats["ink"]
    leather = mats["leather"]

    # Deck planks following the arch.
    count = 21
    for index in range(count):
        y = 5.8 - index * (11.6 / (count - 1))
        z = deck_z(y)
        slope = (deck_z(y + 0.1) - deck_z(y - 0.1)) / 0.2
        box(
            f"Plank{index:02d}", (0, y, z - 0.035), (2.3, 0.53, 0.07),
            paper, None, rotation=(math.atan(slope), 0, 0), bevel=0.012,
        )

    # Side beams and posts, ink rope rails, and little paper lanterns.
    bulbs = []
    for side in (-1.0, 1.0):
        for index in range(12):
            y = 5.9 - index * (11.8 / 11)
            z = deck_z(y)
            box(
                f"Post{int(side)}_{index:02d}", (1.04 * side, y, z + 0.40), (0.055, 0.055, 0.86),
                ink, None, bevel=0.008,
            )
            box(
                f"Cap{int(side)}_{index:02d}", (1.04 * side, y, z + 0.84), (0.09, 0.09, 0.05),
                leather, None, bevel=0.012,
            )
            bpy.ops.mesh.primitive_uv_sphere_add(
                segments=16, ring_count=8, radius=0.028,
                location=(1.04 * side, y, z + 0.90),
            )
            bulb = bpy.context.object
            bulb.name = f"Bulb{int(side)}_{index:02d}"
            bulb.scale = (1.0, 1.0, 1.2)
            bulb.data.materials.append(mats["bulb"])
            smooth(bulb, 40.0)
            bulbs.append((bulb, y))

    # Rope rails as thin cylinders between posts.
    for side in (-1.0, 1.0):
        for level in (0.42, 0.76):
            previous = None
            for index in range(13):
                y = 5.95 - index * (11.9 / 12)
                z = deck_z(y) + level
                point = (1.04 * side, y, z)
                if previous:
                    bevel_rail(previous, point, f"Rail{int(side)}_{level}_{index:02d}", ink)
                previous = point

    # Support arches under the deck.
    for side in (-1.0, 1.0):
        for index in range(7):
            y = 4.6 - index * 1.55
            z = deck_z(y) - 0.16
            box(
                f"Support{int(side)}_{index}", (1.0 * side, y, z - 0.32), (0.06, 0.06, 0.55),
                ink, None, rotation=(math.radians(-8), 0, 0), bevel=0.008,
            )

    return bulbs


def bevel_rail(a, b, name, mat):
    va = Vector(a)
    vb = Vector(b)
    mid = (va + vb) * 0.5
    length = (vb - va).length
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.012, depth=length, location=mid)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = (vb - va).to_track_quat("Z", "Y")
    obj.data.materials.append(mat)
    smooth(obj, 40.0)


def build_city(mats):
    random.seed(11)
    ink = mats["ink"]
    ink_soft = mats["ink_soft"]
    cream = mats["cream"]
    roof = mats["roof"]
    window = mats["window"]
    window_dim = mats["window_dim"]
    win_geo = []

    buildings = []
    for index, x in enumerate([-13, -10.4, -7.8, -5.4, -3.0, 0.6, 3.1, 5.7, 8.4, 11.4, 14.0]):
        height = random.uniform(2.2, 6.4)
        width = random.uniform(1.5, 2.5)
        depth = random.uniform(1.4, 2.4)
        y = random.uniform(-16.5, -11.0)
        mat = ink if index % 2 else ink_soft
        buildings.append((x, y, height, width, depth))
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, height * 0.5 + 0.16))
        building = bpy.context.object
        building.name = f"Building{index}"
        building.scale = (width, depth, height)
        building.data.materials.append(mat)
        apply_transform(building)
        # Roof trim
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, height + 0.19))
        trim = bpy.context.object
        trim.name = f"Roof{index}"
        trim.scale = (width * 1.06, depth * 1.06, 0.07)
        trim.data.materials.append(roof)
        apply_transform(trim)
        if index % 2 == 0:
            bpy.ops.mesh.primitive_cone_add(
                vertices=4, radius1=width * 0.72, radius2=0.02, depth=0.62,
                location=(x, y, height + 0.52), rotation=(0, 0, math.pi / 4),
            )
            gable = bpy.context.object
            gable.name = f"Gable{index}"
            gable.scale = (1.0, depth / width, 1.0) if width else (1.0, 1.0, 1.0)
            gable.data.materials.append(roof)
            apply_transform(gable)
        if height > 4.4:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.05, depth=1.1, location=(x + width * 0.2, y, height + 0.8))
            spire = bpy.context.object
            spire.name = f"Spire{index}"
            spire.data.materials.append(ink)
            apply_transform(spire)
        # Windows on the camera-facing side.
        rows = max(2, int(height / 0.7))
        columns = 2 if width < 2.0 else 3
        for row in range(rows):
            for column in range(columns):
                wx = x - width * 0.32 + column * width * 0.32
                wz = 0.55 + row * 0.58
                if wz > height - 0.2:
                    continue
                lit = random.random() < 0.12
                bpy.ops.mesh.primitive_cube_add(size=1, location=(wx, y + depth * 0.5 + 0.012, wz))
                glint = bpy.context.object
                glint.name = f"Window{index}_{row}_{column}"
                glint.scale = (0.12, 0.012, 0.20)
                glint.data.materials.append(window_dim if lit else window)
                # Keep the object origin on the window so the wake scales in place.
                win_geo.append((glint, wx, wz, lit, row + column * 0.7))

    # Clock tower at the heart of the city.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(-6.6, -10.8, 4.26))
    tower = bpy.context.object
    tower.name = "ClockTower"
    tower.scale = (1.35, 1.35, 8.2)
    tower.data.materials.append(ink)
    apply_transform(tower)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.15, radius2=0.05, depth=1.6, location=(-6.6, -10.8, 9.16))
    cap = bpy.context.object
    cap.name = "ClockSpire"
    cap.rotation_euler = (0, 0, math.pi / 4)
    cap.data.materials.append(roof)
    apply_transform(cap)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.55, depth=0.05, location=(-6.6, -10.1, 7.4), rotation=(math.pi / 2, 0, 0))
    clock = bpy.context.object
    clock.name = "ClockFace"
    clock.data.materials.append(mats["clock"])
    apply_transform(clock)
    torus("ClockRing", (-6.6, -10.06, 7.4), 0.64, 0.028, cream, None, rotation=(math.pi / 2, 0, 0))

    # Paper trees on the far bank.
    for index, (x, scale) in enumerate([(-7.2, 1.0), (6.4, 0.85), (10.6, 1.15), (-11.6, 0.9)]):
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.055, depth=1.0 * scale, location=(x, -8.8, 0.65 * scale))
        trunk = bpy.context.object
        trunk.name = f"TreeTrunk{index}"
        trunk.data.materials.append(ink)
        apply_transform(trunk)
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.55 * scale, radius2=0.04, depth=1.35 * scale, location=(x, -8.8, 1.5 * scale))
        crown = bpy.context.object
        crown.name = f"TreeCrown{index}"
        crown.data.materials.append(ink_soft)
        apply_transform(crown)

    return win_geo


def build_atmosphere(mats):
    # Haze layers between the bridge and the city.
    for index, y in enumerate((-7.5, -11.5, -16.0)):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0, y, 2.6))
        haze = bpy.context.object
        haze.name = f"Haze{index}"
        haze.scale = (34, 7, 1)
        haze.rotation_euler = (math.pi / 2, 0, 0)
        haze.data.materials.append(mats["haze"])
        apply_transform(haze)

    # City glow behind the skyline.
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, -20.0, 3.4))
    glow = bpy.context.object
    glow.name = "CityGlow"
    glow.scale = (20, 7, 1)
    glow.rotation_euler = (math.pi / 2, 0, 0)
    glow.data.materials.append(mats["city_glow"])
    apply_transform(glow)


def build_fireflies(mats):
    random.seed(7)
    fly_mat = mats["fly"]
    flies = []
    for index in range(26):
        x = random.uniform(-8, 8)
        y = random.uniform(-13, 3.5)
        z = random.uniform(0.4, 2.4)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.014, location=(x, y, z))
        fly = bpy.context.object
        fly.name = f"Fly{index}"
        fly.data.materials.append(fly_mat)
        flies.append((fly, x, y, z, random.uniform(0, math.tau), random.uniform(0.5, 1.2)))
    return flies


def build_lantern_beam(mats, arm):
    # Beam cone follows the lantern bone with a child-of constraint.
    bpy.ops.mesh.primitive_cone_add(
        vertices=40, radius1=0.40, radius2=0.02, depth=1.3,
        end_fill_type="NOTHING", location=(0.28, 0, 0.08),
    )
    beam = bpy.context.object
    beam.name = "LanternBeam"
    beam.data.materials.append(mats["beam"])
    constrain_to_bone(beam, arm, "lantern")
    beam.scale = (0.001, 0.001, 0.001)
    beam["film_fx"] = True
    return beam


def constrain_to_bone(obj, arm, bone_name):
    bpy.context.view_layer.update()
    pose_bone = arm.pose.bones[bone_name]
    constraint = obj.constraints.new("CHILD_OF")
    constraint.target = arm
    constraint.subtarget = bone_name
    constraint.inverse_matrix = (arm.matrix_world @ pose_bone.matrix).inverted()


def build_moths(mats):
    wing = mats["moth"]
    moths = []
    for index in range(3):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(0.28, 0.5, 2.1))
        moth = bpy.context.object
        moth.name = f"Moth{index}"
        moth.scale = (0.045, 0.03, 1)
        moth.rotation_euler = (math.pi / 2, 0, 0)
        moth.data.materials.append(wing)
        apply_transform(moth)
        moths.append(moth)
    return moths


def build_lantern_fx(mats, arm):
    beam = build_lantern_beam(mats, arm)
    moths = build_moths(mats)

    light_data = bpy.data.lights.new("LanternGlow", type="POINT")
    light_data.color = (0.62, 1.0, 0.24)
    light_data.energy = 18
    light_data.shadow_soft_size = 0.14
    point = bpy.data.objects.new("LanternGlow", light_data)
    bpy.context.scene.collection.objects.link(point)
    point.location = (0.28, 0, 0.73)
    constrain_to_bone(point, arm, "lantern")

    spot_data = bpy.data.lights.new("LanternSpot", type="SPOT")
    spot_data.color = (0.62, 1.0, 0.3)
    spot_data.energy = 0
    spot_data.spot_size = math.radians(62)
    spot_data.spot_blend = 0.55
    spot = bpy.data.objects.new("LanternSpot", spot_data)
    bpy.context.scene.collection.objects.link(spot)
    spot.location = (0.28, 0, 0.70)
    constrain_to_bone(spot, arm, "lantern")

    return beam, point, spot, moths


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------


def reset_pose(arm):
    for pose_bone in arm.pose.bones:
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)


def walk_pose(arm, phase: float, amount: float, keeper_y: float, root_z: float):
    p = arm.pose.bones
    swing = math.sin(phase)
    bob = 0.018 * amount * (-math.cos(2.0 * phase))
    hips_yaw = 0.10 * amount * swing
    hips_roll = 0.032 * amount * math.sin(phase + math.pi / 2)

    root = p["root"]
    # The root bone points up, so its local Z runs along world -Y.
    root.location = (0.0, root_z + bob + 0.012 * amount, -keeper_y)

    p["hips"].rotation_euler = (0.04 * amount, hips_yaw, hips_roll)
    p["spine"].rotation_euler = (0.055 * amount, -0.55 * hips_yaw, -0.35 * hips_roll)
    p["chest"].rotation_euler = (0.025 * amount, -0.35 * hips_yaw, -0.25 * hips_roll)
    p["neck"].rotation_euler = (-0.02 * amount, 0.2 * hips_yaw, 0.1 * hips_roll)
    p["head"].rotation_euler = (0.01 * amount + 0.018 * amount * math.sin(2 * phase), 0.45 * hips_yaw, -0.6 * hips_roll)

    thigh_l = -0.42 * amount * swing
    thigh_r = 0.42 * amount * swing
    knee_l = 0.08 + 0.60 * amount * max(0.0, -math.sin(phase - 0.30))
    knee_r = 0.08 + 0.60 * amount * max(0.0, -math.sin(phase + math.pi - 0.30))
    foot_l = -0.16 * amount * math.sin(phase + 0.25)
    foot_r = 0.16 * amount * math.sin(phase + 0.25)

    p["thigh_L"].rotation_euler = (thigh_l, 0, 0)
    p["thigh_R"].rotation_euler = (thigh_r, 0, 0)
    p["shin_L"].rotation_euler = (knee_l * amount + 0.04 * (1 - amount), 0, 0)
    p["shin_R"].rotation_euler = (knee_r * amount + 0.04 * (1 - amount), 0, 0)
    p["foot_L"].rotation_euler = (foot_l, 0, 0)
    p["foot_R"].rotation_euler = (foot_r, 0, 0)

    arm_l = 0.13 * amount * swing - 0.04
    arm_r = -0.34 * amount * swing + 0.04
    p["upper_arm_L"].rotation_euler = (arm_l, 0, -0.08)
    p["upper_arm_R"].rotation_euler = (arm_r, 0, 0.08)
    p["forearm_L"].rotation_euler = (-0.12 - 0.06 * max(0.0, -arm_l), 0, 0)
    p["forearm_R"].rotation_euler = (-0.14 - 0.12 * max(0.0, -arm_r), 0, 0)
    p["hand_L"].rotation_euler = (0.04, 0, 0)
    p["hand_R"].rotation_euler = (0.02, 0, 0)

    p["coat_back"].rotation_euler = (0.13 * amount + 0.03 * amount * math.sin(2 * phase), 0, 0.02 * amount * swing)
    p["coat_L"].rotation_euler = (0.09 * amount, 0, -0.06 * amount * swing)
    p["coat_R"].rotation_euler = (0.09 * amount, 0, 0.06 * amount * swing)
    p["scarf_1"].rotation_euler = (0.16 * amount + 0.03 * math.sin(phase - 0.2), 0, 0.04 * math.sin(phase * 0.5))
    p["scarf_2"].rotation_euler = (0.12 * amount + 0.05 * math.sin(phase - 0.6), 0, 0.06 * math.sin(phase * 0.5 - 0.4))
    p["scarf_3"].rotation_euler = (0.08 * amount + 0.08 * math.sin(phase - 1.0), 0, 0.08 * math.sin(phase * 0.5 - 0.8))


def lift_pose(arm, lift: float, phase: float):
    if lift <= 0.0:
        return
    p = arm.pose.bones
    upper = p["upper_arm_L"]
    forearm = p["forearm_L"]
    hand = p["hand_L"]
    head = p["head"]
    neck = p["neck"]
    chest = p["chest"]
    hips = p["hips"]

    direction = (0.46, -0.40, 0.80)
    target = aim_bone(arm, "upper_arm_L", direction)
    current = upper.rotation_euler.to_quaternion()
    upper.rotation_euler = current.slerp(target, lift).to_euler("XYZ")

    forearm.rotation_euler.x = lerp(forearm.rotation_euler.x, -0.20, lift)
    hand.rotation_euler.x = lerp(hand.rotation_euler.x, 0.10, lift)

    hips.rotation_euler.y = lerp(hips.rotation_euler.y, 0.07, lift)
    chest.rotation_euler.x = lerp(chest.rotation_euler.x, -0.04, lift)
    chest.rotation_euler.y = lerp(chest.rotation_euler.y, 0.14, lift)
    neck.rotation_euler.x = lerp(neck.rotation_euler.x, -0.10, lift)
    neck.rotation_euler.y = lerp(neck.rotation_euler.y, 0.24, lift)
    head.rotation_euler.x = lerp(head.rotation_euler.x, -0.30, lift)
    head.rotation_euler.y = lerp(head.rotation_euler.y, 0.82, lift)
    head.rotation_euler.z = lerp(head.rotation_euler.z, -0.10, lift)


def idle_pose(arm, t: float):
    p = arm.pose.bones
    breath = math.sin(math.tau * t)
    sway = math.sin(math.tau * t * 0.5)
    p["root"].location = (0, 0.004 * breath, 0)
    p["hips"].rotation_euler = (0.01, 0.02 * sway, 0.008 * breath)
    p["spine"].rotation_euler = (0.015 * breath, -0.02 * sway, 0)
    p["chest"].rotation_euler = (0.01 * breath, -0.015 * sway, 0)
    p["neck"].rotation_euler = (0, 0.02 * sway, 0)
    p["head"].rotation_euler = (-0.02 + 0.015 * breath, 0.12 * sway, -0.02 * breath)
    p["upper_arm_L"].rotation_euler = (0.02 * breath, 0, -0.07)
    p["upper_arm_R"].rotation_euler = (-0.02 * breath, 0, 0.07)
    p["forearm_L"].rotation_euler = (-0.14, 0, 0)
    p["forearm_R"].rotation_euler = (-0.13, 0, 0)
    p["hand_L"].rotation_euler = (0.02, 0, 0)
    p["thigh_L"].rotation_euler = (0, 0, 0)
    p["thigh_R"].rotation_euler = (0, 0, 0)
    p["shin_L"].rotation_euler = (0.04, 0, 0)
    p["shin_R"].rotation_euler = (0.04, 0, 0)
    p["foot_L"].rotation_euler = (0, 0, 0)
    p["foot_R"].rotation_euler = (0, 0, 0)
    p["coat_back"].rotation_euler = (0.02 * breath, 0, 0)
    p["coat_L"].rotation_euler = (0.01 * breath, 0, -0.01)
    p["coat_R"].rotation_euler = (0.01 * breath, 0, 0.01)
    for index, bone_name in enumerate(("scarf_1", "scarf_2", "scarf_3")):
        p[bone_name].rotation_euler = (
            0.05 + 0.025 * math.sin(math.tau * t * 0.5 - index * 0.5),
            0,
            0.02 * math.sin(math.tau * t * 0.4 - index * 0.4),
        )


def key_all(arm, frame: int):
    for pose_bone in arm.pose.bones:
        pose_bone.keyframe_insert("rotation_euler", frame=frame)
        pose_bone.keyframe_insert("location", frame=frame)


def make_action(arm, name: str):
    arm.animation_data_create()
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    return action


def animate_film(arm, frames: int):
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    action = make_action(arm, "Film")

    for frame in range(1, frames + 1):
        reset_pose(arm)
        travelled = WALK_DISTANCE * smoothstep(1, WALK_END, frame)
        y = START_Y - travelled
        root_z = deck_z(y)
        walk_amount = 1.0 - smoothstep(WALK_END, WALK_END + 8, frame)
        phase = math.tau * STEPS * (travelled / WALK_DISTANCE)
        walk_pose(arm, phase, walk_amount, y, root_z)
        lift = smoothstep(LIFT_START, LIFT_END, frame)
        lift_pose(arm, lift, phase)
        hang_lantern(arm, math.sin(phase) * walk_amount * (1.0 - lift))
        key_all(arm, frame)

    return action


def animate_walk_action(arm):
    frames = 33
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    action = make_action(arm, "Walk")
    for frame in range(1, frames + 1):
        reset_pose(arm)
        phase = math.tau * (frame - 1) / (frames - 1)
        walk_pose(arm, phase, 1.0, 0.0, 0.0)
        hang_lantern(arm, math.sin(phase))
        key_all(arm, frame)
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = frames
    return action


def animate_lift_action(arm):
    frames = 49
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"
    action = make_action(arm, "Lift")
    for frame in range(1, frames + 1):
        reset_pose(arm)
        t = (frame - 1) / (frames - 1)
        lift = smoothstep(0.04, 0.62, t)
        walk_pose(arm, 0.0, 0.0, 0.0, 0.0)
        lift_pose(arm, lift, 0.0)
        p = arm.pose.bones
        breath = math.sin(math.tau * (t - 0.62)) if t > 0.62 else 0.0
        p["chest"].rotation_euler.x += 0.012 * breath
        p["head"].rotation_euler.z += 0.02 * breath
        hang_lantern(arm, 0.25 * math.sin(math.tau * t) * (1.0 - lift))
        key_all(arm, frame)
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = frames
    return action


def animate_idle_action(arm):
    frames = 97
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"
    action = make_action(arm, "Idle")
    for frame in range(1, frames + 1):
        reset_pose(arm)
        idle_pose(arm, (frame - 1) / (frames - 1))
        hang_lantern(arm, 0.4 * math.sin(math.tau * (frame - 1) / (frames - 1) * 0.5))
        key_all(arm, frame)
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = frames
    return action


def stash_action(arm, action, name: str):
    arm.animation_data.action = action
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.name = name
    try:
        if action.slots:
            strip.action_slot = action.slots[0]
    except AttributeError:
        pass
    arm.animation_data.action = None


# ---------------------------------------------------------------------------
# Scene assembly
# ---------------------------------------------------------------------------


def beam_material():
    mat = bpy.data.materials.new("Beam")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.02, 0.03, 0.01, 1.0)
    bsdf.inputs["Roughness"].default_value = 1.0
    emission = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
    if emission:
        emission.default_value = (0.74, 1.0, 0.52, 1.0)
    strength = bsdf.inputs.get("Emission Strength")
    if strength:
        strength.default_value = 0.9
    tex = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    length_ramp = nodes.new("ShaderNodeValToRGB")
    links.new(tex.outputs["Generated"], separate.inputs["Vector"])
    links.new(separate.outputs["Z"], length_ramp.inputs["Fac"])
    elements = length_ramp.color_ramp.elements
    elements[0].position = 0.04
    elements[0].color = (0.0, 0.0, 0.0, 1.0)
    elements[1].position = 0.97
    elements[1].color = (0.05, 0.05, 0.05, 1.0)
    # Fade the cone silhouette so the shaft has no hard edge.
    facing = nodes.new("ShaderNodeLayerWeight")
    facing.inputs["Blend"].default_value = 0.35
    edge_ramp = nodes.new("ShaderNodeValToRGB")
    links.new(facing.outputs["Facing"], edge_ramp.inputs["Fac"])
    edge_ramp.color_ramp.elements[0].position = 0.0
    edge_ramp.color_ramp.elements[0].color = (0.2, 0.2, 0.2, 1.0)
    edge_ramp.color_ramp.elements[1].position = 1.0
    edge_ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    alpha = nodes.new("ShaderNodeMath")
    alpha.operation = "MULTIPLY"
    links.new(length_ramp.outputs["Color"], alpha.inputs[0])
    links.new(edge_ramp.outputs["Color"], alpha.inputs[1])
    links.new(alpha.outputs["Value"], bsdf.inputs["Alpha"])
    try:
        mat.surface_render_method = "BLENDED"
    except AttributeError:
        mat.blend_method = "BLEND"
    mat.use_backface_culling = False
    try:
        mat.use_transparent_shadow = False
    except AttributeError:
        pass
    return mat


def build_materials(mode):
    mats = {}
    mats["cream"] = material("Cream", (0.90, 0.85, 0.76), 0.62)
    mats["paper"] = material("Paper", (0.95, 0.91, 0.82), 0.72)
    mats["ink"] = material("Ink", (0.040, 0.046, 0.062), 0.48, 0.06)
    mats["ink_soft"] = material("InkSoft", (0.10, 0.11, 0.145), 0.55, 0.04)
    mats["coat"] = material("Coat", (0.072, 0.080, 0.105), 0.40, 0.08)
    mats["leather"] = material("Leather", (0.26, 0.18, 0.13), 0.7)
    mats["roof"] = material("Roof", (0.15, 0.12, 0.15), 0.7)
    mats["bank"] = material("Bank", (0.82, 0.76, 0.65), 0.85)
    mats["river"] = material("River", (0.012, 0.018, 0.032), 0.12, 0.55)
    mats["reflection"] = material(
        "Reflection", (1.0, 0.76, 0.46), 0.4, 0.0, emission=(1.0, 0.72, 0.4), strength=0.9, alpha=0.16
    )
    mats["moon"] = material("Moon", (1.0, 0.93, 0.78), 0.9, 0.0, emission=(1.0, 0.93, 0.78), strength=2.6)
    mats["moon_halo"] = material(
        "MoonHalo", (1.0, 0.8, 0.58), 1.0, 0.0, emission=(1.0, 0.8, 0.58), strength=1.2, alpha=0.28
    )
    mats["window"] = material("Window", (0.0, 0.0, 0.0), 0.7, 0.0, emission=(1.0, 0.72, 0.36), strength=5.0)
    mats["window_dim"] = material(
        "WindowDim", (0.0, 0.0, 0.0), 0.7, 0.0, emission=(1.0, 0.72, 0.36), strength=1.0
    )
    mats["clock"] = material("Clock", (0.0, 0.0, 0.0), 0.7, 0.0, emission=(1.0, 0.86, 0.56), strength=4.0)
    mats["fly"] = material("Firefly", (0.6, 1.0, 0.2), 0.8, 0.0, emission=(0.6, 1.0, 0.2), strength=2.4)
    mats["bulb"] = material("Bulb", (0.0, 0.0, 0.0), 0.5, 0.0, emission=(1.0, 0.42, 0.10), strength=1.8)
    mats["moth"] = material("Moth", (0.95, 0.9, 0.78), 0.8, 0.0, emission=(0.95, 0.9, 0.78), strength=0.7)
    mats["haze"] = material(
        "Haze", (0.95, 0.75, 0.55), 0.9, 0.0, emission=(0.95, 0.75, 0.55), strength=0.4, alpha=0.055
    )
    mats["city_glow"] = material(
        "CityGlow", (1.0, 0.62, 0.3), 0.9, 0.0, emission=(1.0, 0.62, 0.3), strength=0.5, alpha=0.07
    )
    mats["beam"] = beam_material()
    mats["lime"] = material(
        "Lime", (0.5, 1.0, 0.1), 0.32, 0.0,
        emission=(0.5, 1.0, 0.1), strength=1.2 if mode == "export" else 3.4,
    )
    mats["sky"] = sky_material()
    return mats


def sky_material():
    mat = bpy.data.materials.new("Sky")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    ramp = nodes.new("ShaderNodeValToRGB")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    tex = nodes.new("ShaderNodeTexCoord")
    links.new(tex.outputs["Generated"], separate.inputs["Vector"])
    links.new(separate.outputs["Z"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], emission.inputs["Color"])
    emission.inputs["Strength"].default_value = 1.0
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    elements = ramp.color_ramp.elements
    elements[0].position = 0.0
    elements[0].color = (0.06, 0.05, 0.09, 1.0)
    elements[1].position = 0.46
    elements[1].color = (0.95, 0.42, 0.24, 1.0)
    middle = elements.new(0.52)
    middle.color = (0.55, 0.28, 0.30, 1.0)
    upper = elements.new(0.66)
    upper.color = (0.10, 0.10, 0.20, 1.0)
    top = elements.new(0.84)
    top.color = (0.03, 0.04, 0.10, 1.0)
    mat.use_backface_culling = False
    return mat


def build_scene(width: int, height: int, engine: str, mode: str, samples: int = 48):
    global ARM
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    mats = build_materials(mode)
    ARM = build_armature()
    build_keeper(mats, mode)

    if mode != "export":
        build_sky(mats)
        build_water(mats)
        bulbs = build_bridge(mats)
        windows = build_city(mats)
        build_atmosphere(mats)
        flies = build_fireflies(mats)
        beam, lantern_light, lantern_spot, moths = build_lantern_fx(mats, ARM)
        animate_world(scene, windows, flies, moths, bulbs, beam, lantern_light, lantern_spot)
        build_lights(mats)

    camera = None
    if mode != "export":
        camera = build_camera(scene)
        animate_film(ARM, FILM_FRAMES)
    else:
        walk = animate_walk_action(ARM)
        idle = animate_idle_action(ARM)
        lift = animate_lift_action(ARM)
        stash_action(ARM, walk, "Walk")
        stash_action(ARM, idle, "Idle")
        stash_action(ARM, lift, "Lift")

    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = FILM_FRAMES if mode != "export" else 97
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    try:
        scene.view_settings.view_transform = "Khronos PBR Neutral"
    except TypeError:
        scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = -0.22

    if engine.upper().startswith("CYCLES"):
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 96
        scene.cycles.use_denoising = True
        scene.cycles.device = "CPU"
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        try:
            scene.eevee.taa_render_samples = samples
        except Exception:
            pass
        try:
            scene.eevee.use_raytracing = True
        except Exception:
            pass

    if mode != "export":
        setup_compositor(scene)

    return scene, {"arm": ARM, "camera": camera, "windows": windows if mode != "export" else []}


def build_lights(mats):
    target = bpy.data.objects.new("LightTarget", None)
    bpy.context.scene.collection.objects.link(target)
    target.location = (0, 2.0, 1.2)

    def aim(obj, location, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.size = size
        light.data.color = color
        light.name = obj
        constraint = light.constraints.new("TRACK_TO")
        constraint.target = target
        constraint.track_axis = "TRACK_NEGATIVE_Z"
        constraint.up_axis = "UP_Y"
        return light

    aim("Key", (3.8, 7.2, 5.2), 420, 3.5, (1.0, 0.82, 0.64))
    aim("Fill", (-4.6, 4.8, 2.8), 120, 6.0, (0.62, 0.72, 1.0))
    aim("Rim", (-2.2, -5.2, 4.0), 260, 3.0, (0.9, 0.94, 1.0))
    aim("MoonKey", (7.2, -18.0, 12.0), 320, 5.0, (0.6, 0.7, 1.0))

    world = bpy.data.worlds.new("Dusk")
    bpy.context.scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.05, 0.07, 0.12, 1.0)
    background.inputs[1].default_value = 0.22


def build_camera(scene):
    target = bpy.data.objects.new("CameraTarget", None)
    bpy.context.scene.collection.objects.link(target)
    target.location = TARGET_KEYS[0][1]

    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.data.lens = 52
    camera.data.sensor_width = 36
    camera.location = CAMERA_KEYS[0][1]
    constraint = camera.constraints.new("TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"
    scene.camera = camera

    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    for frame in range(1, FILM_FRAMES + 1):
        camera.location = spline_sample(CAMERA_KEYS, frame)
        camera.keyframe_insert("location", frame=frame)
        target.location = spline_sample(TARGET_KEYS, frame)
        target.keyframe_insert("location", frame=frame)
    return camera


def animate_world(scene, windows, flies, moths, bulbs, beam, lantern_light, lantern_spot):
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"

    for glint, x, z, lit, order in windows:
        if lit:
            continue
        wake = WAKE_START + abs(x) * 1.4 + z * 1.1 + order * 0.35
        wake = min(WAKE_END - 1, wake)
        glint.scale = (0.001, 0.001, 0.001)
        glint.keyframe_insert("scale", frame=1)
        glint.keyframe_insert("scale", frame=int(max(2, wake - 2)))
        glint.scale = (0.12, 0.012, 0.20)
        glint.keyframe_insert("scale", frame=int(min(FILM_FRAMES, wake + 2)))

    for bulb, y in bulbs:
        wake = 116 + (5.9 - y) * 1.7
        bulb.scale = (0.001, 0.001, 0.001)
        bulb.keyframe_insert("scale", frame=1)
        bulb.keyframe_insert("scale", frame=int(max(2, wake - 2)))
        bulb.scale = (1.0, 1.0, 1.2)
        bulb.keyframe_insert("scale", frame=int(min(FILM_FRAMES, wake + 3)))

    for index, (fly, x, y, z, offset, speed) in enumerate(flies):
        for frame in range(1, FILM_FRAMES + 1, 6):
            t = (frame - 1) / FPS
            fly.location = (
                x + 0.35 * math.sin(t * speed + offset),
                y + 0.25 * math.cos(t * speed * 0.8 + offset),
                z + 0.22 * math.sin(t * speed * 1.4 + offset),
            )
            fly.keyframe_insert("location", frame=frame)

    beam.scale = (0.001, 0.001, 0.001)
    beam.keyframe_insert("scale", frame=LIFT_START - 4)
    beam.scale = (1.0, 1.0, 1.0)
    beam.keyframe_insert("scale", frame=LIFT_END)
    beam.keyframe_insert("scale", frame=FILM_FRAMES)

    lantern_light.data.energy = 18
    lantern_light.data.keyframe_insert("energy", frame=1)
    lantern_light.data.energy = 150
    lantern_light.data.keyframe_insert("energy", frame=LIFT_END)
    lantern_light.data.energy = 125
    lantern_light.data.keyframe_insert("energy", frame=FILM_FRAMES)

    lantern_spot.data.energy = 0
    lantern_spot.data.keyframe_insert("energy", frame=LIFT_START)
    lantern_spot.data.energy = 170
    lantern_spot.data.keyframe_insert("energy", frame=LIFT_END)
    lantern_spot.data.energy = 145
    lantern_spot.data.keyframe_insert("energy", frame=FILM_FRAMES)

    for index, moth in enumerate(moths):
        moth.scale = (0.001, 0.001, 0.001)
        moth.keyframe_insert("scale", frame=LIFT_START - 4)
        moth.scale = (0.045, 0.03, 1)
        moth.keyframe_insert("scale", frame=LIFT_START + 10)
        start = LIFT_START + 4
        for frame in range(start, FILM_FRAMES + 1, 3):
            t = (frame - start) / FPS
            radius = 0.22 + index * 0.06
            angle = t * (1.4 + index * 0.3) + index * 2.1
            moth.location = (
                0.38 + radius * math.cos(angle),
                0.88 + radius * 0.6 * math.sin(angle * 1.2),
                2.18 + 0.10 * math.sin(t * 4.0 + index),
            )
            moth.rotation_euler = (math.pi / 2, 0, angle * 1.5)
            moth.keyframe_insert("location", frame=frame)
            moth.keyframe_insert("rotation_euler", frame=frame)


def setup_compositor(scene):
    try:
        scene.use_nodes = True
        tree = scene.node_tree
        tree.nodes.clear()
        render = tree.nodes.new("CompositorNodeRLayers")
        glare = tree.nodes.new("CompositorNodeGlare")
        glare.glare_type = "FOG_GLOW"
        glare.quality = "HIGH"
        glare.threshold = 0.85
        glare.size = 7
        glare.mix = -0.75
        composite = tree.nodes.new("CompositorNodeComposite")
        tree.links.new(render.outputs["Image"], glare.inputs["Image"])
        tree.links.new(glare.outputs["Image"], composite.inputs["Image"])
    except Exception as error:
        print("COMPOSITOR skipped", error)


def check(scene, rig) -> None:
    arm = rig["arm"]
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH" and obj.get("keeper")]
    print(f"CHECK meshes={len(meshes)} bones={len(arm.data.bones)} camera={scene.camera.name if scene.camera else None}")
    print(f"CHECK frames={scene.frame_start}-{scene.frame_end} fps={scene.render.fps}")
    print(f"CHECK engine={scene.render.engine} resolution={scene.render.resolution_x}x{scene.render.resolution_y}")
    print("CHECK animations=" + ",".join(a.name for a in bpy.data.actions))
    print(f"CHECK keeper_meshes={sorted(obj.name for obj in meshes)[:6]}")


def export_glb(arm, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for obj in bpy.data.objects:
        if obj.get("keeper") and obj.type == "MESH":
            obj.select_set(True)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_force_sampling=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    print(f"GLB {path} {Path(path).stat().st_size} bytes")


def main() -> None:
    args = parse_args()
    if args.export_glb:
        _, rig = build_scene(args.width, args.height, args.engine, "export", args.samples)
        check(bpy.context.scene, rig)
        export_glb(rig["arm"], args.export_glb)
        return

    scene, rig = build_scene(args.width, args.height, args.engine, "film", args.samples)
    check(scene, rig)
    if args.check:
        return

    if args.stills:
        stills_dir = Path(args.stills_dir).resolve()
        stills_dir.mkdir(parents=True, exist_ok=True)
        for raw in args.stills.split(","):
            frame = int(raw.strip())
            if not frame:
                continue
            scene.frame_set(frame)
            scene.render.filepath = str(stills_dir / f"qa_{frame:04d}.png")
            bpy.ops.render.render(write_still=True)
            print(f"STILL {frame} -> {scene.render.filepath}")
        return

    if not args.out:
        raise SystemExit("--out is required unless --check, --stills or --export-glb is used")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    scene.frame_start = args.frames_start
    scene.frame_end = args.frames_end
    scene.render.filepath = str(out / "frame_")
    bpy.ops.render.render(animation=True)
    print(f"RENDERED {args.frames_end - args.frames_start + 1} frames to {out}")


if __name__ == "__main__":
    main()
