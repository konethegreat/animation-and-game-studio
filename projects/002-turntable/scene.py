"""Build the robot turntable scene and render it headless.

Usage (after --):
  --out DIR --frames-start 1 --frames-end 192 --width 1920 --height 1080
  --check
  --export-glb PATH
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

FPS = 24


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


def smooth(obj, angle=35.0):
    try:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle))
    except Exception:
        bpy.ops.object.shade_smooth()
    finally:
        obj.select_set(False)


def sphere(name, location, scale, mat, segments=64, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj)
    return obj


def cylinder(name, location, radius, depth, mat, rotation=(0, 0, 0), vertices=96):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation
    )
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    smooth(obj, 20.0)
    return obj


def torus(name, location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=96, minor_segments=16,
        location=location, rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
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
    obj.empty_display_size = 0.25
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


def build_scene(width: int, height: int, frames: int, engine: str = "EEVEE"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    cream = material("Body", (0.93, 0.885, 0.80), roughness=0.38, metallic=0.05)
    ink = material("Ink", (0.035, 0.037, 0.045), roughness=0.36, metallic=0.15)
    coral = material("Coral", (0.95, 0.18, 0.07), roughness=0.34, metallic=0.05,
                     emission=(1.0, 0.20, 0.08), strength=0.45)
    lime = material("Lime", (0.62, 0.95, 0.16), roughness=0.28,
                    emission=(0.72, 0.95, 0.24), strength=2.6)
    lime_soft = material("LimeSoft", (0.62, 0.95, 0.16), roughness=0.4,
                         emission=(0.72, 0.95, 0.24), strength=1.0)
    sand = material("Sand", (0.78, 0.74, 0.66), roughness=0.9)
    pedestal_mat = material("Pedestal", (0.09, 0.09, 0.10), roughness=0.55, metallic=0.2)

    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "Floor"
    floor.data.materials.append(sand)

    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=1.72, depth=0.26, location=(0, 0, 0.13))
    pedestal = bpy.context.object
    pedestal.name = "Pedestal"
    bevel = pedestal.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.05
    bevel.segments = 5
    pedestal.data.materials.append(pedestal_mat)
    smooth(pedestal, 25.0)

    torus("PedestalInlay", (0, 0, 0.265), 1.52, 0.022, lime_soft)

    pivot = empty("Turntable", (0, 0, 0))
    hover = empty("Hover", (0, 0, 0.04))
    parent_to(hover, pivot)

    body = sphere("Body", (0, 0, 1.55), (0.64, 0.54, 0.76), cream, segments=96, rings=48)
    parent_to(body, hover)
    cylinder("Neck", (0, 0, 2.19), 0.235, 0.14, ink)
    bpy.context.object.parent = hover
    bpy.context.object.matrix_parent_inverse = hover.matrix_world.inverted()

    chest = cylinder("ChestLight", (0, -0.545, 1.60), 0.145, 0.05, coral, rotation=(math.pi / 2, 0, 0))
    parent_to(chest, hover)
    chest_ring = torus("ChestRing", (0, -0.545, 1.60), 0.22, 0.022, lime, rotation=(math.pi / 2, 0, 0))
    parent_to(chest_ring, hover)

    hover_ring = torus("HoverRing", (0, 0, 0.70), 0.50, 0.024, lime)
    parent_to(hover_ring, hover)

    head_group = empty("HeadGroup", (0, 0, 2.58))
    parent_to(head_group, hover)
    head = sphere("Head", (0, 0, 2.58), (0.50, 0.46, 0.44), cream, segments=96, rings=48)
    parent_to(head, head_group)

    visor = cube("Visor", (0, -0.435, 2.60), (0.70, 0.13, 0.34), ink, bevel=0.06)
    parent_to(visor, head_group)

    for side, sx in (("L", -1), ("R", 1)):
        eye = sphere(f"Eye{side}", (sx * 0.135, -0.505, 2.62), (0.055, 0.032, 0.078), lime)
        parent_to(eye, head_group)
        ear = cylinder(
            f"Ear{side}", (sx * 0.49, 0, 2.58), 0.095, 0.07, coral,
            rotation=(0, math.pi / 2, 0),
        )
        parent_to(ear, head_group)

    mouth = sphere("Mouth", (0, -0.505, 2.49), (0.055, 0.02, 0.012), coral)
    parent_to(mouth, head_group)

    antenna = empty("AntennaBase", (0, 0, 2.99))
    parent_to(antenna, head_group)
    rod = cylinder("AntennaRod", (0, 0, 3.17), 0.017, 0.36, ink)
    parent_to(rod, antenna)
    tip = sphere("AntennaTip", (0, 0, 3.38), (0.09, 0.09, 0.09), lime)
    parent_to(tip, antenna)

    arms = {}
    for side, sx in (("L", -1), ("R", 1)):
        arm = empty(f"Arm{side}", (sx * 0.76, 0, 1.60))
        parent_to(arm, hover)
        arms[side] = arm
        upper = sphere(f"UpperArm{side}", (sx * 0.76, 0, 1.60), (0.115, 0.115, 0.27), cream)
        parent_to(upper, arm)
        cuff = torus(f"Cuff{side}", (sx * 0.76, 0, 1.40), 0.115, 0.032, coral)
        parent_to(cuff, arm)
        hand = sphere(f"Hand{side}", (sx * 0.76, 0, 1.27), (0.14, 0.14, 0.14), ink)
        parent_to(hand, arm)

    target = empty("CameraTarget", (0, 0, 1.62))
    bpy.ops.object.camera_add(location=(6.0, -7.4, 4.1))
    camera = bpy.context.object
    camera.name = "Camera"
    camera.data.lens = 48
    look_at_camera(camera, target.location)
    scene.camera = camera

    def area_light(name, location, energy, size, color):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.size = size
        light.data.color = color
        track_to(light, target)

    area_light("Key", (4.6, -5.2, 6.2), 1500, 3.2, (1.0, 0.94, 0.86))
    area_light("Fill", (-5.4, -3.2, 3.4), 320, 8.0, (0.76, 0.85, 1.0))

    rim_target = empty("RimTarget", (0, 0, 2.5))
    bpy.ops.object.light_add(type="SPOT", location=(-3.0, 5.0, 6.2))
    rim = bpy.context.object
    rim.name = "Rim"
    rim.data.energy = 4200
    rim.data.color = (0.72, 0.95, 0.36)
    rim.data.spot_size = math.radians(22)
    rim.data.spot_blend = 1.0
    rim.data.shadow_soft_size = 0.6
    track_to(rim, rim_target)

    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.72, 0.70, 0.66, 1.0)
    background.inputs[1].default_value = 0.45

    _animate(pivot, hover, head_group, antenna, arms, frames)

    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = frames
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.compression = 15
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "Khronos PBR Neutral"
    except TypeError:
        scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"

    if engine.upper().startswith("CYCLES"):
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 48
        scene.cycles.use_denoising = True
        scene.cycles.device = "CPU"
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        try:
            scene.eevee.taa_render_samples = 64
        except Exception:
            pass

    return scene, pivot, camera, floor


def _animate(pivot, hover, head_group, antenna, arms, frames):
    preferences = bpy.context.preferences.edit
    preferences.keyframe_new_interpolation_type = "LINEAR"
    pivot.rotation_mode = "XYZ"
    pivot.rotation_euler = (0, 0, 0)
    pivot.keyframe_insert("rotation_euler", index=2, frame=1)
    pivot.rotation_euler = (0, 0, math.tau * (frames - 1) / frames)
    pivot.keyframe_insert("rotation_euler", index=2, frame=frames)

    preferences.keyframe_new_interpolation_type = "BEZIER"
    hover_base = 0.04
    step = 4
    keyframes = list(range(1, frames + 1, step))
    if keyframes[-1] != frames:
        keyframes.append(frames)
    for frame in keyframes:
        t = (frame - 1) / frames
        hover.location.z = hover_base + 0.045 * math.sin(math.tau * 2.0 * t)
        hover.keyframe_insert("location", index=2, frame=frame)

        head_group.rotation_euler.x = 0.035 * math.sin(math.tau * 1.5 * t + 0.7)
        head_group.rotation_euler.z = 0.09 * math.sin(math.tau * 1.0 * t)
        head_group.keyframe_insert("rotation_euler", index=0, frame=frame)
        head_group.keyframe_insert("rotation_euler", index=2, frame=frame)

        antenna.rotation_euler.x = 0.12 * math.sin(math.tau * 2.0 * t + 0.4)
        antenna.rotation_euler.y = 0.10 * math.sin(math.tau * 1.0 * t + 1.2)
        antenna.keyframe_insert("rotation_euler", index=0, frame=frame)
        antenna.keyframe_insert("rotation_euler", index=1, frame=frame)

        for side, phase in (("L", 0.0), ("R", math.pi)):
            arm = arms[side]
            arm.location.z = 1.60 + 0.055 * math.sin(math.tau * 2.0 * t + phase)
            arm.keyframe_insert("location", index=2, frame=frame)


def check(scene, pivot) -> None:
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    print(f"CHECK meshes={len(meshes)} lights={len(lights)} camera={scene.camera.name}")
    print(f"CHECK frames={scene.frame_start}-{scene.frame_end} fps={scene.render.fps}")
    print(f"CHECK engine={scene.render.engine}")
    print(f"CHECK pivot={pivot.name} rotation={pivot.rotation_euler[2]:.4f}")


def export_glb(pivot, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    keep = {"Turntable", "Hover", "Body", "Neck", "ChestLight", "ChestRing", "HoverRing",
            "HeadGroup", "Head", "Visor", "EyeL", "EyeR", "EarL", "EarR", "Mouth",
            "AntennaBase", "AntennaRod", "AntennaTip", "ArmL", "ArmR", "UpperArmL",
            "UpperArmR", "CuffL", "CuffR", "HandL", "HandR", "Pedestal", "PedestalInlay"}
    root = None
    for obj in bpy.context.scene.objects:
        if obj.name in keep:
            obj.select_set(True)
            if obj.name == "Turntable":
                root = obj
    bpy.context.view_layer.objects.active = root
    bpy.context.scene.frame_set(1)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_yup=True,
    )
    print(f"GLB {path} {Path(path).stat().st_size} bytes")


def main() -> None:
    args = parse_args()
    scene, pivot, _, _ = build_scene(
        args.width, args.height, args.frames_end, args.engine
    )
    check(scene, pivot)
    if args.check:
        return
    if args.export_glb:
        export_glb(pivot, args.export_glb)
        return
    if not args.out:
        raise SystemExit("--out is required unless --check or --export-glb is used")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    if args.hero:
        scene.frame_set(30)
        scene.render.film_transparent = True
        scene.render.image_settings.color_mode = "RGBA"
        bpy.data.objects["Floor"].hide_render = True
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
