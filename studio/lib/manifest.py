from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import assets, engines
from .config import ROOT

ID_RE = re.compile(r"^\d{3}-[a-z0-9-]+$")
KINDS = {"film", "game"}


@dataclass(frozen=True)
class Shot:
    id: str
    entry: str
    frames: int
    still: bool = False


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
    kind: str = "film"
    shots: list[Shot] = field(default_factory=list)
    audio: dict[str, str] = field(default_factory=dict)
    samples: int = 0
    device: str = ""
    engine_args: list[str] = field(default_factory=list)
    assets: list[str] = field(default_factory=list)
    root: Path = field(default=ROOT)

    @property
    def media_dir(self) -> Path:
        return ROOT / "media" / self.id

    def output_path(self, suffix: str) -> Path | None:
        for output in self.outputs:
            if Path(output).suffix.lower() == suffix.lower():
                return ROOT / output
        return None

    def audio_paths(self) -> dict[str, Path]:
        return {key: self.root / value for key, value in self.audio.items()}


def load(project_dir: Path) -> Project:
    data = yaml.safe_load((project_dir / "project.yaml").read_text(encoding="utf-8"))
    render = data.get("render") or {}
    resolution = tuple(render.get("resolution") or (1920, 1080))
    entry = str(data["entry"])
    raw_shots = data.get("shots") or []
    shots = [
        Shot(
            id=str(item["id"]),
            entry=str(item.get("entry", entry)),
            frames=int(item["frames"]),
            still=bool(item.get("still", False)),
        )
        for item in raw_shots
    ]
    if not shots:
        total = int(render.get("frames", 1))
        shots = [Shot(id="main", entry=entry, frames=total)]
    frame_total = int(render.get("frames", sum(shot.frames for shot in shots)))
    return Project(
        id=str(data["id"]),
        type=str(data["type"]),
        title=str(data["title"]),
        summary=str(data.get("summary", "")),
        tags=[str(t) for t in data.get("tags") or []],
        engine=str(data["engine"]),
        entry=entry,
        resolution=(int(resolution[0]), int(resolution[1])),
        fps=int(render.get("fps", 24)),
        frames=frame_total,
        poster_time=float(render.get("poster_time", 1.0)),
        outputs=[str(o) for o in data.get("outputs") or []],
        kind=str(data.get("kind") or ("game" if data["type"] == "game" else "film")),
        shots=shots,
        audio={str(k): str(v) for k, v in (data.get("audio") or {}).items()},
        samples=int(render.get("samples", 0)),
        device=str(render.get("device", "")),
        engine_args=[str(a) for a in render.get("engine_args") or []],
        assets=[str(a) for a in data.get("assets") or []],
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
    if project.type not in {"2d", "3d", "game"}:
        errors.append("type must be one of 2d, 3d, game")
    if project.kind not in KINDS:
        errors.append("kind must be film or game")
    if not engines.known(project.engine):
        errors.append(f"unknown engine '{project.engine}'")
    elif project.kind in KINDS and not engines.supports(project.engine, project.kind):
        errors.append(
            f"engine '{project.engine}' cannot run kind '{project.kind}'"
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
    if not project.shots:
        errors.append("at least one shot is required")
    seen: set[str] = set()
    for shot in project.shots:
        if shot.id in seen:
            errors.append(f"shot id '{shot.id}' is duplicated")
        seen.add(shot.id)
        if shot.frames <= 0:
            errors.append(f"shot '{shot.id}' needs a positive frame count")
        if not (project.root / shot.entry).exists():
            errors.append(f"shot '{shot.id}' entry '{shot.entry}' does not exist")
    total = sum(shot.frames for shot in project.shots)
    if total != project.frames:
        errors.append(
            f"shots total {total} frames but render.frames says {project.frames}"
        )
    for key, value in project.audio.items():
        target = (project.root / value).resolve()
        if not str(target).startswith(str(project.root.resolve())):
            errors.append(f"audio '{key}' escapes the project root")
    known_assets = assets.ids()
    for asset_id in project.assets:
        if asset_id not in known_assets:
            errors.append(f"asset '{asset_id}' is not in assets/catalog.yaml")
    return errors


def find(project_id: str) -> Project:
    for project in load_all():
        if project.id == project_id:
            return project
    raise SystemExit(f"unknown project '{project_id}'")
