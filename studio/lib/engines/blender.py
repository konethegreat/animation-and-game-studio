from __future__ import annotations

from pathlib import Path

from .. import config
from .base import EngineAdapter, count_frames, run_engine


class BlenderAdapter(EngineAdapter):
    name = "blender"
    tool = "blender"
    kinds = frozenset({"film"})

    def _exe(self) -> str:
        exe = config.find_tool("blender")
        if not exe:
            raise RuntimeError("blender not found; run studio doctor")
        return str(exe)

    def command(self, project, shot, out: Path) -> list[str]:
        width, height = project.resolution
        return [
            self._exe(), "-b", "--python", str(project.root / shot.entry), "--",
            "--out", str(out), "--frames-start", "1", "--frames-end", str(shot.frames),
            "--width", str(width), "--height", str(height),
            *project.engine_args,
        ]

    def command_export(self, project, target: Path) -> list[str]:
        return [
            self._exe(), "-b", "--python", str(project.root / project.entry), "--",
            "--export-glb", str(target),
        ]

    def render(self, project, shot, out: Path) -> int:
        out.mkdir(parents=True, exist_ok=True)
        run_engine(self.command(project, shot, out), project.id)
        return count_frames(out)

    def export(self, project, target: Path) -> Path:
        target.parent.mkdir(parents=True, exist_ok=True)
        run_engine(self.command_export(project, target), project.id)
        return target
