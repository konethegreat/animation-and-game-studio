"""Lantern Keeper: a hooded figure walks, stops and lifts a lime lantern.

Usage (after --):
  --out DIR --frames-start 1 --frames-end 120 --width 1280 --height 720
  --stills 1,45,76,112 --stills-dir qa
  --check
  --export-glb PATH
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import bpy

FPS = 24
STEPS = 3
WALK_START = 16
WALK_END = 76
LIFT_START = 94
LIFT_END = 112
ROOT_TRAVEL = 1.75

# Camera offsets from the character, sampled at these frames and joined
# with a Catmull-Rom spline so the dolly never stalls between keys.
CAMERA_KEYS = [
    (1, (3.4, -7.6, 2.4)),
    (40, (1.6, -7.1, 2.4)),
    (76, (-1.0, -6.6, 2.35)),
    (96, (-3.0, -5.6, 2.25)),
    (120, (-4.2, -4.9, 2.05)),
]


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="")
    parser.add_argument("--frames-start", type=int, default=1)
    parser.add_argument("--frames-end", type=int, default=120)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--stills", default="")
    parser.add_argument("--stills-dir", default="qa")
    parser.add_argument("--samples", type=int, default=64)
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


def joint(name, parent=None, offset=(0, 0, 0)):
    empty = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(empty)
    empty.empty_display_size = 0.12
    if parent is not None:
        empty.parent = parent
    empty.location = offset
    return empty


def _finish(obj, name, parent, offset, mat, smooth_angle=35.0):
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    smooth(obj, smooth_angle)
    obj.parent = parent
    obj.location = offset
    return obj


def ball(name, parent, offset, scale, mat, segments=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments, ring_count=rings, location=(0, 0, 0)
    )
    obj = bpy.context.object
    obj.scale = scale
    return _finish(obj, name, parent, offset, mat)


def drum(name, parent, offset, radius, depth, mat, rotation=(0, 0, 0), vertices=64):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=(0, 0, 0), rotation=rotation
    )
    obj = bpy.context.object
    return _finish(obj, name, parent, offset, mat, 30.0)


def cone(name, parent, offset, bottom, top, depth, mat):
    bpy.ops.mesh.primitive_cone_add(
        vertices=64, radius1=bottom, radius2=top, depth=depth, location=(0, 0, 0)
    )
    obj = bpy.context.object
    return _finish(obj, name, parent, offset, mat, 30.0)


def ring(name, parent, offset, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=64,
        minor_segments=12,
        location=(0, 0, 0),
        rotation=rotation,
    )
    obj = bpy.context.object
    return _finish(obj, name, parent, offset, mat, 40.0)


def track_to(obj, target):
    constraint = obj.constraints.new(type="TRACK_TO")
    constraint.target = target
    constraint.track_axis = "TRACK_NEGATIVE_Z"
    constraint.up_axis = "UP_Y"


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


def camera_offset(frame: float) -> tuple[float, float, float]:
    points = CAMERA_KEYS
    if frame <= points[0][0]:
        return points[0][1]
    if frame >= points[-1][0]:
        return points[-1][1]
    for index in range(len(points) - 1):
        frame_a, value_a = points[index]
        frame_b, value_b = points[index + 1]
        if frame_a <= frame <= frame_b:
            before = points[max(0, index - 1)][1]
            after = points[min(len(points) - 1, index + 2)][1]
            t = (frame - frame_a) / (frame_b - frame_a)
            return catmull(before, value_a, value_b, after, t)
    return points[-1][1]


def build_scene(width: int, height: int, frames: int, engine: str, mode: str = "film"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    cream = material("Cream", (0.93, 0.885, 0.80), roughness=0.46, metallic=0.04)
    ink = material("Ink", (0.035, 0.037, 0.045), roughness=0.38, metallic=0.16)
    # The browser tone map clips 2.8 emission to white, so the GLB carries a softer glow.
    lime = material(
        "Lime", (0.45, 1.0, 0.05), roughness=0.30,
        emission=(0.45, 1.0, 0.05), strength=1.0 if mode == "loop" else 2.8,
    )
    sand = material("Sand", (0.70, 0.63, 0.53), roughness=0.92)

    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = "Floor"
    floor.data.materials.append(sand)

    root = joint("Keeper")
    bob = joint("Bob", root)

    head = joint("Head", bob, (0, 0, 1.46))
    ball("HeadShell", head, (0, 0, 0.16), (0.235, 0.225, 0.22), cream)
    ball("EyeL", head, (0.08, -0.205, 0.09), (0.031, 0.031, 0.031), lime, 24, 12)
    ball("EyeR", head, (-0.08, -0.205, 0.09), (0.031, 0.031, 0.031), lime, 24, 12)
    drum("HatBrim", head, (0, 0, 0.31), 0.43, 0.03, ink, vertices=96)
    cone("HatCrown", head, (0, 0, 0.45), 0.24, 0.03, 0.28, ink)

    ball("Torso", bob, (0, 0, 1.06), (0.30, 0.26, 0.36), cream, 64, 32)
    ring("Collar", bob, (0, 0, 1.36), 0.19, 0.045, ink)

    ring("Belt", bob, (0, 0, 0.82), 0.225, 0.018, ink)

    shoulder_l = joint("ShoulderL", bob, (0.27, 0, 1.30))
    ball("ShoulderCapL", shoulder_l, (0, 0, 0), (0.085, 0.085, 0.08), ink, 32, 16)
    ball("ArmL", shoulder_l, (0, 0, -0.22), (0.065, 0.07, 0.22), ink)
    hand_l = joint("HandL", shoulder_l, (0, 0, -0.44))
    ball("PalmL", hand_l, (0, 0, 0), (0.07, 0.07, 0.06), cream, 32, 16)

    shoulder_r = joint("ShoulderR", bob, (-0.27, 0, 1.30))
    ball("ShoulderCapR", shoulder_r, (0, 0, 0), (0.085, 0.085, 0.08), ink, 32, 16)
    ball("ArmR", shoulder_r, (0, 0, -0.22), (0.065, 0.07, 0.22), ink)
    hand_r = joint("HandR", shoulder_r, (0, 0, -0.44))
    ball("PalmR", hand_r, (0, 0, 0), (0.07, 0.07, 0.06), cream, 32, 16)

    lantern = joint("Lantern", hand_r, (0, -0.02, -0.02))
    ring("LanternHandle", lantern, (0, 0, -0.03), 0.10, 0.021, ink, rotation=(math.pi / 2, 0, 0))
    drum("LanternCap", lantern, (0, 0, -0.13), 0.08, 0.035, ink)
    drum("LanternGlass", lantern, (0, 0, -0.23), 0.075, 0.16, lime, vertices=48)
    drum("LanternBase", lantern, (0, 0, -0.33), 0.085, 0.035, ink)

    hip_l = joint("HipL", bob, (0.13, 0, 0.72))
    ball("ThighL", hip_l, (0, 0, -0.18), (0.085, 0.09, 0.19), ink)
    knee_l = joint("KneeL", hip_l, (0, 0, -0.36))
    ball("ShinL", knee_l, (0, 0, -0.17), (0.075, 0.08, 0.17), ink)
    ball("BootL", knee_l, (0, -0.03, -0.30), (0.095, 0.14, 0.06), cream)

    hip_r = joint("HipR", bob, (-0.13, 0, 0.72))
    ball("ThighR", hip_r, (0, 0, -0.18), (0.085, 0.09, 0.19), ink)
    knee_r = joint("KneeR", hip_r, (0, 0, -0.36))
    ball("ShinR", knee_r, (0, 0, -0.17), (0.075, 0.08, 0.17), ink)
    ball("BootR", knee_r, (0, -0.03, -0.30), (0.095, 0.14, 0.06), cream)

    target = joint("CameraTarget", None, (0, 0, 1.08))

    camera_data = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.data.lens = 45
    camera.location = (CAMERA_KEYS[0][1][0], CAMERA_KEYS[0][1][1], 1.08 + CAMERA_KEYS[0][1][2])
    track_to(camera, target)
    scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(4.5, -5.5, 6.0))
    key = bpy.context.object
    key.name = "Key"
    key.data.energy = 1300
    key.data.size = 1.5
    key.data.color = (1.0, 0.95, 0.88)
    track_to(key, target)

    bpy.ops.object.light_add(type="AREA", location=(-5.5, -3.5, 3.2))
    fill = bpy.context.object
    fill.name = "Fill"
    fill.data.energy = 130
    fill.data.size = 6.0
    fill.data.color = (0.78, 0.86, 1.0)
    track_to(fill, target)

    bpy.ops.object.light_add(type="AREA", location=(-3.2, 4.2, 5.0))
    rim = bpy.context.object
    rim.name = "Rim"
    rim.data.energy = 1000
    rim.data.size = 2.0
    rim.data.color = (1.0, 0.98, 0.92)
    track_to(rim, target)

    light_data = bpy.data.lights.new("LanternGlow", type="POINT")
    light_data.color = (0.66, 1.0, 0.28)
    light_data.energy = 25
    light_data.shadow_soft_size = 0.12
    lantern_light = bpy.data.objects.new("LanternGlow", light_data)
    scene.collection.objects.link(lantern_light)
    lantern_light.parent = lantern
    lantern_light.location = (0, -0.16, -0.23)

    world = bpy.data.worlds.new("Studio")
    scene.world = world
    world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    background.inputs[0].default_value = (0.95, 0.91, 0.83, 1.0)
    background.inputs[1].default_value = 0.50

    rig = {
        "root": root,
        "bob": bob,
        "head": head,
        "hip_l": hip_l,
        "hip_r": hip_r,
        "knee_l": knee_l,
        "knee_r": knee_r,
        "shoulder_l": shoulder_l,
        "shoulder_r": shoulder_r,
        "lantern": lantern,
        "lantern_light": lantern_light,
        "camera": camera,
        "target": target,
    }

    animate(rig, frames, mode)

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
    scene.view_settings.exposure = -0.7

    if engine.upper().startswith("CYCLES"):
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 48
        scene.cycles.use_denoising = True
        scene.cycles.device = "CPU"
    else:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
        try:
            scene.eevee.taa_render_samples = args.samples
        except Exception:
            pass
        try:
            scene.eevee.use_raytracing = True
        except Exception:
            pass

    return scene, rig


def set_key(obj, path, frame):
    obj.keyframe_insert(path, frame=frame)


def animate(rig, frames: int, mode: str) -> None:
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"
    root = rig["root"]
    bob = rig["bob"]
    head = rig["head"]
    lantern = rig["lantern"]
    target = rig["target"]
    camera = rig["camera"]

    walk_start, walk_end = (1, frames) if mode == "loop" else (WALK_START, WALK_END)

    for frame in range(1, frames + 1):
        if mode == "loop":
            progress = (frame - 1) / max(1, frames - 1)
            envelope = 1.0
            root_y = 0.0
            lift_amount = 0.0
        else:
            progress = (frame - walk_start) / (walk_end - walk_start)
            progress = min(1.0, max(0.0, progress))
            envelope = smoothstep(walk_start, walk_start + 8, frame) * (
                1.0 - smoothstep(walk_end - 8, walk_end, frame)
            )
            root_y = -ROOT_TRAVEL * smoothstep(walk_start, walk_end, frame)
            lift_amount = smoothstep(LIFT_START, LIFT_END, frame)

        phase = math.tau * STEPS * progress
        swing = math.sin(phase)

        root.location = (0, root_y, 0)
        set_key(root, "location", frame)

        bob.location = (0, 0, 0.032 * envelope * (1.0 - math.cos(2 * phase)) * 0.5)
        bob.rotation_euler = (0, 0, 0.05 * envelope * swing)
        set_key(bob, "location", frame)
        set_key(bob, "rotation_euler", frame)

        hip_l = rig["hip_l"]
        hip_r = rig["hip_r"]
        hip_l.rotation_euler = (0.42 * envelope * swing, 0, 0)
        hip_r.rotation_euler = (-0.42 * envelope * swing, 0, 0)
        set_key(hip_l, "rotation_euler", frame)
        set_key(hip_r, "rotation_euler", frame)

        rig["knee_l"].rotation_euler = (0.55 * envelope * max(0.0, -math.sin(phase + 0.5)), 0, 0)
        rig["knee_r"].rotation_euler = (0.55 * envelope * max(0.0, math.sin(phase + 0.5)), 0, 0)
        set_key(rig["knee_l"], "rotation_euler", frame)
        set_key(rig["knee_r"], "rotation_euler", frame)

        shoulder_l = rig["shoulder_l"]
        shoulder_r = rig["shoulder_r"]
        shoulder_l.rotation_euler = (-0.38 * envelope * swing, 0, 0)
        shoulder_r_x = 0.16 * envelope * swing - 0.3 * lift_amount
        shoulder_r.rotation_euler = (shoulder_r_x, 2.3 * lift_amount, 0)
        set_key(shoulder_l, "rotation_euler", frame)
        set_key(shoulder_r, "rotation_euler", frame)

        lantern.rotation_euler = (
            -0.88 * shoulder_r_x,
            -2.05 * lift_amount,
            0.06 * envelope * swing,
        )
        set_key(lantern, "rotation_euler", frame)

        head_turn = -0.18 * smoothstep(100, 116, frame) if mode == "film" else 0.0
        head.rotation_euler = (-0.14 * lift_amount, 0, head_turn)
        set_key(head, "rotation_euler", frame)

        rig["lantern_light"].data.energy = 20 + 55 * lift_amount
        rig["lantern_light"].data.keyframe_insert("energy", frame=frame)

        target.location = (0, root_y, 1.08 + 0.05 * lift_amount)
        set_key(target, "location", frame)

        offset_x, offset_y, offset_z = camera_offset(frame)
        camera.location = (offset_x, root_y + offset_y, 1.08 + offset_z + 0.05 * lift_amount)
        set_key(camera, "location", frame)


def check(scene, rig) -> None:
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    lights = [obj for obj in scene.objects if obj.type == "LIGHT"]
    print(f"CHECK meshes={len(meshes)} lights={len(lights)} camera={scene.camera.name}")
    print(f"CHECK frames={scene.frame_start}-{scene.frame_end} fps={scene.render.fps}")
    print(f"CHECK engine={scene.render.engine} resolution={scene.render.resolution_x}x{scene.render.resolution_y}")
    print(f"CHECK keeper height=2.05 lantern={rig['lantern'].name}")


def export_glb(root, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)
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
    if args.export_glb:
        _, rig = build_scene(args.width, args.height, args.frames_end, args.engine, "loop")
        export_glb(rig["root"], args.export_glb)
        return

    scene, rig = build_scene(args.width, args.height, args.frames_end, args.engine, "film")
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
