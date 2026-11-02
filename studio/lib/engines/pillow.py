from __future__ import annotations

import sys
from pathlib import Path

from .base import EngineAdapter, count_frames, run_engine


class PythonAdapter(EngineAdapter):
    name = "python"
    tool = "python"
    kinds = frozenset({"film"})

    def command(self, project, shot, out: Path) -> list[str]:
        width, height = project.resolution
        return [
            sys.executable, str(project.root / shot.entry),
            "--out", str(out), "--frames", str(shot.frames),
            "--width", str(width), "--height", str(height),
        ]

    def render(self, project, shot, out: Path) -> int:
        out.mkdir(parents=True, exist_ok=True)
        run_engine(self.command(project, shot, out), project.id)
        return count_frames(out)
