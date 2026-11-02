"""Build the Companion scene, turntable render and glTF export.

Usage (after --):
  --out DIR --frames-start 1 --frames-end 192 --width 1920 --height 1080
  --check
  --export-glb PATH
  --hero
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from pathlib import Path

import bpy
from mathutils import Vector

FPS = 24
TAU = math.tau


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--frames-start", type=int, default=1)
    parser.add_argument("--frames-end", type=int, default=192)
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--export-glb", default="")
    parser.add_argument("--hero", action="store_true")
    parser.add_argument("--engine", default="EEVEE")
    return parser.parse_args(argv)


# --------------------------------------------------------------- primitives
def material(name, color, roughness=0.5, metallic=0.0, emission=None, strength=0.0):
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
    return mat


def pool_material():
    mat = bpy.data.materials.new("Pool")
    mat.use_nodes = True
    tree = mat.node_tree
    nodes, links = tree.nodes, tree.links
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputMaterial")
    mix = nodes.new("ShaderNodeMixShader")
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (1.0, 0.36, 0.10, 1.0)
    emission.inputs["Strength"].default_value = 2.4
    coords = nodes.new("ShaderNodeTexCoord")
    vector = nodes.new("ShaderNodeVectorMath")
    vector.operation = "LENGTH"
    remap = nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = 0.0
    remap.inputs["From Max"].default_value = 0.62
    remap.inputs["To Min"].default_value = 1.0
    remap.inputs["To Max"].default_value = 0.0
    links.new(coords.outputs["Object"], vector.inputs[0])
    links.new(vector.outputs["Value"], remap.inputs["Value"])
    links.new(remap.outputs["Result"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(emission.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], output.inputs["Surface"])
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        mat.blend_method = "BLEND"
    return mat


def sweep_material():
    mat = bpy.data.materials.new("Sweep")
    mat.use_nodes = True
    tree = mat.node_tree
    bsdf = tree.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.94
    coords = tree.nodes.new("ShaderNodeTexCoord")
    split = tree.nodes.new("ShaderNodeSeparateXYZ")
    remap = tree.nodes.new("ShaderNodeMapRange")
    remap.inputs["From Min"].default_value = 0.0
    remap.inputs["From Max"].default_value = 6.5
    ramp = tree.nodes.new("ShaderNodeValToRGB")
    tree.links.new(coords.outputs["Object"], split.inputs["Vector"])
    tree.links.new(split.outputs["Z"], remap.inputs["Value"])
    tree.links.new(remap.outputs["Result"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.42, 0.355, 0.27, 1.0)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (0.945, 0.905, 0.835, 1.0)
    mid = ramp.color_ramp.elements.new(0.30)
    mid.color = (0.79, 0.71, 0.585, 1.0)
    tree.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
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


def sphere(name, location, scale, mat, segments=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=location
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def cylinder(name, location, radius, depth, mat, rotation=(0, 0, 0), vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    smooth(obj, 20.0)
    return obj


def torus(name, location, major, minor, mat, rotation=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=72, minor_segments=14,
        location=location, rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    if scale != (1, 1, 1):
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def cube(name, location, scale, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = bevel
    modifier.segments = 4
    obj.data.materials.append(mat)
    smooth(obj, 30.0)
    return obj


def empty(name, location):
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=location)
    obj = bpy.context.object
    obj.name = name
    obj.empty_display_size = 0.2
    return obj


def parent_to(child, parent):
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()


def track_to(obj, target):
    constraint = obj.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"


def look_at_camera(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def ribbon(name, points, width, mat, thickness=0.012):
    verts = []
    faces = []
    for index, point in enumerate(points):
        p = Vector(point)
        if index < len(points) - 1:
            tangent = (Vector(points[index + 1]) - p).normalized()
        else:
            tangent = (p - Vector(points[index - 1])).normalized()
        side = Vector((1.0, 0.0, 0.0))
        side = (side - tangent * side.dot(tangent)).normalized()
        half = side * (width / 2)
        verts.extend([tuple(p - half), tuple(p + half)])
    for index in range(len(points) - 1):
        a, b = 2 * index, 2 * index + 1
        c, d = 2 * (index + 1) + 1, 2 * (index + 1)
        faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    modifier = obj.modifiers.new("Solidify", "SOLIDIFY")
    modifier.thickness = thickness
    return obj


def spring(name, base, turns, height, radius, wire, mat):
    curve = bpy.data.curves.new(f"{name}Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = wire
    curve.bevel_resolution = 2
    curve.resolution_u = 12
    spline = curve.splines.new("POLY")
    steps = int(turns * 22)
    spline.points.add(steps)
    for index in range(steps + 1):
        angle = TAU * turns * index / steps
        spline.points[index].co = (
            base[0] + radius * math.cos(angle),
            base[1] + radius * math.sin(angle),
            base[2] + height * index / steps,
            1.0,
        )
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.name = name
    smooth(obj, 55.0)
    return obj


# ------------------------------------------------------------------- studio
def build_backdrop(mats):
    profile = []
    floor_start, floor_end = -30.0, 2.4
    arc_radius = 3.2
    for index in range(9):
        profile.append((floor_start + (floor_end - floor_start) * index / 8, 0.0))
    for index in range(1, 25):
        t = (math.pi / 2) * index / 24
        profile.append((floor_end + arc_radius * math.sin(t), arc_radius - arc_radius * math.cos(t)))
    for index in range(1, 8):
        profile.append((floor_end + arc_radius, arc_radius + 5.0 * index / 7))

    half_width = 30.0
    verts = []
    for y, z in profile:
        verts.append((-half_width, y, z))
        verts.append((half_width, y, z))
    faces = []
    for index in range(len(profile) - 1):
        a, b = 2 * index, 2 * index + 1
        c, d = 2 * (index + 1) + 1, 2 * (index + 1)
        faces.append((a, b, c, d))
    mesh = bpy.data.meshes.new("SweepMesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Sweep", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mats["sweep"])
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    smooth(obj, 60.0)
    return obj


def build_dust(mats, count, frames):
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"
    motes = []
    for index in range(count):
        phase = index * 1.618
        radius = 1.15 + (index * 0.137) % 3.0
        angle = index * 2.399
        base_x = math.cos(angle) * radius
        base_y = math.sin(angle) * radius * 0.8
        base_z = 0.35 + (index * 0.291) % 4.0
        size = 0.006 + ((index * 7) % 11) / 11 * 0.013
        mote = sphere(
            f"Mote{index:02d}", (base_x, base_y, base_z),
            (size, size, size), mats["mote"], segments=10, rings=6,
        )
        motes.append(mote)
        for frame in range(1, frames + 1, 8):
            t = (frame - 1) / frames
            mote.location.x = base_x + 0.16 * math.sin(TAU * t + phase)
            mote.location.y = base_y + 0.12 * math.cos(TAU * t + phase * 0.7)
            mote.location.z = base_z + 0.20 * math.sin(TAU * 2 * t + phase)
            mote.keyframe_insert("location", frame=frame)
        mote.location.x = base_x + 0.16 * math.sin(phase)
        mote.location.y = base_y + 0.12 * math.cos(phase * 0.7)
        mote.location.z = base_z + 0.20 * math.sin(phase)
    return motes


def build_bokeh(mats, frames):
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "BEZIER"
    spots = [
        (-3.6, -3.0, 2.6, 0.050), (-3.9, -4.4, 1.4, 0.038),
        (4.2, -4.0, 3.7, 0.044), (5.0, -5.2, 1.9, 0.030),
        (-2.6, 2.6, 3.2, 0.042), (2.8, 3.4, 2.2, 0.034),
        (0.6, 3.8, 4.0, 0.040), (-1.4, 3.2, 1.2, 0.028),
    ]
    orbs = []
    for index, (x, y, z, size) in enumerate(spots):
        orb = sphere(f"Bokeh{index}", (x, y, z), (size, size, size),
                     mats["bokeh"], segments=12, rings=8)
        orbs.append(orb)
        for frame in range(1, frames + 1, 12):
            t = (frame - 1) / frames
            orb.location.x = x + 0.10 * math.sin(TAU * t + index)
            orb.location.z = z + 0.12 * math.sin(TAU * t + index * 2.1)
            orb.keyframe_insert("location", frame=frame)
    return orbs


# ---------------------------------------------------------------- companion
def build_companion(root, mats):
    rig = {}

    hover = empty("Hover", (0, 0, 0.04))
    parent_to(hover, root)
    rig["hover"] = hover

    body = sphere("Body", (0, 0, 1.55), (0.62, 0.52, 0.74), mats["cream"], 72, 36)
    parent_to(body, hover)
    rig["body"] = body

    back_hatch = cylinder(
        "BackHatch", (0, 0.46, 1.44), 0.15, 0.05, mats["coral"],
        rotation=(math.pi / 2, 0, 0), vertices=40,
    )
    parent_to(back_hatch, hover)

    chest_ring = torus("ChestRing", (0, -0.535, 1.58), 0.21, 0.024, mats["coral"],
                       rotation=(math.pi / 2, 0, 0))
    parent_to(chest_ring, hover)
    chest = cylinder("chest", (0, -0.552, 1.58), 0.145, 0.05, mats["core"],
                     rotation=(math.pi / 2, 0, 0), vertices=40)
    parent_to(chest, hover)
    rig["chest"] = chest

    core_light = bpy.data.lights.new("CoreLight", type="POINT")
    core_light.energy = 18.0
    core_light.color = (1.0, 0.62, 0.32)
    core_light.shadow_soft_size = 0.18
    core_obj = bpy.data.objects.new("CoreLight", core_light)
    bpy.context.collection.objects.link(core_obj)
    core_obj.location = (0, -0.62, 1.58)
    parent_to(core_obj, hover)
    rig["core_light"] = core_obj

    hover_ring = torus("HoverRing", (0, 0, 0.55), 0.54, 0.026, mats["glow"])
    parent_to(hover_ring, hover)
    hover_inner = torus("HoverRingInner", (0, 0, 0.51), 0.34, 0.014, mats["glow"],
                        scale=(1, 1, 0.6))
    parent_to(hover_inner, hover)

    neck = cylinder("Neck", (0, 0, 2.26), 0.155, 0.16, mats["ink"], vertices=40)
    parent_to(neck, hover)

    head = empty("head", (0, 0, 2.60))
    parent_to(head, hover)
    rig["head"] = head
    head_mesh = sphere("HeadMesh", (0, 0, 2.60), (0.465, 0.425, 0.405), mats["cream"], 72, 36)
    parent_to(head_mesh, head)

    band = torus("VisorBand", (0, 0, 2.64), 0.436, 0.024, mats["ink"], scale=(1, 1, 0.55))
    parent_to(band, head)
    visor = cube("visor", (0, -0.365, 2.60), (0.585, 0.195, 0.275), mats["ink"], bevel=0.095)
    parent_to(visor, head)
    rig["visor"] = visor

    for side, sx in (("L", -1), ("R", 1)):
        eye = sphere(f"Eye{side}", (sx * 0.152, -0.478, 2.63),
                     (0.060, 0.024, 0.080), mats["glow"], 24, 12)
        parent_to(eye, head)
        rig[f"eye_{side.lower()}"] = eye
        pod = cylinder(f"Ear{side}", (sx * 0.455, 0, 2.60), 0.098, 0.085, mats["coral"],
                       rotation=(0, math.pi / 2, 0), vertices=36)
        parent_to(pod, head)
        cap = cylinder(f"EarCap{side}", (sx * 0.505, 0, 2.60), 0.052, 0.028, mats["ink"],
                       rotation=(0, math.pi / 2, 0), vertices=28)
        parent_to(cap, head)

    antenna = empty("antenna", (0, 0, 3.005))
    parent_to(antenna, head)
    rig["antenna"] = antenna
    coil = spring("AntennaCoil", (0, 0, 3.005), 5.0, 0.34, 0.045, 0.012, mats["ink"])
    parent_to(coil, antenna)
    tip = sphere("AntennaTip", (0, 0, 3.37), (0.05, 0.05, 0.05), mats["glow"], 24, 12)
    parent_to(tip, antenna)

    for side, sx in (("L", -1), ("R", 1)):
        ax = sx * 0.575
        shoulder = empty(f"arm_{side.lower()}", (ax, 0, 1.685))
        parent_to(shoulder, hover)
        rig[f"arm_{side.lower()}"] = shoulder

        cap = torus(f"ShoulderCap{side}", (ax, 0, 1.685), 0.118, 0.028, mats["coral"])
        parent_to(cap, shoulder)
        upper = sphere(f"UpperArm{side}", (ax, 0, 1.50), (0.116, 0.116, 0.21),
                       mats["cream"], 32, 16)
        parent_to(upper, shoulder)

        elbow = empty(f"elbow_{side.lower()}", (ax, 0, 1.315))
        parent_to(elbow, shoulder)
        rig[f"elbow_{side.lower()}"] = elbow
        joint = sphere(f"Elbow{side}", (ax, 0, 1.315), (0.108, 0.108, 0.108),
                       mats["ink"], 32, 16)
        parent_to(joint, elbow)
        cuff = torus(f"Cuff{side}", (ax, 0, 1.245), 0.094, 0.026, mats["coral"])
        parent_to(cuff, elbow)
        fore = sphere(f"Forearm{side}", (ax, 0, 1.145), (0.092, 0.092, 0.17),
                      mats["cream"], 32, 16)
        parent_to(fore, elbow)
        hand = sphere(f"Hand{side}", (ax, -0.012, 0.955), (0.124, 0.114, 0.106),
                      mats["ink"], 32, 16)
        parent_to(hand, elbow)

    scarf = empty("scarf", (0, 0, 2.28))
    parent_to(scarf, hover)
    rig["scarf"] = scarf
    collar = torus("ScarfCollar", (0, 0, 2.29), 0.27, 0.056, mats["coral"], scale=(1, 1, 0.72))
    parent_to(collar, scarf)
    knot = sphere("ScarfKnot", (0.12, -0.20, 2.27), (0.085, 0.06, 0.065),
                  mats["coral"], segments=24, rings=12)
    parent_to(knot, scarf)
    tail = ribbon(
        "ScarfTail",
        [(0.18, 0.30, 2.24), (0.28, 0.42, 2.02), (0.24, 0.50, 1.78), (0.32, 0.54, 1.52)],
        0.17, mats["coral"], thickness=0.012,
    )
    parent_to(tail, scarf)
    flick = ribbon(
        "ScarfFlick",
        [(-0.12, 0.32, 2.22), (-0.22, 0.42, 2.00), (-0.18, 0.50, 1.76)],
        0.12, mats["coral"], thickness=0.010,
    )
    parent_to(flick, scarf)

    return rig


# ------------------------------------------------------------------- lights
def build_lights(target, mats):
    def area(name, location, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.size = size
        light.data.color = color
        track_to(light, target)
        return light

    area("Key", (3.0, -4.8, 5.8), 1150, 5.0, (1.0, 0.93, 0.84))
    area("Fill", (-5.2, -3.4, 2.9), 220, 7.5, (0.78, 0.87, 1.0))
    area("Bounce", (0.0, -2.4, 0.25), 80, 4.0, (1.0, 0.90, 0.78))

    bpy.ops.object.light_add(type="SPOT", location=(0.0, 3.6, 0.5))
    wash = bpy.context.object
    wash.name = "Backdrop"
    wash.data.energy = 1400
    wash.data.color = (1.0, 0.90, 0.76)
    wash.data.spot_size = math.radians(88)
    wash.data.spot_blend = 1.0
    wash.data.shadow_soft_size = 1.0
    wash_target = empty("BackdropTarget", (0.0, 5.2, 4.6))
    track_to(wash, wash_target)

    bpy.ops.object.light_add(type="SPOT", location=(1.4, -2.6, 4.6))
    pool = bpy.context.object
    pool.name = "Pool"
    pool.data.energy = 1600
    pool.data.color = (1.0, 0.93, 0.84)
    pool.data.spot_size = math.radians(50)
    pool.data.spot_blend = 1.0
    pool.data.shadow_soft_size = 1.2
    pool_target = empty("PoolTarget", (0.0, 0.1, 0.15))
    track_to(pool, pool_target)

    rim = bpy.data.lights.new("Rim", type="SPOT")
    rim.energy = 5000
    rim.color = (0.86, 0.92, 1.0)
    rim.spot_size = math.radians(30)
    rim.spot_blend = 1.0
    rim.shadow_soft_size = 0.6
    rim_obj = bpy.data.objects.new("Rim", rim)
    bpy.context.collection.objects.link(rim_obj)
    rim_obj.location = (-2.2, 4.6, 4.8)
    track_to(rim_obj, target)

    bpy.ops.object.light_add(type="SPOT", location=(4.4, 1.8, 2.2))
    kicker = bpy.context.object
    kicker.name = "Kicker"
    kicker.data.energy = 900
    kicker.data.color = (1.0, 0.52, 0.30)
    kicker.data.spot_size = math.radians(34)
    kicker.data.spot_blend = 0.9
    kicker.data.shadow_soft_size = 0.5
    track_to(kicker, target)
    return rim_obj


# ----------------------------------------------------------------- the film
def build_scene(width: int, height: int, frames: int, engine: str = "EEVEE"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    mats = {
        "cream": material("Cream", (0.905, 0.862, 0.782), roughness=0.3, metallic=0.03),
        "ink": material("Ink", (0.042, 0.043, 0.052), roughness=0.3, metallic=0.2),
        "coral": material("Coral", (0.86, 0.28, 0.14), roughness=0.4),
        "glow": material("Glow", (1.0, 0.80, 0.55), roughness=0.3,
                         emission=(1.0, 0.58, 0.24), strength=4.0),
        "core": material("Core", (0.18, 0.06, 0.02), roughness=0.25,
                         emission=(1.0, 0.34, 0.06), strength=7.0),
        "sweep": sweep_material(),
        "disc": material("Disc", (0.035, 0.035, 0.042), roughness=0.18, metallic=0.4),
        "mote": material("Mote", (1.0, 0.88, 0.70), roughness=0.5,
                         emission=(1.0, 0.78, 0.50), strength=2.8),
        "bokeh": material("Bokeh", (1.0, 0.84, 0.60), roughness=0.5,
                          emission=(1.0, 0.72, 0.42), strength=1.4),
        "pool": pool_material(),
    }

    build_backdrop(mats)

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=128, radius=1.95, depth=0.26, location=(0, 0, 0.13)
    )
    disc = bpy.context.object
    disc.name = "Disc"
    bevel = disc.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.06
    bevel.segments = 5
    disc.data.materials.append(mats["disc"])
    smooth(disc, 25.0)
    torus("DiscInlay", (0, 0, 0.268), 1.62, 0.012, mats["glow"], scale=(1, 1, 0.35))
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=96, radius=0.62, depth=0.004, location=(0, 0, 0.269)
    )
    glow_pool = bpy.context.object
    glow_pool.name = "HoverPool"
    glow_pool.data.materials.append(mats["pool"])

    pool_light = bpy.data.lights.new("PoolLight", type="POINT")
    pool_light.energy = 14.0
    pool_light.color = (1.0, 0.55, 0.24)
    pool_light.shadow_soft_size = 0.35
    pool_obj = bpy.data.objects.new("PoolLight", pool_light)
    bpy.context.collection.objects.link(pool_obj)
    pool_obj.location = (0, 0, 0.42)

    root = empty("companion", (0, 0, 0))
    rig = build_companion(root, mats)

    target = empty("CameraTarget", (0, 0, 1.68))
    bpy.ops.object.camera_add(location=(4.1, -6.7, 3.05))
    camera = bpy.context.object
    camera.name = "Camera"
    camera.data.lens = 44
    look_at_camera(camera, target.location)
    camera.data.dof.use_dof = True
    camera.data.dof.aperture_fstop = 2.0
    camera.data.dof.aperture_blades = 7
    focus = empty("Focus", (0, 0, 1.58))
    camera.data.dof.focus_object = focus
    scene.camera = camera

    build_lights(target, mats)
    motes = build_dust(mats, 46, frames)
    orbs = build_bokeh(mats, frames)

    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.86, 0.80, 0.71, 1.0)
    background.inputs[1].default_value = 0.28

    _animate(root, rig, frames)

    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = frames
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.compression = 20
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "Khronos PBR Neutral"
    except TypeError:
        scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    if engine.upper().startswith("CYCLES"):
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 64
        scene.cycles.use_denoising = True
        scene.cycles.device = "CPU"
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        try:
            scene.eevee.taa_render_samples = 48
        except Exception:
            pass
        try:
            scene.eevee.use_raytracing = True
        except Exception:
            pass

    return scene, rig, camera, root, motes + orbs


# --------------------------------------------------------------- animation
def _set_interp(mode):
    bpy.context.preferences.edit.keyframe_new_interpolation_type = mode


def _push_idle(*objects):
    for obj in objects:
        data = obj.animation_data
        if not data or not data.action:
            continue
        action = data.action
        track = data.nla_tracks.new()
        track.name = "Idle"
        track.strips.new("Idle", 1, action)
        data.action = None


def _smoothstep(a, b, t):
    if b <= a:
        return 1.0 if t >= b else 0.0
    x = max(0.0, min(1.0, (t - a) / (b - a)))
    return x * x * (3 - 2 * x)


def _animate(root, rig, frames):
    _set_interp("LINEAR")
    root.rotation_mode = "XYZ"
    root.rotation_euler = (0, 0, 0)
    root.keyframe_insert("rotation_euler", index=2, frame=1)
    root.rotation_euler = (0, 0, TAU * (frames - 1) / frames)
    root.keyframe_insert("rotation_euler", index=2, frame=frames)

    _set_interp("BEZIER")
    animated = [root, rig["hover"], rig["head"], rig["antenna"], rig["scarf"],
                rig["body"], rig["arm_l"], rig["arm_r"], rig["elbow_l"], rig["elbow_r"],
                rig["eye_l"], rig["eye_r"]]

    for frame in range(1, frames + 1, 4):
        t = (frame - 1) / frames

        rig["hover"].location.z = 0.04 + 0.045 * math.sin(TAU * 2 * t)
        rig["hover"].keyframe_insert("location", index=2, frame=frame)

        breath = 1.0 + 0.013 * math.sin(TAU * 2 * t + 0.4)
        rig["body"].scale = (breath, 1.0 + 0.010 * math.sin(TAU * 2 * t), breath)
        rig["body"].keyframe_insert("scale", frame=frame)

        rig["head"].rotation_euler.x = 0.05 * math.sin(TAU * 2 * t + 1.1)
        rig["head"].rotation_euler.z = 0.11 * math.sin(TAU * t + 0.5)
        rig["head"].keyframe_insert("rotation_euler", index=0, frame=frame)
        rig["head"].keyframe_insert("rotation_euler", index=2, frame=frame)

        wave = max(
            _smoothstep(0.015, 0.055, t) * (1.0 - _smoothstep(0.145, 0.195, t)),
            _smoothstep(0.835, 0.865, t) * (1.0 - _smoothstep(0.955, 0.99, t)),
        )
        beat = math.sin(TAU * 6 * t)
        rig["arm_r"].rotation_euler.y = -0.18 - 1.82 * wave
        rig["arm_r"].rotation_euler.z = -0.30 * wave
        rig["arm_r"].rotation_euler.x = 0.05 * math.sin(TAU * 2 * t + 0.8)
        rig["arm_r"].keyframe_insert("rotation_euler", frame=frame)
        rig["elbow_r"].rotation_euler.y = -0.08 + wave * (-1.07 + 0.22 * beat)
        rig["elbow_r"].keyframe_insert("rotation_euler", index=1, frame=frame)

        rig["arm_l"].rotation_euler.y = 0.18 + 0.05 * math.sin(TAU * 2 * t + 1.6)
        rig["arm_l"].rotation_euler.x = 0.04 * math.sin(TAU * t + 0.3)
        rig["arm_l"].keyframe_insert("rotation_euler", frame=frame)
        rig["elbow_l"].rotation_euler.y = 0.08 + 0.08 * math.sin(TAU * 2 * t + 1.1)
        rig["elbow_l"].keyframe_insert("rotation_euler", index=1, frame=frame)

        rig["antenna"].rotation_euler.x = (
            0.06 * math.sin(TAU * 2 * t + 0.9) + 0.16 * wave * math.sin(TAU * 6 * t)
        )
        rig["antenna"].rotation_euler.y = (
            0.05 * math.sin(TAU * t + 2.0) + 0.10 * wave * math.sin(TAU * 6 * t + 0.8)
        )
        rig["antenna"].keyframe_insert("rotation_euler", index=0, frame=frame)
        rig["antenna"].keyframe_insert("rotation_euler", index=1, frame=frame)

        rig["scarf"].rotation_euler.x = 0.05 * math.sin(TAU * t + 0.2) + 0.06 * wave
        rig["scarf"].rotation_euler.z = 0.07 * math.sin(TAU * 2 * t + 1.4)
        rig["scarf"].keyframe_insert("rotation_euler", index=0, frame=frame)
        rig["scarf"].keyframe_insert("rotation_euler", index=2, frame=frame)

    _set_interp("BEZIER")
    for start, close in ((12, 20), (58, 66), (168, 176)):
        for eye in ("eye_l", "eye_r"):
            obj = rig[eye]
            obj.scale = (1, 1, 1)
            obj.keyframe_insert("scale", frame=start)
            obj.scale = (1.05, 1, 0.12)
            obj.keyframe_insert("scale", frame=start + 3)
            obj.scale = (1, 1, 1)
            obj.keyframe_insert("scale", frame=close)

    _push_idle(*animated)


# ----------------------------------------------------------------- output
def character_objects(root):
    found = []
    stack = [root]
    while stack:
        obj = stack.pop()
        found.append(obj)
        stack.extend(obj.children)
    return found


def check(scene, rig, root) -> None:
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    print(f"CHECK meshes={len(meshes)} lights={len(lights)} camera={scene.camera.name}")
    print(f"CHECK frames={scene.frame_start}-{scene.frame_end} fps={scene.render.fps}")
    print(f"CHECK engine={scene.render.engine} lens={scene.camera.data.lens}")
    print(f"CHECK nodes={','.join(sorted(o.name for o in character_objects(root)))}")


def glb_summary(path: str) -> dict:
    data = Path(path).read_bytes()
    _, _, total = struct.unpack_from("<III", data, 0)
    offset = 12
    while offset < total:
        chunk_len, chunk_type = struct.unpack_from("<II", data, offset)
        chunk = data[offset + 8 : offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:
            doc = json.loads(chunk.decode("utf-8"))
            return {
                "nodes": [node.get("name", "") for node in doc.get("nodes", [])],
                "animations": [anim.get("name", "") for anim in doc.get("animations", [])],
                "meshes": len(doc.get("meshes", [])),
                "bytes": len(data),
            }
        offset += 8 + chunk_len + ((4 - chunk_len % 4) % 4)
    raise ValueError("no JSON chunk in GLB")


def export_glb(root, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in character_objects(root):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.context.scene.frame_set(1)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    kwargs = dict(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_yup=True,
    )
    try:
        bpy.ops.export_scene.gltf(
            **kwargs,
            export_animation_mode="NLA_TRACKS",
            export_frame_range=True,
        )
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs)
    summary = glb_summary(path)
    print(f"GLB {path} {summary['bytes']} bytes")
    print(f"GLB nodes={','.join(sorted(summary['nodes']))}")
    print(f"GLB animations={','.join(summary['animations'])}")


def main() -> None:
    args = parse_args()
    scene, rig, camera, root, motes = build_scene(
        args.width, args.height, args.frames_end, args.engine
    )
    check(scene, rig, root)
    if args.check:
        return
    if args.export_glb:
        export_glb(root, args.export_glb)
        return
    if not args.out:
        raise SystemExit("--out is required unless --check or --export-glb is used")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if args.hero:
        scene.frame_set(30)
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
        for name in ("Sweep", "Disc", "DiscInlay"):
            bpy.data.objects[name].hide_render = True
        for mote in motes:
            mote.hide_render = True
        scene.render.filepath = str(out / "hero.png")
        bpy.ops.render.render(write_still=True)
        print(f"HERO {out / 'hero.png'}")
        return
    scene.frame_start = args.frames_start
    scene.frame_end = args.frames_end
    scene.render.filepath = str(out / "frame_")
    bpy.ops.render.render(animation=True)
    print(f"RENDERED {args.frames_end - args.frames_start + 1} frames to {out}")


if __name__ == "__main__":
    main()
