"""Save the head surface of each unpacked VALID avatar for build_probe's face fitting.

VALID has six Black base avatars on one shared mesh; source-avatar redistribution
rights need separate verification. Axes: x side, y up, z front, in centimetres.

    blender --background --python extract_valid_heads.py -- <unpacked dir> <out dir>
"""
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np


def head_island(bm, co):
    """The connected piece of the mesh that reaches the top of the head."""
    bm.verts.ensure_lookup_table()
    start = int(np.argmax(co[:, 1]))
    seen = {start}
    stack = [start]
    while stack:
        vert = bm.verts[stack.pop()]
        for edge in vert.link_edges:
            other = edge.other_vert(vert).index
            if other not in seen:
                seen.add(other)
                stack.append(other)
    return np.array(sorted(seen))


def boundary_loops(bm, keep):
    adjacent: dict[int, list[int]] = {}
    for edge in bm.edges:
        if edge.is_boundary and edge.verts[0].index in keep:
            a, b = edge.verts[0].index, edge.verts[1].index
            adjacent.setdefault(a, []).append(b)
            adjacent.setdefault(b, []).append(a)
    seen: set[int] = set()
    loops = []
    for start in adjacent:
        if start in seen:
            continue
        stack, loop = [start], []
        while stack:
            vert = stack.pop()
            if vert not in seen:
                seen.add(vert)
                loop.append(vert)
                stack += adjacent[vert]
        loops.append(np.array(loop))
    return loops


def extract(path: Path, out_dir: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    bpy.context.view_layer.update()
    body = bpy.data.objects["H_DDS_HighRes"]
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    world = np.array([list(evaluated.matrix_world @ v.co) for v in mesh.vertices]) * 100.0
    evaluated.to_mesh_clear()
    co = np.stack([world[:, 0], world[:, 2], -world[:, 1]], axis=1)

    bm = bmesh.new()
    bm.from_mesh(body.data)
    bm.edges.ensure_lookup_table()
    island = head_island(bm, co)
    keep = set(island.tolist())
    loops = boundary_loops(bm, keep)
    remap = -np.ones(len(co), dtype=np.int64)
    remap[island] = np.arange(len(island))
    tris = []
    for face in bm.faces:
        if face.verts[0].index not in keep:
            continue
        verts = [v.index for v in face.verts]
        for i in range(1, len(verts) - 1):
            tris.append((remap[verts[0]], remap[verts[i]], remap[verts[i + 1]]))
    bm.free()

    points = co[island]

    def find_hole(test):
        for loop in loops:
            centre = co[loop].mean(axis=0)
            if test(centre, co[loop]):
                return remap[loop]
        raise SystemExit(f"{path.name}: hole not found")

    top = points[:, 1].max()
    eye_left = find_hole(lambda c, p: 1.0 < c[0] < 5.5 and top - 16 < c[1] < top - 8 and len(p) < 60)
    eye_right = find_hole(lambda c, p: -5.5 < c[0] < -1.0 and top - 16 < c[1] < top - 8 and len(p) < 60)
    mouth = find_hole(lambda c, p: abs(c[0]) < 0.5 and top - 24 < c[1] < top - 14 and len(p) < 90)
    np.savez_compressed(
        out_dir / f"{path.stem.replace('_Default', '')}.npz",
        co=points.astype(np.float32),
        tris=np.array(tris, dtype=np.int32),
        eye_left=eye_left,
        eye_right=eye_right,
        mouth=mouth,
    )
    print(f"{path.stem}: {len(points)} head verts, {len(tris)} tris, top {top:.1f}")


def main() -> None:
    src, out = sys.argv[sys.argv.index("--") + 1:]
    out_dir = Path(out)
    out_dir.mkdir(parents=True, exist_ok=True)
    for path in sorted(Path(src).glob("*_Default.glb")):
        extract(path, out_dir)


main()
