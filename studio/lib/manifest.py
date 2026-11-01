from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .config import ROOT

ID_RE = re.compile(r"^\d{3}-[a-z0-9-]+$")
ENGINE_BY_TYPE = {"2d": "python", "3d": "blender", "game": "godot"}


@dataclass
class Project:
    id: str
    type: str
    title: str
    summary: str
    tags: list[str]
    engine: str
    entry: str
    resolution: tuple[int, int]
    fps: int
    frames: int
    poster_time: float
    outputs: list[str]
    root: Path = field(default=ROOT)

    @property
    def media_dir(self) -> Path:
        return ROOT / "media" / self.id


def load(project_dir: Path) -> Project:
    data = yaml.safe_load((project_dir / "project.yaml").read_text(encoding="utf-8"))
    render = data.get("render") or {}
    resolution = tuple(render.get("resolution") or (1920, 1080))
    return Project(
        id=str(data["id"]),
        type=str(data["type"]),
        title=str(data["title"]),
        summary=str(data.get("summary", "")),
        tags=[str(t) for t in data.get("tags") or []],
        engine=str(data["engine"]),
        entry=str(data["entry"]),
        resolution=(int(resolution[0]), int(resolution[1])),
        fps=int(render.get("fps", 24)),
        frames=int(render.get("frames", 1)),
        poster_time=float(render.get("poster_time", 1.0)),
        outputs=[str(o) for o in data.get("outputs") or []],
        root=project_dir,
    )


def load_all(projects_root: Path | None = None) -> list[Project]:
    projects_root = projects_root or (ROOT / "projects")
    found = []
    for manifest_path in sorted(projects_root.glob("*/project.yaml")):
        if manifest_path.parent.name.startswith("_"):
            continue
        found.append(load(manifest_path.parent))
    return found


def validate(project: Project) -> list[str]:
    errors: list[str] = []
    if not ID_RE.match(project.id):
        errors.append(f"id '{project.id}' must look like 001-name")
    if project.type not in ENGINE_BY_TYPE:
        errors.append(f"type '{project.type}' must be one of 2d, 3d, game")
    elif ENGINE_BY_TYPE[project.type] != project.engine:
        errors.append(
            f"engine '{project.engine}' does not match type '{project.type}' "
            f"(expected '{ENGINE_BY_TYPE[project.type]}')"
        )
    if not (project.root / project.entry).exists():
        errors.append(f"entry '{project.entry}' does not exist in {project.root}")
    width, height = project.resolution
    if width <= 0 or height <= 0:
        errors.append("resolution must be positive")
    if width > 1920 or height > 1080:
        errors.append("resolution must not exceed 1080p on this machine")
    if project.fps <= 0:
        errors.append("fps must be positive")
    if project.frames <= 0:
        errors.append("frames must be positive")
    if not project.outputs:
        errors.append("at least one output is required")
    for output in project.outputs:
        target = (ROOT / output).resolve()
        if not str(target).startswith(str(ROOT.resolve())):
            errors.append(f"output '{output}' escapes the repo root")
    return errors


def find(project_id: str) -> Project:
    for project in load_all():
        if project.id == project_id:
            return project
    raise SystemExit(f"unknown project '{project_id}'")
