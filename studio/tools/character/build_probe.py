"""Build the character probe asset: MHR body, eyes, hair and baked skin.

Runs inside Blender 4.5 headless. The MHR base is Apache-2.0 and lives in the
ignored embed lane; the generated GLB is a probe, not a shipped asset yet.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector, kdtree

# Keep only targets the probe can actually drive. Names become glTF morph names.
BODY_SHAPES = {
    "shape_0": "body_frame",
    "shape_1": "body_width",
    "shape_2": "body_belly",
    "shape_3": "body_chest",
    "shape_4": "body_shoulders",
    "shape_5": "body_waist",
    "shape_6": "body_upperchest",
    "shape_7": "body_bust",
    "shape_8": "body_hips",
    "shape_9": "body_pelvis",
}
HEAD_SHAPES = {
    "shape_20": "face_jaw",
    "shape_21": "face_chin",
    "shape_22": "face_midface",
    "shape_23": "face_mouth",
    "shape_24": "face_forehead",
    "shape_25": "face_nose",
    "shape_26": "face_eyes",
    "shape_27": "face_brow",
    "shape_28": "face_cheeks",
    "shape_29": "face_nosewidth",
    "shape_30": "face_lips",
    "shape_31": "face_jawwidth",
    "shape_32": "face_mouth2",
}
EXPRESSION_SHAPES = {
    "shape_57": "expr_eyesclosed_L",
    "shape_58": "expr_eyesclosed_R",
    "shape_69": "expr_jawdrop",
    "shape_77": "expr_smile_L",
    "shape_78": "expr_smile_R",
    "shape_67": "expr_innerbrow_L",
    "shape_68": "expr_innerbrow_R",
    "shape_111": "expr_outerbrow_L",
    "shape_112": "expr_outerbrow_R",
    "shape_113": "expr_upperlid_L",
    "shape_114": "expr_upperlid_R",
    "shape_65": "expr_lookup_L",
    "shape_66": "expr_lookup_R",
}
KEEP = {**BODY_SHAPES, **HEAD_SHAPES, **EXPRESSION_SHAPES}

# The MHR base already has lids. These landmarks bound the lens-shaped run of
# triangles that closes the opening, measured from the mesh creases in cm.
LID_MID_Y = 162.18
LID_INNER_X = 1.70
LID_OUTER_X = 4.70
IRIS_RADIUS = 0.565
CORNEA_RADIUS = 0.72
MOUTH_CORNER_X = 2.42
DEFAULT_FACE = {"face_jaw": -0.55, "face_cheeks": -0.5, "face_jawwidth": -0.35, "body_frame": -1.6}
FEATURE_KEYS = ("feat_lips", "feat_nose_wide", "feat_nose_bridge", "feat_cheeks")
BUILD_KEYS = ("build_female", "build_male")
# Upper arm, forearm and clavicle rotations for a relaxed stance, in degrees.
ARM_POSE = {"clavicle": -5.0, "uparm": -31.0, "lowarm": -22.0}
ARM_RIG: dict = {}
REST_CO: np.ndarray | None = None

HAIRLINE_Y = 167.7
HAIR_WHORL = np.array([-1.6, 171.6, -3.6])
HAIR_STRANDS = 16000
HAIR_CLUMPS = 900
AFRO_RADIUS = 14.4



def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--bake", action="store_true")
    parser.add_argument("--bake-ao", action="store_true")
    parser.add_argument("--hair-only", action="store_true")
    parser.add_argument("--styles", default=None, help="comma separated hair styles to regenerate")
    return parser.parse_args(argv)


def new_image(name: str, size: int, colorspace: str = "sRGB", alpha: bool = False):
    image = bpy.data.images.new(name, size, size, alpha=alpha)
    image.colorspace_settings.name = colorspace
    return image


def save_image(image, path: Path, fmt: str = "PNG", quality: int = 92) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = fmt
    if fmt == "JPEG":
        image.save_render(str(path), scene=bpy.context.scene)
    else:
        image.save()


def read_pixels(image) -> np.ndarray:
    width, height = image.size
    pixels = np.empty(width * height * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return pixels.reshape(height, width, 4)


def write_pixels(image, pixels: np.ndarray) -> None:
    image.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    image.update()



def generate_iris_texture(path: Path) -> None:
    size = 512
    rng = np.random.default_rng(5)
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    dx = (xx - cx) / (size * 0.5)
    dy = (yy - cy) / (size * 0.5)
    radius = np.sqrt(dx * dx + dy * dy)
    angle = np.arctan2(dy, dx)

    def fibres(count, seed, drift):
        table = np.random.default_rng(seed).random(count)
        at = (angle / math.tau + 0.5 + drift * np.sin(radius * 9.0 + angle * 3.0)) * count
        low = np.floor(at).astype(np.int64) % count
        high = (low + 1) % count
        f = at - np.floor(at)
        return table[low] * (1.0 - f) + table[high] * f

    fibre = 0.45 * fibres(120, 5, 0.003) + 0.55 * fibres(420, 6, 0.005)
    crypts = np.clip(fibres(70, 7, 0.004) * 2.2 - 1.2, 0.0, 1.0) * np.exp(-((radius - 0.60) / 0.16) ** 2)
    value = 0.60 + 0.55 * (fibre - 0.5) - 0.18 * crypts
    base = np.stack((0.80 * value, 0.74 * value, 0.68 * value), axis=-1)
    collar = np.exp(-((radius - 0.37) / 0.11) ** 2)[..., None]
    base = base * (1.0 - 0.55 * collar) + np.array([0.96, 0.84, 0.62]) * (0.55 + 0.8 * fibre[..., None]) * 0.55 * collar
    limbal = ss(0.80, 0.97, radius)[..., None]
    base = base * (1.0 - 0.80 * limbal) + np.array([0.13, 0.11, 0.10]) * 0.80 * limbal
    pupil = ss(0.285, 0.255, radius)[..., None]
    base = base * (1.0 - pupil) + np.array([0.006, 0.006, 0.007]) * pupil
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(base, 0, 1)
    image = new_image("iris", size, "sRGB")
    write_pixels(image, rgba)
    save_image(image, path)


def simple_material(
    name: str, color, roughness: float = 0.5, texture=None, alpha: bool = False
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    if texture is not None:
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = texture
        links.new(image_node.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            links.new(image_node.outputs["Alpha"], bsdf.inputs["Alpha"])
            material.surface_render_method = "DITHERED"
    return material


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def read_arm_rig(body) -> None:
    """Sum each vertex's skin weights into the arm chain states the pose needs."""
    armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    bones = armature.data.bones
    states = {}
    for group in body.vertex_groups:
        bone = bones.get(group.name)
        chain = []
        while bone is not None:
            chain.append(bone.name)
            bone = bone.parent
        side = "l" if f"l_clavicle" in chain else "r" if "r_clavicle" in chain else None
        if side is None:
            continue
        for part in ("lowarm", "uparm", "clavicle"):
            if f"{side}_{part}" in chain:
                states[group.index] = (side, part)
                break
    pivots = {}
    for side in "lr":
        for part in ("clavicle", "uparm", "lowarm"):
            pivots[(side, part)] = np.array(bones[f"{side}_{part}"].head_local)
    count = len(body.data.vertices)
    weights = {key: np.zeros(count) for key in pivots}
    for vertex in body.data.vertices:
        for element in vertex.groups:
            state = states.get(element.group)
            if state is not None:
                weights[state][vertex.index] += element.weight
    ARM_RIG.update(pivots=pivots, weights=weights)


def rotate_z(points, pivot, degrees):
    angle = math.radians(degrees)
    c, s = math.cos(angle), math.sin(angle)
    moved = points - pivot
    x = moved[:, 0] * c - moved[:, 1] * s
    y = moved[:, 0] * s + moved[:, 1] * c
    return np.stack((x, y, moved[:, 2]), axis=1) + pivot


def pose_points(points):
    """Linear blend skinning for the arm chains, about z in the rest frame."""
    posed = points.copy()
    for side, sign in (("l", 1.0), ("r", -1.0)):
        pivots = ARM_RIG["pivots"]
        weights = ARM_RIG["weights"]
        clav = (side, "clavicle")
        up = (side, "uparm")
        low = (side, "lowarm")

        def after_clav(p):
            return rotate_z(p, pivots[clav], sign * ARM_POSE["clavicle"])

        def after_up(p):
            return after_clav(rotate_z(p, pivots[up], sign * ARM_POSE["uparm"]))

        def after_low(p):
            return after_up(rotate_z(p, pivots[low], sign * ARM_POSE["lowarm"]))

        for state, transform in ((clav, after_clav), (up, after_up), (low, after_low)):
            w = weights[state][:, None]
            posed += w * (transform(points) - points)
    return posed


def pose_body(body) -> None:
    """Relax the arms out of the capture pose, in the basis and every key."""
    global REST_CO
    keys = body.data.shape_keys.key_blocks
    count = len(body.data.vertices)
    REST_CO, _ = body_arrays(body)
    REST_CO = REST_CO.copy()
    for block in keys:
        values = np.empty(count * 3)
        block.data.foreach_get("co", values)
        block.data.foreach_set("co", pose_points(values.reshape(-1, 3)).ravel())
    body.data.vertices.foreach_set("co", pose_points(REST_CO).ravel())
    body.data.update()
    co, _ = body_arrays(body)
    print(f"posed arms, hand now at {co[np.abs(co[:, 0]).argmax()].round(1)}")


def add_key(body, name: str, delta: np.ndarray) -> None:
    co, _ = body_arrays(body)
    key = body.shape_key_add(name=name, from_mix=False)
    key.data.foreach_set("co", (co + delta).ravel())
    key.value = 0.0


def add_build_keys(body) -> None:
    """Female and male structure, sculpted from the frame's real landmarks.

    MHR's identity space has no sex axis, so these are authored directly: pelvis,
    ribcage, shoulder girdle, neck and limb mass. Nothing above the jaw moves, so
    the eyes and hair stay seated.
    """
    co, normals = body_arrays(body)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    side = np.sign(x)

    def band(centre, sigma):
        return np.exp(-(((y - centre) / sigma) ** 2))

    torso = ss(30.0, 22.0, ax) * ss(70.0, 78.0, y) * ss(158.0, 150.0, y)
    # In the rest pose the arm runs out from the shoulder, so the limb mask is
    # everything past the shoulder line and above the thigh.
    arm = ss(19.0, 24.0, ax) * ss(98.0, 110.0, y)
    legs = ss(82.0, 70.0, y)
    upper = ss(14.0, 20.0, ax) * ss(122.0, 132.0, y)
    neck = ss(147.0, 150.0, y) * ss(157.5, 154.0, y)
    jaw = ss(146.0, 150.0, y) * ss(159.0, 155.0, y)
    chest_front = ss(0.0, 5.0, z)

    delta = np.zeros_like(co)
    # Waist in, pelvis out, softer rear and thigh; narrower shoulder girdle.
    delta[:, 0] += x * (-0.125 * band(110.0, 8.5) + 0.075 * band(90.0, 8.0) - 0.055 * band(138.0, 9.0)) * torso
    delta[:, 2] += z * (-0.07 * band(110.0, 8.0)) * torso
    delta[:, 2] += np.minimum(z, 0.0) * 0.09 * band(88.0, 7.0) * torso
    delta[:, 0] += -side * 1.9 * upper
    delta += -normals * (0.34 * arm + 0.08 * legs)[:, None]
    delta[:, [0, 2]] += co[:, [0, 2]] * (-0.10 * neck)[:, None]
    delta[:, 0] += x * (-0.045 * jaw)
    for sx in (1.0, -1.0):
        bust = np.exp(-(((x - sx * 8.3) / 5.0) ** 2 + ((y - 127.5) / 4.8) ** 2)) * chest_front * torso
        delta[:, 2] += 1.5 * bust
        delta[:, 1] += -0.35 * bust
    add_key(body, "build_female", delta)

    delta = np.zeros_like(co)
    # Broad shoulders, deep chest, a straighter line from ribs to hip, thicker neck.
    delta[:, 0] += x * (0.065 * band(136.0, 9.0) - 0.04 * band(106.0, 9.0) - 0.05 * band(90.0, 8.0)) * torso
    delta[:, 2] += z * (0.055 * band(130.0, 9.0) - 0.045 * band(106.0, 9.0)) * torso
    delta[:, 0] += side * 2.4 * upper
    delta += normals * (0.42 * arm + 0.16 * legs)[:, None]
    delta[:, [0, 2]] += co[:, [0, 2]] * (0.11 * neck)[:, None]
    delta[:, 0] += x * (0.02 * jaw)
    add_key(body, "build_male", delta)


