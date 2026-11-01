"""__TITLE__: a minimal Blender turntable starting point.

Usage (after --):
  --out DIR --frames-start 1 --frames-end 96 --width 1280 --height 720
  --check
  --export-glb PATH
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

FPS = 24


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--frames-start", type=int, default=1)
    parser.add_argument("--frames-end", type=int, default=96)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--export-glb", default="")
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


def look_at(camera, target):
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def track_to(obj, target):
    constraint = obj.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"


def build_scene(width: int, height: int, frames: int, engine: str = "EEVEE"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    cream = material("Body", (0.93, 0.885, 0.80), roughness=0.38, metallic=0.05)
    ink = material("Ink", (0.035, 0.037, 0.045), roughness=0.36, metallic=0.15)
    coral = material("Coral", (0.95, 0.18, 0.07), roughness=0.34,
                     emission=(1.0, 0.20, 0.08), strength=0.45)
    lime = material("Lime", (0.62, 0.95, 0.16), roughness=0.28,
                    emission=(0.72, 0.95, 0.24), strength=2.0)
    sand = material("Sand", (0.78, 0.74, 0.66), roughness=0.9)
    pedestal_mat = material("Pedestal", (0.09, 0.09, 0.10), roughness=0.55, metallic=0.2)

    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "Floor"
    floor.data.materials.append(sand)

    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=1.3, depth=0.24, location=(0, 0, 0.12))
    pedestal = bpy.context.object
    pedestal.name = "Pedestal"
    bevel = pedestal.modifiers.new("Bevel", "BEVEL")
    bevel.width = 0.04
    bevel.segments = 5
    pedestal.data.materials.append(pedestal_mat)
    smooth(pedestal, 25.0)

    bpy.ops.mesh.primitive_torus_add(
        major_radius=1.14, minor_radius=0.02, major_segments=96, minor_segments=16,
        location=(0, 0, 0.245),
    )
    ring = bpy.context.object
    ring.name = "PedestalInlay"
    ring.data.materials.append(lime)
    smooth(ring)

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0, 0))
    pivot = bpy.context.object
    pivot.name = "Turntable"

    body = sphere("Body", (0, 0, 1.45), (0.55, 0.50, 0.62), cream, segments=96, rings=48)
    body.parent = pivot

    head = sphere("Head", (0, 0, 2.15), (0.36, 0.34, 0.30), cream, segments=96, rings=48)
    head.parent = pivot

    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=0.10, depth=0.30, location=(0, 0, 2.55))
    antenna = bpy.context.object
    antenna.name = "Antenna"
    antenna.data.materials.append(ink)
    antenna.parent = pivot
    smooth(antenna, 20.0)

    tip = sphere("AntennaTip", (0, 0, 2.72), (0.075, 0.075, 0.075), lime)
    tip.parent = pivot

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=64, radius=0.10, depth=0.05, location=(0, -0.34, 1.48),
        rotation=(math.pi / 2, 0, 0),
    )
    chest = bpy.context.object
    chest.name = "ChestLight"
    chest.data.materials.append(coral)
    chest.parent = pivot
    smooth(chest, 20.0)

    target = bpy.data.objects.new("CameraTarget", None)
    scene.collection.objects.link(target)
    target.location = (0, 0, 1.45)

    bpy.ops.object.camera_add(location=(5.2, -6.4, 3.4))
    camera = bpy.context.object
    camera.name = "Camera"
    camera.data.lens = 50
    look_at(camera, target.location)
    scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(4.2, -4.8, 5.6))
    key = bpy.context.object
    key.name = "Key"
    key.data.energy = 1200
    key.data.size = 3.0
    key.data.color = (1.0, 0.94, 0.86)
    track_to(key, target)

    bpy.ops.object.light_add(type="AREA", location=(-4.6, -2.8, 3.0))
    fill = bpy.context.object
    fill.name = "Fill"
    fill.data.energy = 260
    fill.data.size = 7.0
    fill.data.color = (0.76, 0.85, 1.0)
    track_to(fill, target)

    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.72, 0.70, 0.66, 1.0)
    background.inputs[1].default_value = 0.45

    animate(pivot, frames)

    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = frames
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
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

    return scene, pivot


def animate(pivot, frames: int) -> None:
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    pivot.rotation_mode = "XYZ"
    pivot.rotation_euler = (0, 0, 0)
    pivot.keyframe_insert("rotation_euler", index=2, frame=1)
    pivot.rotation_euler = (0, 0, math.tau * (frames - 1) / frames)
    pivot.keyframe_insert("rotation_euler", index=2, frame=frames)


def check(scene, pivot) -> None:
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    print(f"CHECK meshes={len(meshes)} lights={len(lights)} camera={scene.camera.name}")
    print(f"CHECK frames={scene.frame_start}-{scene.frame_end} fps={scene.render.fps}")
    print(f"CHECK engine={scene.render.engine}")
    print(f"CHECK pivot={pivot.name} rotation={pivot.rotation_euler[2]:.4f}")


def export_glb(path: str) -> None:
    bpy.ops.object.select_all(action="SELECT")
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    print(f"GLB {path} {Path(path).stat().st_size} bytes")


def main() -> None:
    args = parse_args()
    scene, pivot = build_scene(args.width, args.height, args.frames_end, args.engine)
    check(scene, pivot)
    if args.check:
        return
    if args.export_glb:
        export_glb(args.export_glb)
        return
    if not args.out:
        raise SystemExit("--out is required unless --check or --export-glb is used")
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    scene.frame_start = args.frames_start
    scene.frame_end = args.frames_end
    scene.render.filepath = str(out / "frame_")
    bpy.ops.render.render(animation=True)
    print(f"RENDERED {args.frames_end - args.frames_start + 1} frames to {out}")


if __name__ == "__main__":
    main()
