from __future__ import annotations

from pathlib import Path

from .. import godot as godot_tool
from .base import EngineAdapter


class GodotAdapter(EngineAdapter):
    name = "godot"
    tool = "godot"
    kinds = frozenset({"game"})

    def build(self, project, out: Path, target: str = "web") -> Path:
        if target == "web":
            godot_tool.export_web(project.root, out)
            return out
        if target == "windows":
            return godot_tool.export_windows(project.root, out, f"{project.id}.exe")
        raise ValueError(f"godot cannot build target {target}")
