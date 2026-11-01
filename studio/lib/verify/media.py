from __future__ import annotations

from pathlib import Path

from .. import media
from ..config import ROOT

ALL_SUFFIXES = {".mp4", ".webm", ".gif", ".jpg", ".jpeg", ".png", ".glb"}


def _render_paths(project) -> list[Path]:
    paths = [
        path
        for path in (
            media.resolve_mp4(project),
            media.resolve_webm(project),
            media.resolve_gif(project),
        )
        if path
    ]
    paths.append(media.resolve_poster(project))
    return paths


def _label(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def check(project, stage: str = "all") -> list[str]:
    if stage == "render":
        paths = _render_paths(project)
    else:
        paths = [
            ROOT / output if not Path(output).is_absolute() else Path(output)
            for output in project.outputs
            if Path(output).suffix.lower() in ALL_SUFFIXES
        ]
    problems: list[str] = []
    for full in paths:
        name = _label(full)
        if not full.exists():
            problems.append(f"missing output {name}")
            continue
        try:
            media.check_budget(full)
        except ValueError as exc:
            problems.append(str(exc))
        if full.suffix.lower() in {".mp4", ".webm"}:
            try:
                info = media.probe(full)
            except RuntimeError as exc:
                problems.append(str(exc))
                continue
            if (info["width"], info["height"]) != project.resolution:
                problems.append(
                    f"{name} is {info['width']}x{info['height']}, "
                    f"expected {project.resolution[0]}x{project.resolution[1]}"
                )
            if abs(info["fps"] - project.fps) > 0.06:
                problems.append(f"{name} is {info['fps']:.2f} fps, expected {project.fps}")
    return problems
