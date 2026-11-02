from __future__ import annotations

from pathlib import Path

from .. import godot as godot_tool
from .base import EngineAdapter


class GodotAdapter(EngineAdapter):
    name = "godot"
    tool = "godot"
    kinds = frozenset({"game"})

    def build(self, project, out: Path) -> Path:
        godot_tool.export_web(project.root, out)
        return out