def add_feature_keys(body) -> None:
    """Lips, nose and cheekbones with more reach than the identity space offers.

    These are ranges, not one face: every slider goes both ways.
    """
    co, _ = body_arrays(body)
    x, y, z = co[:, 0], co[:, 1], co[:, 2]
    ax = np.abs(x)
    face = z > 7.0

    xs, ys = mouth_curve(body)
    line = np.interp(ax, xs, ys)
    lip_mask = ss(3.2, 2.0, ax) * np.exp(-(((y - line) / 1.7) ** 2)) * face
    delta = np.zeros_like(co)
    # Fuller: vermilion rolls outward, grows away from the mouth line, and widens.
    delta[:, 1] += (y - line) * 0.36 * lip_mask
    delta[:, 2] += 0.36 * lip_mask * ss(0.0, 0.5, np.abs(y - line))
    delta[:, 0] += x * 0.05 * lip_mask
    add_key(body, "feat_lips", delta)

    nose = np.exp(-(((y - 158.4) / 1.25) ** 2)) * ss(3.6, 1.6, ax) * (z > 11.0)
    delta = np.zeros_like(co)
    delta[:, 0] += np.sign(x) * ss(0.2, 1.6, ax) * 0.62 * nose
    delta[:, 2] += -0.10 * nose * ss(0.0, 1.0, ax)
    add_key(body, "feat_nose_wide", delta)

    bridge = np.exp(-(((y - 161.0) / 1.5) ** 2)) * ss(1.7, 0.2, ax) * (z > 11.0)
    tip = np.exp(-(((y - 159.2) / 0.8) ** 2)) * ss(1.5, 0.2, ax) * (z > 12.0)
    delta = np.zeros_like(co)
    delta[:, 2] += -0.42 * bridge - 0.16 * tip
    add_key(body, "feat_nose_bridge", delta)

    cheek = np.exp(-(((ax - 4.9) / 1.9) ** 2 + ((y - 159.0) / 1.25) ** 2)) * (z > 6.0)
    delta = np.zeros_like(co)
    delta[:, 0] += np.sign(x) * 0.16 * cheek
    delta[:, 2] += 0.34 * cheek
    delta[:, 1] += 0.08 * cheek
    add_key(body, "feat_cheeks", delta)


def import_body(source: Path) -> bpy.types.Object:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(source))
    body = bpy.data.objects.get("body_mesh")
    if body is None:
        body = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    read_arm_rig(body)
    world = body.matrix_world.copy()
    body.parent = None
    body.matrix_world = world
    for modifier in list(body.modifiers):
        body.modifiers.remove(modifier)
    for obj in list(bpy.context.scene.objects):
        if obj != body:
            bpy.data.objects.remove(obj, do_unlink=True)

    uv = body.data.uv_layers.get("Attribute") or body.data.uv_layers[0]
    uv.name = "UVMap"
    uv.active_render = True
    body.data.uv_layers.active = uv

    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_smooth()

    keys = body.data.shape_keys.key_blocks
    for block in list(keys):
        if block.name == "Basis":
            continue
        if block.name in KEEP:
            block.name = KEEP[block.name]
        else:
            body.shape_key_remove(block)
    for block in body.data.shape_keys.key_blocks:
        block.value = 0.0
    body.data.update()
    print(f"body verts={len(body.data.vertices)} keys={len(body.data.shape_keys.key_blocks)}")
    return body


