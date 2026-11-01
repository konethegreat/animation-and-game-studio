from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from . import config, media
from .manifest import Project


def _run(cmd: list[str], label: str) -> None:
    print(f"[{label}] {' '.join(cmd[:4])} ...")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")


def run(project: Project) -> Path:
    frames = project.media_dir / "_frames"
    media.clear_dir(frames)
    width, height = project.resolution

    if project.engine == "python":
        cmd = [
            sys.executable, str(project.root / project.entry),
            "--out", str(frames), "--frames", str(project.frames),
            "--width", str(width), "--height", str(height),
        ]
        _run(cmd, project.id)
    elif project.engine == "blender":
        blender = config.find_tool("blender")
        if not blender:
            raise RuntimeError("blender not found; run studio doctor")
        cmd = [
            str(blender), "-b", "--python", str(project.root / project.entry), "--",
            "--out", str(frames),
            "--frames-start", "1", "--frames-end", str(project.frames),
            "--width", str(width), "--height", str(height),
        ]
        _run(cmd, project.id)
    else:
        raise ValueError(f"project {project.id} cannot be rendered as video")

    produced = sorted(frames.glob("frame_*.png"))
    if len(produced) != project.frames:
        raise RuntimeError(
            f"{project.id} produced {len(produced)} frames, expected {project.frames}"
        )

    media.encode(frames, project.media_dir, project.fps, width, height)
    return frames
