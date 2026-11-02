"""Shot 02: the portrait breathes while light moves across the face.

The plate is the owner's own photograph. A wide plate crop is expected from
portrait.py; until it exists the full portrait stands in, framed tight. The
mesh is subdivided and displaced by the generated depth map, so the camera
orbit produces real parallax inside the photograph instead of a sliding card.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy

import film_common as film

PLATE = film.PRIVATE / "portrait_plate.png"
DEPTH = film.PRIVATE / "portrait_plate_depth.png"


def source() -> Path:
    if PLATE.exists():
        return PLATE
    fallback = film.PRIVATE / "portrait.png"
    if not fallback.exists():
        raise SystemExit(f"missing portrait plate: {PLATE}")
    return fallback


def plate(scene, image_path: Path) -> bpy.types.Object:
    loaded = bpy.data.images.load(str(image_path), check_existing=True)
    aspect = loaded.size[0] / loaded.size[1]
    height = 0.62
    width = height * aspect
    if width < 1.62:
        # Keep the photograph comfortably wider than the 2.4 frame so the lens
        # crops it through the whole move and no plate edge enters shot.
        width = 1.62
        height = width / aspect

    bpy.ops.mesh.primitive_grid_add(x_subdivisions=384, y_subdivisions=160, size=1.0, location=(0.0, 0.0, 1.30))
    obj = bpy.context.object
    obj.name = "PortraitPlate"
    obj.rotation_euler = (math.radians(90), 0.0, 0.0)
    obj.scale = (width, height, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    film.smooth(obj, 20.0)

    mat = film.textured_material("PortraitPlateMat", image_path, emission_strength=0.03, roughness=0.46)
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    grain = nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 220.0
    grain.inputs["Detail"].default_value = 3.0
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.04
    links.new(grain.outputs["Fac"], bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    obj.data.materials.append(mat)

    if DEPTH.exists():
        depth = bpy.data.images.load(str(DEPTH), check_existing=True)
        depth.colorspace_settings.name = "Non-Color"
        texture = bpy.data.textures.new("PortraitDepth", type="IMAGE")
        texture.image = depth
        texture.extension = "EXTEND"
        displace = obj.modifiers.new("Depth", "DISPLACE")
        displace.texture = texture
        displace.texture_coords = "UV"
        displace.mid_level = 0.5
        displace.strength = 0.016
    else:
        print(f"NOTE {DEPTH.name} missing; rendering the plate flat")

    return obj


def build(scene, args):
    image_path = source()
    obj = plate(scene, image_path)
    film.haze(scene, size=(6.0, 6.0, 3.2), density=0.004, color=(1.0, 0.86, 0.68))
    film.world(scene, color=(0.008, 0.009, 0.012), strength=0.15)

    sweep = film.area_light(
        "Sweep", (1.45, -1.30, 2.05), (0.0, 0.0, 1.34),
        energy=60, size=1.1, color=(1.0, 0.73, 0.46),
    )
    film.area_light(
        "Fill", (-1.30, -1.55, 1.05), (0.0, 0.0, 1.30),
        energy=9, size=1.6, color=(0.50, 0.64, 1.0),
    )
    film.area_light(
        "BackRim", (0.40, 1.35, 1.95), (0.0, 0.0, 1.35),
        energy=28, size=1.1, color=(1.0, 0.55, 0.28),
    )

    motes = film.dust(scene, count=28, center=(0.0, -0.72, 1.30), spread=(1.6, 0.42, 0.6), seed=13)

    film.keyframe(sweep, "location", 1, (1.45, -1.30, 2.05))
    film.keyframe(sweep, "location", 108, (0.20, -1.55, 2.20))
    film.keyframe(sweep, "location", 216, (-1.25, -1.30, 1.95))
    film.ease(sweep)

    film.keyframe(obj, "scale", 1, (1.0, 1.0, 1.0))
    film.keyframe(obj, "scale", 54, (1.0032, 1.0032, 1.0))
    film.keyframe(obj, "scale", 108, (1.0, 1.0, 1.0))
    film.keyframe(obj, "scale", 162, (1.0032, 1.0032, 1.0))
    film.keyframe(obj, "scale", 216, (1.0, 1.0, 1.0))
    film.ease(obj)

    film.keyframe(obj, "rotation_euler", 1, (math.radians(90), 0.0, math.radians(-0.9)))
    film.keyframe(obj, "rotation_euler", 216, (math.radians(90), 0.0, math.radians(0.9)))
    film.ease(obj)

    focus = film.empty("PortraitFocus", (0.0, -0.02, 1.35))
    rig = film.camera(
        (0.0, -2.05, 1.31), (0.0, 0.0, 1.31),
        lens=50, fstop=1.9, focus=focus,
    )
    camera, target = rig["camera"], rig["target"]
    # Push in and out without sweeping sideways: the parallax comes from the
    # depth mesh and the plate's own yaw, so the photograph's edge stays hidden.
    film.keyframe(camera, "location", 1, (-0.02, -2.10, 1.30))
    film.keyframe(camera, "location", 108, (0.0, -2.00, 1.32))
    film.keyframe(camera, "location", 216, (0.02, -2.07, 1.31))
    film.keyframe(target, "location", 1, (0.0, 0.0, 1.31))
    film.keyframe(target, "location", 216, (0.0, 0.0, 1.33))
    film.ease(camera)
    film.ease(target)

    film.keyframe(motes, "location", 1, (0.0, -0.72, 1.25))
    film.keyframe(motes, "location", 216, (0.0, -0.60, 1.38))
    film.keyframe(motes, "rotation_euler", 1, (0.0, 0.0, 0.0))
    film.keyframe(motes, "rotation_euler", 216, (0.0, 0.0, math.radians(5)))
    film.ease(motes)

    return {"camera": camera, "plate": obj, "sweep": sweep, "focus": focus}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