def ss(edge0, edge1, value):
    """Vectorised smoothstep. Accepts reversed edges."""
    t = np.clip((np.asarray(value, dtype=np.float64) - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mesh_object(name, verts, faces, uvs=None, material=None, matrix=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(map(int, f)) for f in faces])
    mesh.update()
    if uvs is not None:
        layer = mesh.uv_layers.new(name="UVMap")
        for loop in mesh.loops:
            layer.data[loop.index].uv = uvs[loop.vertex_index]
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if matrix is not None:
        obj.matrix_world = matrix
    if material is not None:
        mesh.materials.append(material)
    return obj


def body_arrays(body):
    mesh = body.data
    count = len(mesh.vertices)
    co = np.empty(count * 3)
    mesh.vertices.foreach_get("co", co)
    normals = np.empty(count * 3)
    mesh.vertices.foreach_get("normal", normals)
    return co.reshape(-1, 3), normals.reshape(-1, 3)


def key_deltas(body, names):
    keys = body.data.shape_keys.key_blocks
    count = len(body.data.vertices)
    basis = np.empty(count * 3)
    keys["Basis"].data.foreach_get("co", basis)
    deltas = {}
    for name in names:
        values = np.empty(count * 3)
        keys[name].data.foreach_get("co", values)
        deltas[name] = (values - basis).reshape(-1, 3)
    return deltas


def add_follow_keys(obj, deltas, sources, weights):
    """Give a mesh the body's shape keys, driven by weighted body vertices."""
    mesh = obj.data
    count = len(mesh.vertices)
    co = np.empty(count * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    obj.shape_key_add(name="Basis", from_mix=False)
    for name, delta in deltas.items():
        key = obj.shape_key_add(name=name, from_mix=False)
        moved = co + (delta[sources] * weights[..., None]).sum(axis=1)
        key.data.foreach_set("co", moved.ravel())
        key.value = 0.0


def slim_lower_face(body) -> None:
    """Bake a leaner jaw and cheek into the basis and every key.

    The default MHR identity reads as heavy-set. The mask stops below the eyes:
    lid, hairline and brow landmarks are measured from the unmodified upper head.
    """
    co, _ = body_arrays(body)
    deltas = key_deltas(body, list(DEFAULT_FACE))
    # Below the eyes everything may move; the face keys stop at the neck, the
    # frame key carries on down the whole body.
    upper = ss(161.0, 157.0, co[:, 1])[:, None]
    neck = ss(145.5, 150.0, co[:, 1])[:, None]
    shift = 0.0
    for name, weight in DEFAULT_FACE.items():
        shift = shift + deltas[name] * weight * upper * (1.0 if name == "body_frame" else neck)
    keys = body.data.shape_keys.key_blocks
    count = len(co)
    for block in keys:
        values = np.empty(count * 3)
        block.data.foreach_get("co", values)
        block.data.foreach_set("co", (values.reshape(-1, 3) + shift).ravel())
    body.data.vertices.foreach_set("co", (co + shift).ravel())
    body.data.update()
    print(f"default build baked, largest shift {np.linalg.norm(shift, axis=1).max():.2f} cm")


def open_eyes(body) -> dict[float, np.ndarray]:
    """Delete the triangles spanning the lid opening. The mesh already has lids.

    MHR models a real almond aperture about 2.85 cm wide, then closes it with a
    few long triangles. Those are the only faces crossing the aperture mid line.
    Faces go, vertices stay, so every shape key index remains valid.
    """
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    doomed = []
    rims: dict[float, set[int]] = {1.0: set(), -1.0: set()}
    for face in bm.faces:
        ys = [v.co.y for v in face.verts]
        ax = sum(abs(v.co.x) for v in face.verts) / len(ys)
        if min(ys) >= LID_MID_Y or max(ys) <= LID_MID_Y:
            continue
        if not (LID_INNER_X < ax < LID_OUTER_X):
            continue
        if min(ys) < 161.6 or max(ys) > 162.95 or min(v.co.z for v in face.verts) < 10.8:
            continue
        doomed.append(face)
        side = 1.0 if face.calc_center_median().x > 0 else -1.0
        rims[side].update(v.index for v in face.verts)
    bmesh.ops.delete(bm, geom=doomed, context="FACES_ONLY")
    bm.to_mesh(body.data)
    bm.free()
    body.data.update()
    co, _ = body_arrays(body)
    result = {}
    for side, indices in rims.items():
        rim = np.array(sorted(indices))
        centre = co[rim, :2].mean(axis=0)
        order = np.argsort(np.arctan2(co[rim, 1] - centre[1], (co[rim, 0] - centre[0]) * side))
        result[side] = rim[order]
        print(
            f"eye {side:+.0f}: rim verts={len(rim)} x={co[rim, 0].min():.2f}..{co[rim, 0].max():.2f} "
            f"y={co[rim, 1].min():.2f}..{co[rim, 1].max():.2f} z={co[rim, 2].min():.2f}..{co[rim, 2].max():.2f}"
        )
    print(f"opened eyes, removed {len(doomed)} faces")
    return result


def generate_sclera_texture(path: Path) -> None:
    """Planar map over the eye shell: u runs from tear duct to outer corner."""
    size = 512
    rng = np.random.default_rng(19)
    yy, xx = np.mgrid[0:size, 0:size]
    u = xx / (size - 1)
    v = yy / (size - 1)
    base = np.ones((size, size, 3), dtype=np.float32) * np.array([0.67, 0.61, 0.565], dtype=np.float32)
    vein = np.zeros((size, size), dtype=np.float32)
    for _ in range(34):
        x = rng.uniform(0, size)
        y = rng.uniform(size * 0.15, size * 0.85)
        heading = 0.0 if x > size / 2 else math.pi
        strength = rng.uniform(0.10, 0.30)
        for _step in range(rng.integers(40, 120)):
            heading += rng.uniform(-0.35, 0.35)
            x += math.cos(heading) * 1.4
            y += math.sin(heading) * 1.4
            if 0 <= int(x) < size and 0 <= int(y) < size:
                vein[int(y), int(x)] = max(vein[int(y), int(x)], strength)
    fade = np.abs(u - 0.5)[..., None] * 2.0
    base = base * (1 - vein[..., None] * fade) + np.array([0.66, 0.30, 0.27]) * vein[..., None] * fade
    # Both corners are wet pink tissue, the tear duct more so, never white.
    inner = ss(0.27, 0.13, u)[..., None]
    outer = ss(0.72, 0.87, u)[..., None]
    base = base * (1 - inner * 0.85) + np.array([0.70, 0.40, 0.37]) * inner * 0.85
    base = base * (1 - outer * 0.55) + np.array([0.60, 0.40, 0.36]) * outer * 0.55
    # The upper lid always shades the top of the eye.
    shade = (1.0 - 0.58 * ss(0.52, 0.72, v)) * (1.0 - 0.18 * ss(0.42, 0.30, v))
    base = base * shade[..., None]
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(base, 0, 1)
    image = new_image("sclera", size, "sRGB")
    write_pixels(image, rgba)
    save_image(image, path)


def build_eyes(body, rims: dict[float, np.ndarray], out_dir: Path) -> list:
    iris_path = out_dir / "iris.png"
    sclera_path = out_dir / "sclera.png"
    generate_iris_texture(iris_path)
    generate_sclera_texture(sclera_path)
    iris_mat = simple_material("Iris", (0.3, 0.15, 0.06), 0.3, bpy.data.images.load(str(iris_path)))
    sclera_mat = simple_material("Sclera", (0.85, 0.82, 0.78), 0.34, bpy.data.images.load(str(sclera_path)))
    cornea_mat = simple_material("Cornea", (0.0, 0.0, 0.0), 0.05)
    wet_mat = simple_material("Waterline", (0.62, 0.36, 0.32), 0.30)
    wet_mat.use_backface_culling = False
    lash_mat = simple_material("Lashes", (0.040, 0.026, 0.020), 0.6)
    lash_mat.use_backface_culling = False

    co, _ = body_arrays(body)
    matrix = body.matrix_world
    rigid_names = [n for n in KEEP.values() if not n.startswith("expr_")]
    rigid = key_deltas(body, rigid_names)
    all_deltas = key_deltas(body, list(HEAD_SHAPES.values()) + list(EXPRESSION_SHAPES.values()))
    skin_tree = kdtree.KDTree(int((co[:, 1] > 150).sum()))
    for index in np.where(co[:, 1] > 150)[0]:
        skin_tree.insert(co[index], int(index))
    skin_tree.balance()

    objects = []
    for side, rim in rims.items():
        tag = "L" if side > 0 else "R"
        rim_co = co[rim]
        cx = 0.5 * (rim_co[:, 0].min() + rim_co[:, 0].max())
        cy = 0.5 * (rim_co[:, 1].min() + rim_co[:, 1].max())
        out = (rim_co[:, 0] - cx) * side
        half_x = float(out.max() - out.min()) * 0.5
        half_y = float(rim_co[:, 1].max() - rim_co[:, 1].min()) * 0.5

        def surface(px, py):
            """Membrane through the rim, 0.6 mm behind it, domed in the middle."""
            dist = np.sqrt((rim_co[:, 0] - px) ** 2 + (rim_co[:, 1] - py) ** 2) + 0.012
            weight = dist ** -3.0
            membrane = float((rim_co[:, 2] * weight).sum() / weight.sum())
            radial = ((px - cx) / half_x) ** 2 + ((py - cy) / (half_y * 1.25)) ** 2
            return membrane - 0.06 + 0.17 * max(0.0, 1.0 - radial) ** 1.5

        # Shell: a height field over the aperture, dilated to tuck under the lid.
        def rim_distance(px, py):
            return np.sqrt(((rim_co[:, 0] - px) ** 2) + ((rim_co[:, 1] - py) ** 2)).min()

        polygon = rim_co[:, :2]
        def inside_rim(px, py):
            hit = False
            for i in range(len(polygon)):
                x1, y1 = polygon[i]
                x2, y2 = polygon[(i + 1) % len(polygon)]
                if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1:
                    hit = not hit
            return hit

        grid: dict[tuple[int, int], int] = {}
        verts, uvs, faces = [], [], []
        step_x, step_y = 0.075, 0.055
        for j in range(-18, 19):
            for i in range(-27, 28):
                px = cx + i * step_x * side
                py = cy + j * step_y
                inside = inside_rim(px, py)
                if not inside and rim_distance(px, py) > 0.24:
                    continue
                dx = (px - cx) * side
                dy = py - cy
                pz = surface(px, py)
                if not inside:
                    # Fold back under the lid so nothing pokes out past the rim.
                    pz -= 0.08 + 1.4 * rim_distance(px, py)
                grid[(i, j)] = len(verts)
                verts.append((px, py, pz))
                uvs.append((0.5 + dx / 4.0, 0.5 + dy / 2.0))
        for (i, j), a in grid.items():
            b, c, d = grid.get((i + 1, j)), grid.get((i + 1, j + 1)), grid.get((i, j + 1))
            if None not in (b, c, d):
                faces.append((a, b, c, d) if side > 0 else (d, c, b, a))
        shell = mesh_object(f"sclera_{tag}", verts, faces, uvs, sclera_mat, matrix)

        # Rests slightly high: the upper lid should cover the top of the iris.
        iris_x, iris_y = cx + 0.02 * side, cy + 0.075
        centre_z = surface(iris_x, iris_y)
        slope_x = (surface(iris_x + 0.3, iris_y) - surface(iris_x - 0.3, iris_y)) / 0.6
        slope_y = (surface(iris_x, iris_y + 0.2) - surface(iris_x, iris_y - 0.2)) / 0.4

        def radial(radius, offset, rings=10, segments=48):
            def place(px, py, r):
                plane = centre_z + slope_x * (px - iris_x) + slope_y * (py - iris_y)
                return (px, py, max(plane + offset(r), surface(px, py) + 0.010))

            cap_verts = [place(iris_x, iris_y, 0.0)]
            cap_uvs = [(0.5, 0.5)]
            cap_faces = []
            for ring in range(1, rings + 1):
                rr = ring / rings
                for seg in range(segments):
                    angle = math.tau * seg / segments
                    px = iris_x + radius * rr * math.cos(angle)
                    py = iris_y + radius * rr * math.sin(angle)
                    cap_verts.append(place(px, py, radius * rr))
                    cap_uvs.append((0.5 + 0.5 * rr * math.cos(angle), 0.5 + 0.5 * rr * math.sin(angle)))
            for seg in range(segments):
                cap_faces.append((0, 1 + seg, 1 + (seg + 1) % segments))
            for ring in range(1, rings):
                start = 1 + (ring - 1) * segments
                for seg in range(segments):
                    a = start + seg
                    b = start + (seg + 1) % segments
                    cap_faces.append((a, a + segments, b + segments, b))
            return cap_verts, cap_faces, cap_uvs

        def iris_height(r):
            return 0.018 - 0.05 * (r / IRIS_RADIUS) ** 2

        def cornea_height(r):
            return 0.020 + 0.060 * max(0.0, 1.0 - (r / CORNEA_RADIUS) ** 2) - 0.012 * (r / CORNEA_RADIUS) ** 2

        iris_verts, iris_faces, iris_uvs = radial(IRIS_RADIUS, iris_height)
        iris = mesh_object(f"iris_{tag}", iris_verts, iris_faces, iris_uvs, iris_mat, matrix)
        cornea_verts, cornea_faces, cornea_uvs = radial(CORNEA_RADIUS, cornea_height)
        cornea = mesh_object(f"cornea_{tag}", cornea_verts, cornea_faces, cornea_uvs, cornea_mat, matrix)

        # Eye parts stay rigid but ride along with face shape sliders.
        follow = {name: delta[rim].mean(axis=0, keepdims=True) for name, delta in rigid.items()}
        for part in (shell, iris, cornea):
            add_follow_keys(
                part, follow,
                np.zeros((len(part.data.vertices), 1), dtype=np.int64),
                np.ones((len(part.data.vertices), 1)),
            )

        # Waterline: the wet inner edge between the lid rim and the shell.
        strip_verts, strip_faces, strip_src = [], [], []
        for k, index in enumerate(rim):
            x, y, z = co[index]
            toward = np.array([cx - x, cy - y, 0.0])
            toward *= 0.05 / max(1e-6, float(np.linalg.norm(toward)))
            strip_verts.append((x, y, z))
            strip_verts.append(tuple(np.array([x, y, z - 0.20]) + toward))
            strip_src += [index, index]
            nxt = (k + 1) % len(rim)
            strip_faces.append((k * 2, nxt * 2, nxt * 2 + 1, k * 2 + 1))
        waterline = mesh_object(f"waterline_{tag}", strip_verts, strip_faces, None, wet_mat, matrix)
        add_follow_keys(
            waterline, all_deltas,
            np.array(strip_src, dtype=np.int64)[:, None],
            np.ones((len(strip_src), 1)),
        )

        # Lashes grow from the actual rim and inherit its blink.
        rng = np.random.default_rng(41 if side > 0 else 43)
        lash_verts, lash_faces, lash_src = [], [], []
        chord_slope = (rim_co[np.argmax(out), 1] - rim_co[np.argmin(out), 1]) / max(1e-3, out.max() - out.min())
        chord = rim_co[np.argmin(out), 1] + (out - out.min()) * chord_slope
        for upper, count, reach, width in ((True, 62, 0.56, 0.017), (False, 30, 0.24, 0.011)):
            lid = rim[(rim_co[:, 1] > chord) == upper]
            lid_co = co[lid]
            lid_out = (lid_co[:, 0] - cx) * side
            order = np.argsort(lid_out)
            lid, lid_co, lid_out = lid[order], lid_co[order], lid_out[order]
            if len(lid) < 3:
                continue
            for _ in range(count):
                s = rng.uniform(lid_out[0] + 0.12, lid_out[-1] - 0.04)
                point = np.array([np.interp(s, lid_out, lid_co[:, a]) for a in range(3)])
                source = int(lid[np.argmin(np.abs(lid_out - s))])
                along = (s - lid_out[0]) / (lid_out[-1] - lid_out[0])
                length = reach * rng.uniform(0.70, 1.05) * (0.55 + 0.45 * math.sin(math.pi * min(1.0, along * 0.92 + 0.08)) ** 0.5)
                fan = (along - 0.42) * 0.85 * side + rng.uniform(-0.09, 0.09)
                vertical = 1.0 if upper else -1.0
                heading = np.array([fan, 0.10 * vertical, 1.0])
                curl = np.array([fan * 0.10, 0.42 * vertical, -0.06])
                pos = point + np.array([0.0, 0.0, 0.015])
                start = len(lash_verts)
                segments = 4
                for step in range(segments + 1):
                    t = step / segments
                    half = 0.5 * width * (1.0 - t) ** 0.8 + 0.0015
                    direction = heading / np.linalg.norm(heading)
                    sideways = np.cross(direction, np.array([0.0, 0.0, 1.0]))
                    sideways /= max(1e-6, float(np.linalg.norm(sideways)))
                    lash_verts.append(tuple(pos - sideways * half))
                    lash_verts.append(tuple(pos + sideways * half))
                    lash_src += [source, source]
                    pos = pos + direction * length / segments
                    heading = heading + curl * 0.55
                for step in range(segments):
                    a = start + step * 2
                    lash_faces.append((a, a + 1, a + 3, a + 2))
        lashes = mesh_object(f"lashes_{tag}", lash_verts, lash_faces, None, lash_mat, matrix)
        add_follow_keys(
            lashes, all_deltas,
            np.array(lash_src, dtype=np.int64)[:, None],
            np.ones((len(lash_src), 1)),
        )
        objects += [shell, iris, cornea, waterline, lashes]
        print(f"eye {tag}: centre {cx:.2f} {cy:.2f} shell {len(verts)}v lashes {len(lash_verts)}v")
    return objects


def hair_density(x, y, z):
    """Where hair grows: 1 inside the scalp, 0 on skin, soft over about 7 mm."""
    x, y, z = np.asarray(x, float), np.asarray(y, float), np.asarray(z, float)
    ax = np.abs(x)
    wobble = 0.16 * np.sin(x * 2.3 + 1.0) + 0.09 * np.sin(x * 5.9) + 0.05 * np.sin(x * 13.0 + 2.0)
    line = HAIRLINE_Y + 1.05 * ss(2.2, 5.6, ax) + wobble
    front = y - line
    temple_z = 4.3 + 0.36 * np.clip(y - 161.0, 0.0, 12.0) + wobble * 0.8
    side = temple_z - z
    # Lower edge: nape behind the ear, over the ear, sideburn in front of it.
    lower = 156.0 + 7.8 * ss(-1.3, -0.1, z)
    lower = lower + (161.5 - lower) * ss(3.4, 4.4, z)
    lower = lower - 0.5 * ss(4.0, 0.0, ax) * ss(-2.0, -4.0, z)
    distance = np.minimum(np.maximum(front, side), y - lower + wobble * 0.6)
    density = ss(-0.25, 0.95, distance)
    return np.where((y < 150.0) | (ax > 9.4), 0.0, density)


class SurfaceSampler:
    """Area-weighted points on the head, carrying barycentrics for shape keys."""

    def __init__(self, body, density):
        self.co, self.normals = body_arrays(body)
        tris = []
        for poly in body.data.polygons:
            idx = poly.vertices[:]
            if self.co[idx[0], 1] < 149.0:
                continue
            for k in range(1, len(idx) - 1):
                tris.append((idx[0], idx[k], idx[k + 1]))
        self.tris = np.array(tris)
        a, b, c = (self.co[self.tris[:, i]] for i in range(3))
        self.areas = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
        self.density = density

    def sample(self, count, seed, importance=None):
        rng = np.random.default_rng(seed)
        centre = self.co[self.tris].mean(axis=1)
        weight = self.areas * np.maximum(0.0, self.density(centre[:, 0], centre[:, 1], centre[:, 2]) + 0.02 * (self.density(centre[:, 0], centre[:, 1] + 0.8, centre[:, 2]) > 0))
        if importance is not None:
            weight = weight * importance(centre[:, 0], centre[:, 1], centre[:, 2])
        weight = weight / weight.sum()
        total = count * 3
        picks = rng.choice(len(self.tris), size=total, p=weight)
        r1, r2 = rng.random(total), rng.random(total)
        flip = r1 + r2 > 1.0
        r1[flip], r2[flip] = 1.0 - r1[flip], 1.0 - r2[flip]
        bary = np.stack((1.0 - r1 - r2, r1, r2), axis=1)
        tri = self.tris[picks]
        points = (self.co[tri] * bary[..., None]).sum(axis=1)
        normals = (self.normals[tri] * bary[..., None]).sum(axis=1)
        normals /= np.linalg.norm(normals, axis=1, keepdims=True)
        density = self.density(points[:, 0], points[:, 1], points[:, 2])
        keep = rng.random(total) < density
        return points[keep][:count], normals[keep][:count], tri[keep][:count], bary[keep][:count], density[keep][:count]


def hair_flow(point):
    """Direction hair lies along at a scalp point, before projection."""
    x, y, z = point
    back = float(ss(1.5, -3.5, z))
    sides = float(ss(5.2, 7.6, abs(x)) * ss(169.5, 166.0, y))
    # Off the hairline up and back, with a slight sweep toward one side.
    swept = np.array([-0.20 + 0.10 * math.sin(z * 0.5), 0.34, -1.0])
    fall = np.array([x * 0.03, -1.0, -0.30])
    flow = swept * (1.0 - back) + fall * back
    return flow * (1.0 - sides) + np.array([0.0, -1.0, -0.55]) * sides


def hair_length(point, density):
    y, z = point[1], point[2]
    crown = float(ss(161.5, 169.5, y))
    length = 1.05 + 2.45 * crown ** 1.4
    length *= 1.0 + 0.16 * float(ss(3.0, 9.0, z))
    length *= 1.0 - 0.22 * float(ss(-1.0, -7.0, z))
    return length * (0.30 + 0.70 * density)


def grow_guide(point, normal, length, density, tree, co, normals, rng, points=9):
    """Lift off the scalp, then lie along the flow, staying outside the skull."""
    crown = float(ss(163.0, 170.0, point[1]))
    flow = hair_flow(point)
    tangent = flow - normal * float(flow @ normal)
    tangent = tangent / max(1e-6, float(np.linalg.norm(tangent)))
    lift = (0.22 + 0.48 * crown) * (0.30 + 0.70 * density)
    heading = tangent * (1.0 - lift) + normal * lift
    wander = rng.normal(0.0, 0.20, 3)
    path = [point + normal * 0.03]
    step = length / (points - 1)
    for index in range(1, points):
        at = path[-1]
        _, nearest, _ = tree.find(at)
        surface_normal = normals[nearest]
        flow = hair_flow(at)
        tangent = flow - surface_normal * float(flow @ surface_normal)
        tangent = tangent / max(1e-6, float(np.linalg.norm(tangent)))
        bend = 0.30 + 0.22 * index / points
        heading = heading * (1.0 - bend) + tangent * bend + wander * 0.10
        heading = heading + np.array([0.0, -0.03, 0.0])
        heading = heading / np.linalg.norm(heading)
        at = at + heading * step
        _, nearest, _ = tree.find(at)
        clearance = float((at - co[nearest]) @ normals[nearest])
        minimum = 0.10 + 0.35 * crown * math.sin(math.pi * index / points)
        if clearance < minimum:
            at = at + normals[nearest] * (minimum - clearance)
        path.append(at)
    return np.array(path)


def resample(path, count):
    distance = np.concatenate(([0.0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))))
    targets = np.linspace(0.0, distance[-1], count)
    return np.stack([np.interp(targets, distance, path[:, axis]) for axis in range(3)], axis=1)


def hair_follow(body, co, density_fn):
    """One fitted affine per shape key, so hair stays seated on the head sliders."""
    scalp = np.where(density_fn(co[:, 0], co[:, 1], co[:, 2]) > 0.15)[0]
    basis = np.concatenate((co[scalp] * 0.01, np.ones((len(scalp), 1))), axis=1)
    deltas = key_deltas(body, [name for name in KEEP.values() if not name.startswith("expr_")])
    follow = {}
    for name, delta in deltas.items():
        solved, *_ = np.linalg.lstsq(basis, delta[scalp] * 0.01, rcond=None)
        follow[name] = [round(float(v), 6) for v in solved.T.ravel()]
    return follow


def write_hair(path: Path, strands: list, params: dict, follow: dict) -> None:
    """Layout: strand and point counts, u8 counts padded to 4, then per-point arrays.

    Each strand is (points in cm, width 0..1, shade per point, seed 0..1).
    """
    counts, positions, tangents, data, arcs = [], [], [], [], []
    for points, width, shade, seed in strands:
        count = len(points)
        counts.append(count)
        steps = np.linalg.norm(np.diff(points, axis=0), axis=1)
        arc = np.concatenate(([0.0], np.cumsum(steps)))
        t = arc / max(1e-6, arc[-1])
        direction = np.gradient(points, axis=0)
        direction /= np.maximum(1e-6, np.linalg.norm(direction, axis=1, keepdims=True))
        positions.append(points * 0.01)
        tangents.append(direction)
        arcs.append(arc)
        data.append(np.stack((t, np.clip(shade, 0.0, 1.0), np.full(count, width), np.full(count, seed)), axis=1))
    counts_arr = np.array(counts, dtype=np.uint8)
    position_arr = np.concatenate(positions).astype(np.float32)
    tangent_arr = np.clip(np.round(np.concatenate(tangents) * 127.0), -127, 127).astype(np.int8)
    tangent_arr = np.concatenate((tangent_arr, np.zeros((len(tangent_arr), 1), dtype=np.int8)), axis=1)
    data_arr = np.clip(np.round(np.concatenate(data) * 255.0), 0, 255).astype(np.uint8)
    arc_arr = np.concatenate(arcs).astype(np.float32)
    meta = json.dumps({**params, "follow": follow}).encode("utf-8")
    with open(path, "wb") as handle:
        handle.write(np.array([len(counts_arr), len(position_arr)], dtype=np.uint32).tobytes())
        handle.write(counts_arr.tobytes())
        handle.write(b"\0" * ((4 - len(counts_arr) % 4) % 4))
        handle.write(position_arr.tobytes())
        handle.write(tangent_arr.tobytes())
        handle.write(data_arr.tobytes())
        handle.write(arc_arr.tobytes())
        handle.write(np.array([len(meta)], dtype=np.uint32).tobytes())
        handle.write(meta)
    print(f"hair {path.stem}: strands={len(counts_arr)} points={len(position_arr)} {path.stat().st_size / 1048576:.2f} MB")


class HeadField:
    """Shared lookups for hair generators: scalp samples plus skull and body collision."""

    def __init__(self, body):
        self.sampler = SurfaceSampler(body, hair_density)
        self.co, self.normals = self.sampler.co, self.sampler.normals
        head = np.where(self.co[:, 1] > 150.0)[0]
        self.head_tree = kdtree.KDTree(len(head))
        for index in head:
            self.head_tree.insert(self.co[index], int(index))
        self.head_tree.balance()
        upper = np.where(self.co[:, 1] > 96.0)[0]
        self.body_tree = kdtree.KDTree(len(upper))
        for index in upper:
            self.body_tree.insert(self.co[index], int(index))
        self.body_tree.balance()

    def push_out(self, point, clearance, tree=None):
        _, nearest, _ = (tree or self.head_tree).find(point)
        gap = float((point - self.co[nearest]) @ self.normals[nearest])
        if gap < clearance:
            return point + self.normals[nearest] * (clearance - gap)
        return point

    def spaced_roots(self, count, spacing, seed, min_density=0.4):
        points, normals, _, _, densities = self.sampler.sample(count * 12, seed)
        keep = densities > min_density
        points, normals = points[keep], normals[keep]
        picked = []
        for index, point in enumerate(points):
            if picked and np.linalg.norm(points[picked] - point, axis=1).min() < spacing:
                continue
            picked.append(index)
            if len(picked) >= count:
                break
        return points[picked], normals[picked]


def helix(start, axis, length, radius, turns_per_cm, rng, points=12):
    """A tight coil about an axis. This is the shape afro-textured hair actually has."""
    axis = axis / np.linalg.norm(axis)
    helper = np.array([0.0, 1.0, 0.0]) if abs(axis[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
    u = np.cross(axis, helper)
    u /= np.linalg.norm(u)
    v = np.cross(axis, u)
    s = np.linspace(0.0, 1.0, points)
    angle = rng.uniform(0.0, math.tau) + s * length * turns_per_cm * math.tau
    envelope = np.minimum(1.0, s * 5.0)[:, None] * radius
    return (
        start + axis[None, :] * (s * length)[:, None]
        + u[None, :] * np.cos(angle)[:, None] * envelope
        + v[None, :] * np.sin(angle)[:, None] * envelope
    )


def coil_field(field, rng, count, height, top_only=None, lift=(0.0, 0.32, -0.10), length=(1.2, 2.2), radius=0.13, width=(0.05, 0.075), seed=31):
    """Coils through a volume over the scalp, lighter toward the outside."""
    roots, normals, _, _, densities = field.sampler.sample(count, seed)
    strands = []
    lift = np.array(lift)
    for point, normal, density in zip(roots, normals, densities):
        if top_only is not None and rng.random() > top_only(point):
            continue
        depth = rng.random() ** 0.55
        out = normal + lift
        out = out / np.linalg.norm(out)
        reach = height(point) * float(density)
        base = point + out * (0.05 + reach * depth)
        axis = out * 0.72 + rng.normal(0.0, 0.5, 3)
        path = helix(base, axis, rng.uniform(*length), radius * rng.uniform(0.8, 1.25), rng.uniform(1.8, 2.8), rng)
        t = np.linspace(0.0, 1.0, len(path))
        gain = 0.34 + 0.66 * depth * depth
        strands.append((path, rng.uniform(*width) * (0.6 + 0.4 * float(density)), gain * (0.72 + 0.28 * t) * rng.uniform(0.82, 1.15), rng.random()))
    return strands


def filler_field(field, rng, count, height, seed=37, width=0.85):
    """Broad dark ribbons inside the volume, so you never see daylight through it."""
    roots, normals, _, _, densities = field.sampler.sample(count, seed)
    strands = []
    for point, normal, density in zip(roots, normals, densities):
        out = normal + np.array([0.0, 0.32, -0.10])
        out = out / np.linalg.norm(out)
        reach = height(point) * float(density)
        if reach < 0.3:
            continue
        path = np.stack([point + out * reach * k for k in (0.05, 0.35, 0.62, 0.86)])
        strands.append((path, width * (0.5 + 0.5 * float(density)), np.full(4, 0.16), rng.random()))
    return strands


def fall_path(field, root, normal, length, step, half_width, rng):
    """A rope from the scalp that falls under gravity, clear of the face."""
    side = 1.0 if root[0] >= 0.0 else -1.0
    away = root - np.array([0.0, 171.5, -1.2])
    away = away - normal * float(away @ normal)
    away = away / max(1e-6, float(np.linalg.norm(away)))
    heading = away + normal * 0.12
    front = float(ss(2.0, 6.0, root[2]))
    heading = heading * (1.0 - front) + np.array([side * 0.95, 0.10, -0.30]) * front
    heading /= np.linalg.norm(heading)
    wander = rng.normal(0.0, 0.05, 3)
    layer = rng.uniform(0.0, 0.7)
    path = [root + normal * 0.12]
    count = max(4, int(length / step))
    for index in range(count):
        at = path[-1]
        pull = np.array([0.0, -0.10 - 0.30 * min(1.0, index * step / 9.0), 0.0])
        # Hair parts around the face, so nothing falls across the eyes.
        if at[2] > 1.5 and abs(at[0]) < 9.8 and at[1] > 146.0:
            pull = pull + np.array([side * 0.34, 0.0, -0.20 * float(ss(1.5, 8.0, at[2]))])
        heading = heading + pull + wander * 0.25
        heading /= np.linalg.norm(heading)
        at = at + heading * step
        if at[2] > 3.0 and at[1] < 170.5:
            # The opening around the face, widest at the eyes.
            opening = 8.2 * float(ss(170.5, 166.0, at[1]))
            if abs(at[0]) < opening:
                at[0] = side * opening
        # A little more clearance per rope stops them all sharing one surface.
        at = field.push_out(at, half_width + 0.10 + layer, field.head_tree if at[1] > 150.0 else field.body_tree)
        path.append(at)
    return np.array(path)


def style_afro(field, rng):
    centre = np.array([0.0, 166.8, -0.2])

    def height(point):
        reach = AFRO_RADIUS - float(np.linalg.norm(point - centre))
        return max(1.6, reach) * float(ss(158.5, 163.5, point[1]) * 0.75 + 0.25)

    strands = filler_field(field, rng, 2800, height) + coil_field(field, rng, 16000, height)
    return strands, {"mode": 0, "width": 0.012, "taper": 0.5, "shine": 0.32, "capAlpha": 1.0, "capLow": 0.0, "capHigh": 0.0}


def style_coils(field, rng):
    def height(point):
        return 1.15 + 0.55 * float(ss(164.0, 170.0, point[1]))

    strands = coil_field(field, rng, 15000, height, lift=(0.0, 0.1, -0.02), length=(0.9, 1.5), radius=0.10)
    return strands, {"mode": 0, "width": 0.012, "taper": 0.5, "shine": 0.36, "capAlpha": 1.0, "capLow": 0.0, "capHigh": 0.0}


def style_fade(field, rng):
    def height(point):
        return 1.5 + 0.8 * float(ss(167.0, 171.0, point[1]))

    def top(point):
        return float(ss(165.8, 168.0, point[1]))

    strands = coil_field(field, rng, 15000, height, top, lift=(0.0, 0.2, -0.02), length=(0.9, 1.5), radius=0.10)
    # The cap carries the fade: skin at the nape and sideburn, dense toward the top.
    return strands, {"mode": 0, "width": 0.012, "taper": 0.5, "shine": 0.36, "capAlpha": 0.96, "capLow": 1.585, "capHigh": 1.665}


def style_waves(field, rng):
    strands = []
    roots, normals, _, _, densities = field.sampler.sample(13000, 41)
    for point, normal, density in zip(roots, normals, densities):
        flow = hair_flow(point)
        if point[2] < 2.0:
            flow = np.array([point[0] * 0.05, -1.0, -0.15])
        tangent = flow - normal * float(flow @ normal)
        tangent /= max(1e-6, float(np.linalg.norm(tangent)))
        count = 6
        length = rng.uniform(1.0, 1.6) * (0.6 + 0.4 * float(density))
        s = np.linspace(0.0, 1.0, count)
        path = point[None, :] + tangent[None, :] * (s * length)[:, None] + normal[None, :] * (0.04 + 0.07 * np.sin(s * math.pi))[:, None]
        # Waves ripple away from the crown; the ridge shade is what reads as 360s.
        ring = float(np.linalg.norm(point - HAIR_WHORL))
        ridge = (0.5 + 0.5 * math.sin(ring * 3.6)) ** 1.5
        strands.append((path, rng.uniform(0.05, 0.07), (0.16 + 0.84 * ridge) * (0.75 + 0.25 * s) * rng.uniform(0.92, 1.08), rng.random()))
    return strands, {"mode": 0, "width": 0.012, "taper": 0.8, "shine": 2.2, "capAlpha": 1.0, "capLow": 0.0, "capHigh": 0.0}


def style_puff(field, rng):
    gather = np.array([0.0, 172.4, -2.6])
    strands = []
    roots, normals, _, _, densities = field.sampler.sample(9000, 43)
    for point, normal, density in zip(roots, normals, densities):
        count = 7
        points = [point + normal * 0.05]
        for k in range(1, count):
            s = k / (count - 1)
            at = point + (gather - point) * s
            points.append(field.push_out(at, 0.10 + 0.05 * rng.random()))
        path = np.array(points) + rng.normal(0.0, 0.015, (count, 3))
        strands.append((path, rng.uniform(0.045, 0.07) * (0.6 + 0.4 * float(density)), np.linspace(0.42, 0.85, count) * rng.uniform(0.85, 1.12), rng.random()))
    centre = np.array([0.0, 175.6, -3.4])
    for _ in range(1500):
        direction = rng.normal(0.0, 1.0, 3)
        direction /= np.linalg.norm(direction)
        direction[1] = abs(direction[1]) * 0.8 + direction[1] * 0.2
        path = np.stack([centre + direction * 5.6 * k for k in (0.05, 0.35, 0.65, 0.92)])
        strands.append((path, 0.85, np.full(4, 0.15), rng.random()))
    for _ in range(11000):
        direction = rng.normal(0.0, 1.0, 3)
        direction /= np.linalg.norm(direction)
        depth = rng.random() ** 0.5
        base = centre + direction * np.array([1.08, 0.95, 1.05]) * (6.4 * depth)
        axis = direction * 0.7 + rng.normal(0.0, 0.5, 3)
        path = helix(base, axis, rng.uniform(1.2, 2.2), 0.13, rng.uniform(1.8, 2.8), rng)
        shade = (0.32 + 0.68 * depth * depth) * rng.uniform(0.82, 1.15)
        strands.append((path, rng.uniform(0.05, 0.075), np.full(len(path), shade), rng.random()))
    return strands, {"mode": 0, "width": 0.012, "taper": 0.5, "shine": 0.34, "capAlpha": 1.0, "capLow": 0.0, "capHigh": 0.0}


def rope_style(field, rng, count, spacing, length, width_cm, step, mode, seed, cap_alpha=0.92, shine=0.5, swing=0.2):
    roots, normals = field.spaced_roots(count, spacing, seed)
    strands = []
    half = width_cm * 0.5
    for point, normal in zip(roots, normals):
        reach = length * rng.uniform(1.0 - swing, 1.0 + swing * 0.5)
        path = fall_path(field, point, normal, reach, step, half, rng)
        t = np.linspace(0.0, 1.0, len(path))
        strands.append((path, rng.uniform(0.86, 1.0), (0.62 + 0.38 * t) * rng.uniform(0.82, 1.15), rng.random()))
    print(f"  ropes placed {len(strands)} of {count}")
    return strands, {"mode": mode, "width": width_cm * 0.01, "taper": 0.0, "shine": shine, "capAlpha": cap_alpha, "capLow": 0.0, "capHigh": 0.0}


def style_locs(field, rng):
    return rope_style(field, rng, 74, 2.05, 27.0, 0.98, 1.1, 1, 51, shine=0.34)


def style_twists(field, rng):
    return rope_style(field, rng, 120, 1.55, 14.0, 0.66, 0.42, 2, 52, shine=0.46, swing=0.15)


def style_braids(field, rng):
    return rope_style(field, rng, 150, 1.38, 38.0, 0.56, 0.42, 3, 53, cap_alpha=0.70, shine=0.56, swing=0.1)


def trace_row(field, start, drift, rng, step=0.40):
    """Walk over the scalp from a start point: back across the crown, then down."""
    co, normals = field.co, field.normals
    points = [start]
    for _ in range(130):
        at = points[-1]
        _, nearest, _ = field.head_tree.find(at)
        normal = normals[nearest]
        behind = float(ss(1.5, -3.5, at[2]))
        want = np.array([drift + at[0] * 0.012 * behind, 0.22 * (1.0 - behind) - behind, -(1.0 - behind * 0.92)])
        tangent = want - normal * float(want @ normal)
        tangent /= max(1e-6, float(np.linalg.norm(tangent)))
        at = at + tangent * step
        _, nearest, _ = field.head_tree.find(at)
        at = at + normals[nearest] * (0.22 - float((at - co[nearest]) @ normals[nearest]))
        points.append(at)
        if at[1] < 156.4:
            break
    path = np.array(points)
    kept = hair_density(path[:, 0], path[:, 1], path[:, 2]) > 0.06
    path = path[: max(8, int(kept.sum()))]
    tail = [path[-1] + np.array([path[-1][0] * 0.01, -0.42 * k, -0.10 * k]) for k in range(1, 10)]
    return np.concatenate((path, np.array(tail)))


def style_cornrows(field, rng):
    co = field.co
    density = hair_density(co[:, 0], co[:, 1], co[:, 2])
    strands = []
    for x0 in np.arange(-6.6, 6.61, 1.2):
        near = np.where((np.abs(co[:, 0] - x0) < 0.5) & (density > 0.30) & (co[:, 1] > 163.0))[0]
        if not len(near):
            continue
        start = co[near[np.argmax(co[near, 2] + co[near, 1] * 0.02)]].copy()
        path = trace_row(field, start, 0.05 * x0 / 6.6, rng)
        strands.append((path, rng.uniform(0.92, 1.0), np.full(len(path), rng.uniform(0.82, 1.05)), rng.random()))
    # Side rows start at the temple and pass over the ear.
    for sign in (1.0, -1.0):
        for y0 in (167.4, 166.1, 164.8):
            near = np.where((co[:, 0] * sign > 6.0) & (np.abs(co[:, 1] - y0) < 0.4) & (density > 0.30))[0]
            if not len(near):
                continue
            start = co[near[np.argmax(co[near, 2])]].copy()
            path = trace_row(field, start, 0.0, rng)
            strands.append((path, rng.uniform(0.92, 1.0), np.full(len(path), rng.uniform(0.82, 1.05)), rng.random()))
    print(f"  cornrows {len(strands)}")
    return strands, {"mode": 3, "width": 0.0085, "taper": 0.0, "shine": 0.58, "capAlpha": 0.42, "capLow": 0.0, "capHigh": 0.0}


def style_bantu(field, rng):
    roots, normals = field.spaced_roots(13, 4.5, 54, min_density=0.55)
    strands = []
    for point, normal in zip(roots, normals):
        helper = np.array([0.0, 1.0, 0.0]) if abs(normal[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = np.cross(normal, helper)
        u /= np.linalg.norm(u)
        v = np.cross(normal, u)
        count = 64
        s = np.linspace(0.0, 1.0, count)
        angle = rng.uniform(0.0, math.tau) + s * math.tau * 3.6
        radius = (1.72 * (1.0 - s) ** 0.65 + 0.06)[:, None]
        rise = (0.32 + 3.0 * s ** 0.85)[:, None]
        path = point + normal[None, :] * rise + u[None, :] * np.cos(angle)[:, None] * radius + v[None, :] * np.sin(angle)[:, None] * radius
        strands.append((path, 1.0, 0.70 + 0.30 * s, rng.random()))
    return strands, {"mode": 2, "width": 0.0088, "taper": 0.0, "shine": 0.5, "capAlpha": 0.84, "capLow": 0.0, "capHigh": 0.0}


def style_crop(field, rng):
    co, normals = field.co, field.normals

    def short_hair_weight(x, y, z):
        band = np.exp(-((hair_density(x, y, z) - 0.32) / 0.26) ** 2)
        return (1.0 + 1.6 * ss(170.0, 162.0, y)) * (1.0 + 2.2 * band)

    roots, root_normals, _, _, densities = field.sampler.sample(HAIR_STRANDS, 11, short_hair_weight)
    centres, centre_normals, _, _, centre_density = field.sampler.sample(HAIR_CLUMPS, 12)
    guides, gains = [], []
    for point, normal, density in zip(centres, centre_normals, centre_density):
        length = hair_length(point, density) * rng.uniform(0.74, 1.22)
        guides.append(grow_guide(point, normal, length, density, field.head_tree, co, normals, rng))
        gains.append(rng.uniform(0.84, 1.16))
    clump_tree = kdtree.KDTree(len(centres))
    for index, point in enumerate(centres):
        clump_tree.insert(point, index)
    clump_tree.balance()
    strands = []
    for point, normal, density in zip(roots, root_normals, densities):
        _, clump, _ = clump_tree.find(point)
        guide = guides[clump]
        guide_len = float(np.linalg.norm(np.diff(guide, axis=0), axis=1).sum())
        own = hair_length(point, density)
        scale = min(1.15, own * rng.uniform(0.68, 1.08) / max(0.1, guide_len))
        count = 5 if guide_len * scale < 2.4 else 7
        t = np.linspace(0.0, 1.0, count)
        path = resample(guide[: max(3, int(round(len(guide) * min(1.0, scale))))], count)
        offset = point + normal * 0.03 - path[0]
        path = path + offset[None, :] * (1.0 - 0.82 * float(density) ** 1.5 * t ** 1.15)[:, None]
        phase = rng.uniform(0, math.tau, 3)
        amount = 0.035 + 0.025 * (1.0 - float(density))
        for axis in range(3):
            path[:, axis] += amount * np.sin(t * rng.uniform(4.0, 9.0) + phase[axis]) * t
        root_shade = 0.34 + 0.40 * (1.0 - float(density)) ** 2
        shade = (root_shade + (1.0 - root_shade) * t ** 0.70) * gains[clump] * rng.uniform(0.86, 1.14)
        strands.append((path, (0.28 + 0.72 * float(density)) * rng.uniform(0.62, 1.0) * 0.071, shade, rng.random()))
    return strands, {"mode": 0, "width": 0.012, "taper": 1.0, "shine": 1.0, "capAlpha": 1.0, "capLow": 0.0, "capHigh": 0.0}


HAIR_STYLES = {
    "afro": style_afro,
    "coils": style_coils,
    "fade": style_fade,
    "waves": style_waves,
    "puff": style_puff,
    "locs": style_locs,
    "twists": style_twists,
    "braids": style_braids,
    "cornrows": style_cornrows,
    "bantu": style_bantu,
    "crop": style_crop,
}


def build_hair_styles(body, out_dir: Path, only: str | None = None) -> None:
    field = HeadField(body)
    follow = hair_follow(body, field.co, hair_density)
    hair_dir = out_dir / "hair"
    hair_dir.mkdir(parents=True, exist_ok=True)
    for index, (name, style) in enumerate(HAIR_STYLES.items()):
        if only and name not in only.split(","):
            continue
        strands, params = style(field, np.random.default_rng(100 + index))
        write_hair(hair_dir / f"{name}.bin", strands, params, follow)


def build_hair_cap(body, out_dir: Path) -> list:
    """Dark soft underlayer. Strands sit in it; it also shades the hairline skin."""
    cap_mat = simple_material("HairCap", (0.05, 0.03, 0.02), 0.8)
    co, normals = body_arrays(body)
    source = bpy.data.meshes.new("hair_cap_source")
    keep: dict[int, int] = {}
    local, faces = [], []
    densities = hair_density(co[:, 0], co[:, 1], co[:, 2])
    for poly in body.data.polygons:
        indices = poly.vertices[:]
        if max(densities[i] for i in indices) < 0.02:
            continue
        face = []
        for i in indices:
            if i not in keep:
                keep[i] = len(local)
                local.append(tuple(co[i]))
            face.append(keep[i])
        faces.append(tuple(face))
    source.from_pydata(local, [], faces)
    source.update()
    bm = bmesh.new()
    bm.from_mesh(source)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=4, use_grid_fill=True)
    bm.to_mesh(source)
    bm.free()
    source.update()
    count = len(source.vertices)
    sub = np.empty(count * 3)
    source.vertices.foreach_get("co", sub)
    sub = sub.reshape(-1, 3)
    sub_normals = np.empty(count * 3)
    source.vertices.foreach_get("normal", sub_normals)
    sub_normals = sub_normals.reshape(-1, 3)
    density = hair_density(sub[:, 0], sub[:, 1], sub[:, 2])
    lift = (0.06 + 0.26 * ss(162.0, 170.0, sub[:, 1])) * density + 0.015
    moved = sub + sub_normals * lift[:, None]
    cap_faces = [tuple(poly.vertices) for poly in source.polygons]
    cap = mesh_object("hair_cap", moved, cap_faces, None, cap_mat, body.matrix_world)
    layer = cap.data.color_attributes.new(name="Density", type="FLOAT_COLOR", domain="POINT")
    for index, value in enumerate(density):
        layer.data[index].color = (float(value), float(value), float(value), 1.0)
    bpy.data.meshes.remove(source)
    print(f"hair cap verts={count} faces={len(cap_faces)}")
    return [cap]


def brow_centre(ax):
    """Brow spine height across the ridge, from inner head to tail."""
    return np.interp(ax, (1.25, 2.3, 3.9, 5.0, 5.8), (163.72, 164.30, 164.62, 164.40, 163.92))


def brow_density(x, y, z):
    ax = np.abs(np.asarray(x, float))
    y = np.asarray(y, float)
    half = np.interp(ax, (1.25, 2.3, 3.9, 5.0, 5.8), (0.40, 0.42, 0.34, 0.22, 0.07))
    across = np.abs(y - brow_centre(ax)) / half
    return ss(1.15, 0.72, across) * ss(1.15, 1.45, ax) * ss(5.95, 5.6, ax) * (np.asarray(z, float) > 8.0)


def build_brows(body) -> list:
    """Individual hairs on the skin, carried by the same keys as the brow ridge."""
    material = simple_material("Brows", (0.05, 0.032, 0.022), 0.6)
    material.use_backface_culling = False
    sampler = SurfaceSampler(body, brow_density)
    rng = np.random.default_rng(23)
    points, normals, tris, barys, densities = sampler.sample(1050, 23)
    verts, faces, sources, weights = [], [], [], []
    for point, normal, tri, bary, density in zip(points, normals, tris, barys, densities):
        ax = abs(point[0])
        sx = 1.0 if point[0] > 0 else -1.0
        along = (ax - 1.25) / 4.6
        # Inner hairs stand up, mid hairs angle out, the tail lies flat along it.
        rise = float(np.interp(along, (0.0, 0.18, 0.55, 0.85, 1.0), (0.92, 0.55, 0.28, 0.0, -0.22)))
        heading = np.array([sx * (1.0 - abs(rise) * 0.55), rise, 0.0]) + rng.normal(0.0, 0.10, 3)
        heading = heading - normal * float(heading @ normal)
        heading = heading / max(1e-6, float(np.linalg.norm(heading)))
        length = rng.uniform(0.26, 0.50) * (0.7 + 0.3 * float(density))
        width = rng.uniform(0.010, 0.019)
        side = np.cross(normal, heading)
        side = side / max(1e-6, float(np.linalg.norm(side)))
        start = len(verts)
        for step in range(4):
            t = step / 3
            spine = point + heading * length * t + normal * (0.012 + 0.030 * math.sin(t * math.pi * 0.7))
            spine = spine + side * sx * 0.05 * length * t * t
            half = 0.5 * width * (1.0 - t) ** 0.7 + 0.002
            verts.append(tuple(spine - side * half))
            verts.append(tuple(spine + side * half))
            sources += [tri, tri]
            weights += [bary, bary]
        for step in range(3):
            a = start + step * 2
            faces.append((a, a + 1, a + 3, a + 2))
    brows = mesh_object("brows", verts, faces, None, material, body.matrix_world)
    deltas = key_deltas(body, list(HEAD_SHAPES.values()) + list(EXPRESSION_SHAPES.values()))
    add_follow_keys(brows, deltas, np.array(sources), np.array(weights))
    print(f"brow hairs={len(points)} verts={len(verts)}")
    return [brows]


def noise3(points, scale, seed):
    """Trilinear value noise over object-space positions, in 0..1."""
    rng = np.random.default_rng(seed)
    table = rng.random((64, 64, 64), dtype=np.float32)
    scaled = points * scale
    base = np.floor(scaled).astype(np.int64)
    f = scaled - base
    f = f * f * (3.0 - 2.0 * f)
    i = base & 63
    j = (base + 1) & 63
    result = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                ix = (j if dx else i)[..., 0]
                iy = (j if dy else i)[..., 1]
                iz = (j if dz else i)[..., 2]
                wx = f[..., 0] if dx else 1.0 - f[..., 0]
                wy = f[..., 1] if dy else 1.0 - f[..., 1]
                wz = f[..., 2] if dz else 1.0 - f[..., 2]
                result = result + table[ix, iy, iz] * wx * wy * wz
    return result


def fractal(points, scale, seed, octaves=3):
    total, amp = 0.0, 0.0
    weight = 1.0
    for octave in range(octaves):
        total = total + noise3(points, scale * 2.0 ** octave, seed + octave) * weight
        amp += weight
        weight *= 0.5
    return total / amp


def rasterise_positions(body, size: int) -> tuple[np.ndarray, np.ndarray]:
    """Object-space position per UV texel, so paint follows the real geometry."""
    mesh = body.data
    co = REST_CO
    _, vertex_normals = body_arrays(body)
    uv_layer = mesh.uv_layers.active.data
    positions = np.zeros((size, size, 3), dtype=np.float32)
    normal_map = np.zeros((size, size, 3), dtype=np.float32)
    covered = np.zeros((size, size), dtype=bool)
    loop_vert = np.empty(len(mesh.loops), dtype=np.int64)
    mesh.loops.foreach_get("vertex_index", loop_vert)
    uv = np.empty(len(mesh.loops) * 2)
    uv_layer.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2) * size
    for poly in mesh.polygons:
        start, total = poly.loop_start, poly.loop_total
        for k in range(1, total - 1):
            ids = (start, start + k, start + k + 1)
            a, b, c = uv[ids[0]], uv[ids[1]], uv[ids[2]]
            denom = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(denom) < 1e-9:
                continue
            x0, x1 = int(max(0, math.floor(min(a[0], b[0], c[0])))), int(min(size - 1, math.ceil(max(a[0], b[0], c[0]))))
            y0, y1 = int(max(0, math.floor(min(a[1], b[1], c[1])))), int(min(size - 1, math.ceil(max(a[1], b[1], c[1]))))
            xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / denom
            w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / denom
            w2 = 1.0 - w0 - w1
            inside = (w0 >= -0.02) & (w1 >= -0.02) & (w2 >= -0.02)
            if not inside.any():
                continue
            pa, pb, pc = co[loop_vert[ids[0]]], co[loop_vert[ids[1]]], co[loop_vert[ids[2]]]
            rows = ys[inside].astype(np.int64)
            cols = xs[inside].astype(np.int64)
            positions[rows, cols] = (
                w0[inside][:, None] * pa + w1[inside][:, None] * pb + w2[inside][:, None] * pc
            )
            normal_map[rows, cols] = vertex_normals[loop_vert[ids[0]]]
            covered[rows, cols] = True
    # Grow the islands so mip levels and seams never sample unpainted black.
    for _ in range(10):
        missing = ~covered
        if not missing.any():
            break
        grown = positions.copy()
        filled = covered.copy()
        for shift, axis in ((1, 0), (-1, 0), (1, 1), (-1, 1)):
            near = np.roll(covered, shift, axis)
            take = missing & near & ~filled
            grown[take] = np.roll(positions, shift, axis)[take]
            filled |= take
        positions, covered = grown, filled
    return positions, normal_map


def mouth_curve(body):
    """Mouth line from the mesh crease. Past 1.8 cm the crease fades into the cheek."""
    co, _ = body_arrays(body)
    region = co[(np.abs(co[:, 0]) < 2.0) & (co[:, 1] > 154.6) & (co[:, 1] < 156.6) & (co[:, 2] > 9.0)]
    xs, ys = [], []
    for centre in np.arange(0.0, 1.9, 0.2):
        column = region[np.abs(np.abs(region[:, 0]) - centre) < 0.14]
        if ys:
            column = column[np.abs(column[:, 1] - ys[-1]) < 0.28]
        if len(column) < 4:
            continue
        fit = np.polyval(np.polyfit(column[:, 1], column[:, 2], 2), column[:, 1])
        xs.append(centre)
        ys.append(float(column[np.argmin(column[:, 2] - fit), 1]))
    # The corner sits a little below where the measured crease runs out.
    xs += [MOUTH_CORNER_X, 3.4]
    ys += [ys[-1] - 0.14, ys[-1] - 0.14]
    print("mouth line", [(round(a, 1), round(b, 2)) for a, b in zip(xs, ys)])
    return np.array(xs), np.array(ys)


def paint_skin(body, rims, out_dir: Path) -> None:
    size = 2048
    positions, surface_normals = rasterise_positions(body, size)
    pos = positions.astype(np.float64)
    x, y, z = pos[..., 0], pos[..., 1], pos[..., 2]
    ax = np.abs(x)
    front = ss(4.0, 7.0, z)

    # Identity colour lives in the material tint; the map holds the variation.
    colour = np.ones((size, size, 3)) * np.array([0.725, 0.580, 0.520])

    def blend(mask, tone, amount=1.0):
        nonlocal colour
        weight = (np.clip(mask, 0.0, 1.0) * amount)[..., None]
        colour = colour * (1.0 - weight) + np.array(tone) * weight

    def blob(cx, cy, cz, rx, ry, rz, mirror=True):
        dx = (ax - cx) if mirror else (x - cx)
        return np.exp(-((dx / rx) ** 2 + ((y - cy) / ry) ** 2 + ((z - cz) / rz) ** 2))

    large = fractal(pos, 0.42, 3)
    medium = fractal(pos, 1.4, 7)
    fine = fractal(pos, 7.0, 13)
    colour *= (0.955 + 0.09 * large)[..., None]
    blend((medium - 0.46) * 3.2, (0.70, 0.46, 0.40), 0.20)

    # Facial colour zones: warm blood across the mid face, yellow on the brow.
    blend(blob(0.0, 167.0, 11.5, 7.0, 3.2, 5.0, False), (0.76, 0.60, 0.49), 0.32)
    blend(blob(4.2, 156.8, 10.5, 2.9, 2.5, 3.5), (0.72, 0.49, 0.43), 0.38)
    blend(blob(0.0, 158.4, 15.0, 1.5, 1.5, 1.8, False), (0.72, 0.49, 0.43), 0.34)
    blend(ss(6.6, 7.6, ax) * ss(155.5, 157.5, y) * ss(164.5, 163.0, y) * ss(-2.0, 0.0, z) * ss(5.0, 3.5, z), (0.72, 0.42, 0.38), 0.55)
    # Shadow under the eye and around the socket.
    blend(blob(3.2, 160.8, 11.5, 1.9, 0.75, 2.0), (0.60, 0.42, 0.40), 0.38)
    blend(blob(3.2, 163.0, 11.5, 2.5, 0.45, 2.0), (0.66, 0.46, 0.41), 0.34)
    # Beard shadow: cool and desaturated, broken up by follicles.
    beard = (
        ss(158.0, 156.6, y) * ss(147.5, 149.5, y) * ss(5.5, 8.0, z) * ss(7.4, 5.4, ax)
    ) * (1.0 - 0.45 * blob(3.9, 156.0, 11.0, 1.4, 1.8, 2.5))
    beard = np.maximum(beard, ss(6.4, 4.8, np.abs(y - 159.5 + 0.0 * x)) * 0.0)
    follicle = ss(0.45, 0.72, fractal(pos, 26.0, 21, 2))
    blend(beard * (0.40 + 0.60 * follicle), (0.47, 0.42, 0.40), 0.26)

    # Sparse round freckles over nose and cheek tops, soft enough to be tone.
    spots = np.random.default_rng(31)
    freckles = np.zeros((size, size))
    for _ in range(170):
        cx, cy = spots.uniform(0.0, 5.6), spots.uniform(157.0, 161.0)
        side_sign = spots.choice((-1.0, 1.0))
        radius = spots.uniform(0.045, 0.10)
        near = (np.abs(x - side_sign * cx) < 0.3) & (np.abs(y - cy) < 0.3) & (z > 8.0)
        d2 = (x[near] - side_sign * cx) ** 2 + (y[near] - cy) ** 2
        freckles[near] = np.maximum(freckles[near], np.exp(-d2 / (radius * radius)) * spots.uniform(0.25, 0.7))
    blend(freckles, (0.56, 0.37, 0.30), 0.26)
    colour *= (0.98 + 0.04 * fine)[..., None]

    # Lips follow the measured mouth line, with a real cupid's bow.
    xs, ys = mouth_curve(body)
    line = np.interp(ax, xs, ys)
    corner = MOUTH_CORNER_X
    cap = np.clip(1.0 - (ax / corner) ** 2, 0.0, 1.0)
    bow = 1.02 + 0.15 * np.exp(-(((ax - 0.60) / 0.40) ** 2)) - 0.07 * np.exp(-((ax / 0.22) ** 2))
    upper_edge = line + bow * cap ** 0.70
    lower_edge = line - 1.28 * cap ** 0.60
    lips = (
        ss(-0.17, 0.14, upper_edge - y) * ss(-0.20, 0.17, y - lower_edge)
        * ss(10.0, 11.5, z) * ss(0.0, 0.10, cap)
    )
    mottled = 0.90 + 0.20 * fractal(pos * np.array([3.0, 0.9, 1.0]), 6.0, 17, 2)
    lip_tone = np.stack((0.635 * mottled, 0.395 * mottled, 0.365 * mottled), axis=-1)
    colour = colour * (1.0 - lips[..., None] * 0.80) + lip_tone * lips[..., None] * 0.80
    upper_lip = lips * ss(line - 0.05, line + 0.25, y)
    blend(upper_lip, (0.54, 0.31, 0.30), 0.34)
    # Mouth seam and interior go dark, tapering into the corners.
    seam = ss(0.13, 0.015, np.abs(y - line)) * ss(corner + 0.25, corner - 0.7, ax) * ss(10.0, 11.5, z)
    blend(seam, (0.20, 0.10, 0.09), 0.78)
    # Nostril interior and the crease beside the nose.
    blend(blob(1.0, 157.95, 13.3, 0.62, 0.34, 0.8), (0.22, 0.11, 0.10), 0.72)

    # Lash line and lid edge, measured from the rim rather than guessed.
    co, _ = body_arrays(body)
    region = (ax > 1.2) & (ax < 5.4) & (y > 160.9) & (y < 163.6) & (z > 8.5)
    points = np.stack((ax[region], y[region]), axis=1)
    rim_xy = np.abs(co[rims[1.0]][:, :2])
    gaps = np.sqrt(((points[:, None, :] - rim_xy[None, :, :]) ** 2).sum(axis=2)).min(axis=1)
    rim_gap = np.full((size, size), 9.0)
    rim_gap[region] = gaps
    above = y > 162.3
    blend(ss(0.14, 0.02, rim_gap) * above, (0.30, 0.19, 0.16), 0.72)
    blend(ss(0.09, 0.015, rim_gap) * (~above), (0.70, 0.46, 0.42), 0.55)
    # Pre-brow softness: a faint tone beneath the individual brow hairs.
    blend(brow_density(x, y, z) * (z > 8.0), (0.36, 0.26, 0.21), 0.42)

    ao_path = out_dir / "skin_ao.png"
    if ao_path.exists():
        ao_image = bpy.data.images.load(str(ao_path))
        ao_image.colorspace_settings.name = "Non-Color"
        ao = read_pixels(ao_image)[..., 0].astype(np.float64)
        if ao.shape != (size, size):
            raise RuntimeError(f"AO map must be {size}, got {ao.shape}")
        # Cavity only; broad shading is the light's job.
        colour *= (0.42 + 0.58 * ss(0.05, 0.86, ao))[..., None]
        red = (1.0 - ss(0.25, 0.95, ao)) * 0.16
        colour[..., 1] *= 1.0 - red
        colour[..., 2] *= 1.0 - red

    # Masks let the page choose lip and palm colour per skin tone. Deep skin has
    # darker, two-tone lips and much lighter palms; no single tint can do that.
    # Rest-pose palms face down and forward; soles face straight down.
    palm = ss(44.0, 50.0, ax) * ss(0.25, 0.65, -surface_normals[..., 1] * 0.9 - surface_normals[..., 2] * 0.35)
    sole = ss(5.0, 2.5, y) * ss(0.3, 0.7, -surface_normals[..., 1])
    mask = np.ones((size, size, 4), dtype=np.float32)
    mask[..., 0] = np.clip(lips, 0.0, 1.0)
    mask[..., 1] = np.clip(ss(line - 0.05, line + 0.22, y), 0.0, 1.0)
    mask[..., 2] = np.clip(np.maximum(palm, sole), 0.0, 1.0)
    mask_image = new_image("skin_mask", size, "Non-Color")
    write_pixels(mask_image, mask)
    save_image(mask_image, out_dir / "skin_mask.png")

    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(colour, 0.0, 1.0)
    albedo = new_image("skin_albedo", size, "sRGB")
    write_pixels(albedo, rgba)
    save_image(albedo, out_dir / "skin_albedo.png")

    # Roughness: oily T zone, dry cheeks, wet-looking but not glassy lips.
    rough = 0.70 + 0.09 * (fine - 0.5) + 0.05 * (medium - 0.5)
    tzone = np.maximum(blob(0.0, 166.0, 12.5, 3.2, 2.8, 3.0, False), blob(0.0, 159.5, 15.0, 1.4, 3.0, 2.2, False))
    rough = rough - 0.12 * tzone
    rough = rough * (1.0 - lips) + (0.40 + 0.10 * fine) * lips
    grey = np.clip(rough, 0.0, 1.0).astype(np.float32)
    rough_rgba = np.ones((size, size, 4), dtype=np.float32)
    rough_rgba[..., 0] = rough_rgba[..., 1] = rough_rgba[..., 2] = grey
    image = new_image("skin_rough", size, "Non-Color")
    write_pixels(image, rough_rgba)
    save_image(image, out_dir / "skin_rough.png")
    print(f"painted skin {size}px, lips texels={int((lips > 0.5).sum())}, ao={'yes' if ao_path.exists() else 'no'}")


def bake_ao(body, out_dir: Path) -> None:
    """Socket, nostril and ear cavity. Slow, so it is cached until asked for."""
    material = simple_material("AoBake", (0.8, 0.8, 0.8), 0.8)
    body.data.materials.clear()
    body.data.materials.append(material)
    nodes = material.node_tree.nodes
    image = new_image("skin_ao", 2048, "Non-Color")
    target = nodes.new("ShaderNodeTexImage")
    target.image = image
    nodes.active = target
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = False
    scene.world = bpy.data.worlds.new("AoWorld")
    scene.world.light_settings.distance = 0.05
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.bake(type="AO", margin=8)
    save_image(image, out_dir / "skin_ao.png")
    print("baked ambient occlusion")


def generate_fabric_texture(path: Path) -> None:
    size = 1024
    rng = np.random.default_rng(29)
    u = np.arange(size, dtype=np.float32) / size
    xx, yy = np.meshgrid(u, u)
    weave = 0.5 + 0.5 * np.sin(xx * math.tau * 140) * np.sin(yy * math.tau * 140)
    cloud = (
        0.5
        + 0.25 * np.sin(xx * math.tau * 3 + yy * math.tau * 1 + 0.7)
        + 0.15 * np.sin(xx * math.tau * 7 - yy * math.tau * 5 + 2.1)
        + 0.10 * np.sin(xx * math.tau * 13 + yy * math.tau * 9 + 4.3)
    )
    base = 0.82 + 0.012 * weave + 0.05 * cloud + rng.normal(0, 0.008, (size, size))
    base = np.clip(base, 0, 1)
    rgb = np.stack([base, base * 0.992, base * 0.975], axis=-1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = rgb
    image = new_image("fabric", size, "sRGB")
    write_pixels(image, rgba)
    save_image(image, path)


def garment_width(y: float) -> float:
    """Half-width of the top at a rest-pose height, in centimetres."""
    if y < 100.4 or y > 153.4:
        return -1.0
    if y < 128.0:
        return 21.0 - (y - 100.4) * 2.0 / 27.6
    if y < 146.0:
        return 19.0 - (y - 128.0) * 3.8 / 18.0
    return 15.2 - (y - 146.0) * 7.2 / 7.4


def garment_limit(x: float, z: float) -> float:
    """Neckline height: a crew curve, scooped at the front, higher at the back."""
    back = max(0.0, min(1.0, (4.0 - z) / 10.0))
    return 147.5 + 4.6 * back + 2.2 * min(1.0, (x / 6.5) ** 2)


def garment_edge(co) -> float:
    """Signed distance in cm to the cut line, positive on the fabric."""
    width = garment_width(max(100.4, min(153.4, co.y)))
    return min(width - abs(co.x), garment_limit(co.x, co.z) - co.y, co.y - 100.4)


def trouser_edge(co) -> float:
    """Waist down to the ankle, on rest-pose positions."""
    return min(105.5 - co.y, co.y - 11.5, 34.0 - abs(co.x))


def build_garment(body: bpy.types.Object, out_dir: Path, name: str = "garment", edge_fn=None, offset: float = 0.35, tint=(0.34, 0.38, 0.44, 1.0)) -> bpy.types.Object:
    """Duplicate part of the body as clothing; reshape with the body's morph keys."""
    fabric_path = out_dir / "fabric.png"
    generate_fabric_texture(fabric_path)
    fabric_image = bpy.data.images.load(str(fabric_path))
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 0.84
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Sheen Weight"].default_value = 0.4
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = fabric_image
    multiply = nodes.new("ShaderNodeMixRGB")
    multiply.blend_type = "MULTIPLY"
    multiply.inputs["Fac"].default_value = 1.0
    multiply.inputs["Color2"].default_value = tint
    links.new(tex.outputs["Color"], multiply.inputs["Color1"])
    links.new(multiply.outputs["Color"], bsdf.inputs["Base Color"])

    mesh = body.data
    keys = [block for block in mesh.shape_keys.key_blocks if block.name != "Basis"]
    uv_data = mesh.uv_layers.active.data

    # Keep a margin past the cut. The page discards on the interpolated distance,
    # so the visible edge is a smooth curve whatever the triangles underneath do.
    edge_of = edge_fn or garment_edge
    edges = [edge_of(Vector(point)) for point in REST_CO]
    selected = [poly for poly in mesh.polygons if max(edges[v] for v in poly.vertices) > -0.2]
    if not selected:
        raise RuntimeError("garment region selected no faces")

    remap: dict[int, int] = {}
    source: list[int] = []
    verts: list[tuple[float, float, float]] = []
    uvs: list[tuple[float, float]] = []
    faces: list[tuple[int, ...]] = []

    def add_outer(index: int) -> int:
        if index in remap:
            return remap[index]
        vertex = mesh.vertices[index]
        out = vertex.co + vertex.normal * offset
        remap[index] = len(verts)
        source.append(index)
        verts.append(tuple(out))
        return remap[index]

    for poly in selected:
        face = []
        for loop_index in poly.loop_indices:
            loop = mesh.loops[loop_index]
            face.append(add_outer(loop.vertex_index))
            uv = uv_data[loop_index].uv
            uvs.append((uv.x, uv.y))
        faces.append(tuple(face))

    garment_mesh = bpy.data.meshes.new(name)
    garment_mesh.from_pydata(verts, [], faces)
    garment_mesh.update()
    uv_layer = garment_mesh.uv_layers.new(name="UVMap")
    for loop in garment_mesh.loops:
        if loop.index < len(uvs):
            uv_layer.data[loop.index].uv = uvs[loop.index]
        else:
            uv_layer.data[loop.index].uv = (0.5, 0.5)
    for poly in garment_mesh.polygons:
        poly.use_smooth = True
    edge_layer = garment_mesh.color_attributes.new(name="Edge", type="FLOAT_COLOR", domain="POINT")
    for index, src in enumerate(source):
        value = max(0.0, min(1.0, 0.5 + edges[src] / 6.0))
        edge_layer.data[index].color = (value, value, value, 1.0)

    garment = bpy.data.objects.new(name, garment_mesh)
    bpy.context.scene.collection.objects.link(garment)
    garment.data.materials.append(mat)
    garment.matrix_world = body.matrix_world

    garment.shape_key_add(name="Basis", from_mix=False)
    basis = mesh.shape_keys.key_blocks["Basis"]
    for block in keys:
        key = garment.shape_key_add(name=block.name, from_mix=False)
        for out_index, src_index in enumerate(source):
            delta = block.data[src_index].co - basis.data[src_index].co
            key.data[out_index].co = Vector(verts[out_index]) + delta
        key.value = 0.0
    print(f"{name} faces={len(selected)} verts={len(verts)} keys={len(keys)}")
    return garment


def node(nt, kind: str, location=(0, 0), **inputs):
    item = nt.nodes.new(kind)
    item.location = location
    for key, value in inputs.items():
        item.inputs[key].default_value = value
    return item


def math_node(nt, operation: str, a, b=None, clamp: bool = False, location=(0, 0)):
    item = nt.nodes.new("ShaderNodeMath")
    item.operation = operation
    item.use_clamp = clamp
    item.location = location
    if isinstance(a, (int, float)):
        item.inputs[0].default_value = a
    else:
        nt.links.new(a, item.inputs[0])
    if b is not None:
        if isinstance(b, (int, float)):
            item.inputs[1].default_value = b
        else:
            nt.links.new(b, item.inputs[1])
    return item.outputs[0]


def smooth(nt, source, low: float, high: float, location=(0, 0)):
    item = nt.nodes.new("ShaderNodeMapRange")
    item.interpolation_type = "SMOOTHSTEP"
    item.location = location
    item.inputs["From Min"].default_value = low
    item.inputs["From Max"].default_value = high
    item.inputs["To Min"].default_value = 0.0
    item.inputs["To Max"].default_value = 1.0
    nt.links.new(source, item.inputs["Value"])
    return item.outputs["Result"]


def mix_color(nt, factor, color_a, color_b, location=(0, 0)):
    item = nt.nodes.new("ShaderNodeMix")
    item.data_type = "RGBA"
    item.blend_type = "MIX"
    item.location = location
    if isinstance(factor, (int, float)):
        item.inputs["Factor"].default_value = factor
    else:
        nt.links.new(factor, item.inputs["Factor"])
    if isinstance(color_a, tuple):
        item.inputs[6].default_value = (*color_a, 1.0)
    else:
        nt.links.new(color_a, item.inputs[6])
    if isinstance(color_b, tuple):
        item.inputs[7].default_value = (*color_b, 1.0)
    else:
        nt.links.new(color_b, item.inputs[7])
    return item.outputs[2]


def distance_mask(nt, x, y, z, location=(0, 0)):
    combine = nt.nodes.new("ShaderNodeCombineXYZ")
    combine.location = location
    for socket, value in zip(combine.inputs, (x, y, z)):
        if isinstance(value, (int, float)):
            socket.default_value = value
        else:
            nt.links.new(value, socket)
    return combine


def build_skin_material(out_dir: Path) -> tuple[bpy.types.Material, dict[str, bpy.types.Image]]:
    mat = bpy.data.materials.new("SkinProcedural")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    links = nt.links

    output = node(nt, "ShaderNodeOutputMaterial", (900, 0))
    bsdf = node(nt, "ShaderNodeBsdfPrincipled", (600, 0))
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["IOR"].default_value = 1.4
    links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])

    texcoord = node(nt, "ShaderNodeTexCoord", (-1200, 0))
    separate = node(nt, "ShaderNodeSeparateXYZ", (-1000, 0))
    links.new(texcoord.outputs["Object"], separate.inputs["Vector"])
    x, y, z = separate.outputs["X"], separate.outputs["Y"], separate.outputs["Z"]
    abs_x = math_node(nt, "ABSOLUTE", x, location=(-850, -200))

    macro_noise = node(nt, "ShaderNodeTexNoise", (-850, 300))
    macro_noise.inputs["Scale"].default_value = 5.5
    macro_noise.inputs["Detail"].default_value = 4.0
    macro_noise.inputs["Roughness"].default_value = 0.55
    links.new(texcoord.outputs["Object"], macro_noise.inputs["Vector"])

    mottling_noise = node(nt, "ShaderNodeTexNoise", (-850, 520))
    mottling_noise.inputs["Scale"].default_value = 140.0
    mottling_noise.inputs["Detail"].default_value = 3.0
    links.new(texcoord.outputs["Object"], mottling_noise.inputs["Vector"])

    skin_a = (0.56, 0.25, 0.16)
    skin_b = (0.43, 0.17, 0.10)
    base = mix_color(nt, macro_noise.outputs["Fac"], skin_a, skin_b, (-620, 300))
    base = mix_color(nt, 0.10, base, (0.34, 0.13, 0.08), (-450, 300))

    lip_band = math_node(nt, "MULTIPLY",
        smooth(nt, y, 154.6, 155.2, (-850, -420)),
        math_node(nt, "SUBTRACT", 1.0, smooth(nt, y, 156.3, 157.0, (-850, -560)), location=(-680, -500)),
        location=(-500, -420))
    lip_band = math_node(nt, "MULTIPLY", lip_band, smooth(nt, z, 10.6, 11.6, (-680, -640)), location=(-340, -440))
    lip_band = math_node(nt, "MULTIPLY", lip_band,
        math_node(nt, "SUBTRACT", 1.0, smooth(nt, abs_x, 2.5, 3.2, (-680, -760)), location=(-340, -600)),
        location=(-200, -440), clamp=True)
    base = mix_color(nt, lip_band, base, (0.36, 0.095, 0.085), (-20, 250))

    brow_band = math_node(nt, "MULTIPLY",
        smooth(nt, y, 162.5, 163.0, (-850, -900)),
        math_node(nt, "SUBTRACT", 1.0, smooth(nt, y, 164.0, 164.5, (-850, -1020)), location=(-680, -960)),
        location=(-500, -900))
    brow_band = math_node(nt, "MULTIPLY", brow_band, smooth(nt, z, 11.2, 12.0, (-680, -1080)), location=(-340, -920))
    brow_band = math_node(nt, "MULTIPLY", brow_band,
        math_node(nt, "MULTIPLY",
            math_node(nt, "SUBTRACT", 1.0, smooth(nt, abs_x, 1.0, 1.35, (-680, -1180)), location=(-340, -1140)),
            smooth(nt, abs_x, 5.4, 6.0, (-680, -1280)),
            location=(-200, -1100)),
        location=(-60, -920))
    base = mix_color(nt, brow_band, base, (0.09, 0.05, 0.03), (170, 220))

    ear_band = math_node(nt, "MULTIPLY", smooth(nt, abs_x, 6.1, 6.8, (-850, -1400)), smooth(nt, y, 157.0, 159.0, (-680, -1440)), location=(-500, -1400))
    ear_band = math_node(nt, "MULTIPLY", ear_band,
        math_node(nt, "MULTIPLY", smooth(nt, z, -4.0, -2.0, (-680, -1520)),
            math_node(nt, "SUBTRACT", 1.0, smooth(nt, z, 4.5, 6.0, (-680, -1600)), location=(-500, -1540)),
            location=(-340, -1500)),
        location=(-180, -1420))
    base = mix_color(nt, ear_band, base, (0.48, 0.14, 0.12), (300, 180))

    nose_band = math_node(nt, "MULTIPLY", smooth(nt, y, 157.0, 158.0, (-850, -1750)), smooth(nt, z, 12.5, 13.2, (-680, -1780)), location=(-500, -1750))
    nose_band = math_node(nt, "MULTIPLY", nose_band,
        math_node(nt, "SUBTRACT", 1.0, smooth(nt, abs_x, 1.3, 1.9, (-680, -1850)), location=(-500, -1830)),
        location=(-340, -1750))
    base = mix_color(nt, nose_band, base, (0.50, 0.18, 0.14), (430, 140))

    eye_l = distance_mask(nt, 3.56, 162.26, 11.55, (-1000, -2000))
    eye_r = distance_mask(nt, -3.56, 162.26, 11.55, (-1000, -2100))
    dist_l = nt.nodes.new("ShaderNodeVectorMath")
    dist_l.operation = "DISTANCE"
    dist_l.location = (-820, -2000)
    links.new(texcoord.outputs["Object"], dist_l.inputs[0])
    links.new(eye_l.outputs["Vector"], dist_l.inputs[1])
    dist_r = nt.nodes.new("ShaderNodeVectorMath")
    dist_r.operation = "DISTANCE"
    dist_r.location = (-820, -2100)
    links.new(texcoord.outputs["Object"], dist_r.inputs[0])
    links.new(eye_r.outputs["Vector"], dist_r.inputs[1])
    min_dist = math_node(nt, "MINIMUM", dist_l.outputs["Value"], dist_r.outputs["Value"], location=(-620, -2050))
    eye_band = math_node(nt, "SUBTRACT", 1.0, smooth(nt, min_dist, 1.6, 2.6, (-450, -2050)), location=(-300, -2050), clamp=True)
    eye_band = math_node(nt, "MULTIPLY", eye_band, 0.45, location=(-160, -2050))
    base = mix_color(nt, eye_band, base, (0.50, 0.22, 0.17), (560, 120))

    lash_dx = math_node(nt, "DIVIDE",
        math_node(nt, "ABSOLUTE", math_node(nt, "SUBTRACT", abs_x, 3.13, location=(-1000, -2250)), location=(-850, -2250)),
        1.28, location=(-700, -2250))
    lash_t = math_node(nt, "MAXIMUM",
        math_node(nt, "SUBTRACT", 1.0, math_node(nt, "MULTIPLY", lash_dx, lash_dx, location=(-560, -2350)), location=(-420, -2350)),
        0.0, location=(-280, -2350))
    lash_half = math_node(nt, "MAXIMUM",
        math_node(nt, "MULTIPLY", 0.48, math_node(nt, "POWER", lash_t, 0.65, location=(-140, -2350)), location=(20, -2350)),
        0.04, location=(160, -2350))
    lash_s = math_node(nt, "DIVIDE",
        math_node(nt, "ABSOLUTE", math_node(nt, "SUBTRACT", y, EYE_Y, location=(20, -2250)), location=(160, -2250)),
        lash_half, location=(320, -2300))
    lash_band = math_node(nt, "MULTIPLY",
        smooth(nt, lash_s, 0.80, 0.98, (480, -2350)),
        math_node(nt, "SUBTRACT", 1.0, smooth(nt, lash_s, 1.02, 1.18, (480, -2450)), location=(640, -2400)),
        location=(800, -2350))
    lash_band = math_node(nt, "MULTIPLY", lash_band, smooth(nt, z, 10.2, 11.4, (640, -2550)), location=(940, -2400))
    lash_band = math_node(nt, "MULTIPLY", lash_band, smooth(nt, abs_x, 2.1, 2.6, (940, -2650)), location=(1010, -2450))
    lash_band = math_node(nt, "MULTIPLY", lash_band,
        math_node(nt, "SUBTRACT", 1.0, smooth(nt, abs_x, 5.2, 5.8, (940, -2750)), location=(1080, -2730)),
        location=(1160, -2450))
    base = mix_color(nt, math_node(nt, "MULTIPLY", lash_band, 0.8, location=(1300, -2450)), base, (0.10, 0.045, 0.035), (1440, 110))

    freckle_noise = node(nt, "ShaderNodeTexVoronoi", (-850, 700))
    freckle_noise.feature = "F1"
    freckle_noise.inputs["Scale"].default_value = 95.0
    links.new(texcoord.outputs["Object"], freckle_noise.inputs["Vector"])
    freckles = math_node(nt, "SUBTRACT", 1.0, smooth(nt, freckle_noise.outputs["Distance"], 0.02, 0.075, (-620, 700)), location=(-450, 700), clamp=True)
    freckle_zone = math_node(nt, "MULTIPLY", smooth(nt, y, 156.0, 159.0, (-620, 820)), smooth(nt, abs_x, 0.0, 4.5, (-620, 900)), location=(-450, 820))
    freckle_zone = math_node(nt, "MULTIPLY", freckle_zone,
        smooth(nt, z, 4.0, 8.0, (-620, 980)),
        location=(-300, 840))
    freckles = math_node(nt, "MULTIPLY", freckles, freckle_zone, location=(-300, 700))
    base = mix_color(nt, math_node(nt, "MULTIPLY", freckles, 0.45, location=(-150, 700)), base, (0.30, 0.14, 0.09), (720, 100))

    noise_fine = math_node(nt, "MULTIPLY", mottling_noise.outputs["Fac"], 0.12, location=(-620, 520))
    base = mix_color(nt, noise_fine, base, (0.38, 0.15, 0.10), (860, 60))

    links.new(base, bsdf.inputs["Base Color"])

    pore = node(nt, "ShaderNodeTexNoise", (-620, -2350))
    pore.inputs["Scale"].default_value = 420.0
    pore.inputs["Detail"].default_value = 2.0
    pore.inputs["Roughness"].default_value = 0.6
    links.new(texcoord.outputs["Object"], pore.inputs["Vector"])
    bump = node(nt, "ShaderNodeBump", (-300, -2350))
    bump.inputs["Strength"].default_value = 0.28
    bump.inputs["Distance"].default_value = 0.0012
    links.new(pore.outputs["Fac"], bump.inputs["Height"])
    large = node(nt, "ShaderNodeTexNoise", (-620, -2500))
    large.inputs["Scale"].default_value = 55.0
    large.inputs["Detail"].default_value = 3.0
    links.new(texcoord.outputs["Object"], large.inputs["Vector"])
    bump2 = node(nt, "ShaderNodeBump", (-80, -2450))
    bump2.inputs["Strength"].default_value = 0.12
    bump2.inputs["Distance"].default_value = 0.002
    links.new(large.outputs["Fac"], bump2.inputs["Height"])
    links.new(bump.outputs["Normal"], bump2.inputs["Normal"])
    links.new(bump2.outputs["Normal"], bsdf.inputs["Normal"])

    rough_base = math_node(nt, "SUBTRACT", 0.62, math_node(nt, "MULTIPLY", mottling_noise.outputs["Fac"], 0.10, location=(-620, -2650)), location=(-450, -2650))
    rough_base = math_node(nt, "SUBTRACT", rough_base, math_node(nt, "MULTIPLY", lip_band, 0.24, location=(-450, -2750)), location=(-280, -2650), clamp=True)
    rough_base = math_node(nt, "SUBTRACT", rough_base, math_node(nt, "MULTIPLY", nose_band, 0.16, location=(-280, -2800)), location=(-110, -2650), clamp=True)
    links.new(rough_base, bsdf.inputs["Roughness"])

    sss_mask = math_node(nt, "ADD", 0.32,
        math_node(nt, "MULTIPLY", ear_band, 0.62, location=(-110, -3000)),
        location=(80, -2950), clamp=True)
    sss_mask = math_node(nt, "ADD", sss_mask,
        math_node(nt, "MULTIPLY", nose_band, 0.45, location=(80, -3050)),
        location=(250, -2950), clamp=True)
    sss_mask = math_node(nt, "ADD", sss_mask,
        math_node(nt, "MULTIPLY", lip_band, 0.4, location=(250, -3150)),
        location=(420, -2950), clamp=True)

    return mat, {"sss_mask": sss_mask}


def bake_skin(body: bpy.types.Object, out_dir: Path) -> dict[str, Path]:
    mat, skin_sockets = build_skin_material(out_dir)
    body.data.materials.clear()
    body.data.materials.append(mat)
    sss_socket = skin_sockets["sss_mask"]

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 20
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 8
    scene.render.bake.use_selected_to_active = False
    bpy.context.view_layer.objects.active = body
    body.select_set(True)

    images = {
        "albedo": new_image("skin_albedo", 2048, "sRGB"),
        "normal": new_image("skin_normal", 2048, "Non-Color"),
        "rough": new_image("skin_rough", 1024, "Non-Color"),
        "sss": new_image("skin_sss", 1024, "Non-Color"),
    }
    nodes = mat.node_tree.nodes
    image_nodes = {}
    for name, image in images.items():
        image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = image
        image_node.location = (900, -400 - 200 * len(image_nodes))
        image_nodes[name] = image_node

    def bake(name: str, kind: str, pass_filter=None):
        for item in nodes:
            item.select = False
        image_nodes[name].select = True
        nodes.active = image_nodes[name]
        print(f"baking {name}...")
        bpy.ops.object.bake(type=kind, pass_filter=pass_filter or set(), margin=8)
        image = images[name]
        path = out_dir / f"skin_{name}.png"
        image.filepath_raw = str(path)
        image.file_format = "PNG"
        image.save()
        print(f"  wrote {path.name} {path.stat().st_size // 1024} KB")

    bake("albedo", "DIFFUSE", {"COLOR"})
    bake("normal", "NORMAL")
    bake("rough", "ROUGHNESS")

    output = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
    surface = output.inputs["Surface"].links[0].from_socket
    emission = node(mat.node_tree, "ShaderNodeEmission", (600, -400))
    mat.node_tree.links.new(sss_socket, emission.inputs["Color"])
    mat.node_tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    bake("sss", "EMIT")
    mat.node_tree.links.new(surface, output.inputs["Surface"])
    mat.node_tree.nodes.remove(emission)

    result = {name: out_dir / f"skin_{name}.png" for name in images}
    for image in images.values():
        image.pack()
    return result


def export_material(paths: dict[str, Path]) -> bpy.types.Material:
    albedo = bpy.data.images.load(str(paths["albedo"]))
    normal = bpy.data.images.load(str(paths["normal"]))
    rough = bpy.data.images.load(str(paths["rough"]))
    albedo.colorspace_settings.name = "sRGB"
    normal.colorspace_settings.name = "Non-Color"
    rough.colorspace_settings.name = "Non-Color"

    mat = bpy.data.materials.new("Skin")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["IOR"].default_value = 1.4

    tex = nodes.new("ShaderNodeTexImage")
    tex.image = albedo
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    tex_n = nodes.new("ShaderNodeTexImage")
    tex_n.image = normal
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(tex_n.outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    tex_r = nodes.new("ShaderNodeTexImage")
    tex_r.image = rough
    links.new(tex_r.outputs["Color"], bsdf.inputs["Roughness"])
    return mat


def existing_textures(out_dir: Path) -> dict[str, Path]:
    names = ("albedo", "normal", "rough", "sss")
    paths = {name: out_dir / f"skin_{name}.png" for name in names}
    return paths if all(path.exists() for path in paths.values()) else {}


def main() -> None:
    args = parse_args()
    source = Path(args.source).resolve()
    out_path = Path(args.out).resolve()
    out_dir = out_path.parent
    out_dir.mkdir(parents=True, exist_ok=True)

    body = import_body(source)
    slim_lower_face(body)
    add_build_keys(body)
    add_feature_keys(body)
    pose_body(body)
    rims = open_eyes(body)
    build_hair_styles(body, out_dir, args.styles)
    if args.hair_only:
        return

    if args.bake:
        bake_skin(body, out_dir)
    if args.bake_ao:
        bake_ao(body, out_dir)
    paint_skin(body, rims, out_dir)
    texture_paths = existing_textures(out_dir)

    if texture_paths:
        body.data.materials.clear()
        body.data.materials.append(export_material(texture_paths))
    else:
        simple = simple_material("SkinPreview", (0.56, 0.30, 0.22), 0.52)
        body.data.materials.clear()
        body.data.materials.append(simple)

    eye_objects = build_eyes(body, rims, out_dir)
    brow_objects = build_brows(body)
    hair_objects = build_hair_cap(body, out_dir)
    garment = build_garment(body, out_dir)
    trousers = build_garment(body, out_dir, "trousers", trouser_edge, 0.28)

    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    for obj in [body, *eye_objects, *brow_objects, *hair_objects, garment, trousers]:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_texcoords=True,
        export_normals=True,
        export_morph=True,
        export_morph_normal=False,
        export_morph_animation=False,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_extras=True,
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_draco_mesh_compression_enable=False,
        export_vertex_color="ACTIVE",
    )
    size = out_path.stat().st_size
    print(f"wrote {out_path} {size / (1024 * 1024):.2f} MB")


if __name__ == "__main__":
    main()
