from __future__ import annotations

import json
import struct
from pathlib import Path


def inspect(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError(f"{path.name} is too small to be a GLB")
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"{path.name} is not a GLB")
    if version != 2:
        raise ValueError(f"{path.name} is glTF version {version}, expected 2")
    if length != len(data):
        raise ValueError(f"{path.name} length header says {length}, file is {len(data)}")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError(f"{path.name} first chunk is not JSON")
    document = json.loads(data[20:20 + chunk_length])
    return {
        "version": version,
        "animations": len(document.get("animations") or []),
        "meshes": len(document.get("meshes") or []),
        "nodes": len(document.get("nodes") or []),
    }
