from __future__ import annotations

from dataclasses import replace
from pathlib import Path

from . import engines, media, queue
from .manifest import Project


def run(
    project: Project,
    shot_ids: list[str] | None = None,
    preview: bool = False,
    resume: bool = True,
) -> Path:
    if project.kind != "film":
        raise ValueError(f"{project.id} is a game; use studio build")

    adapter = engines.get(project.engine)
    width, height = project.resolution
    if preview:
        width = max(2, width // 2)
        height = max(2, height // 2)

    frames_root = project.media_dir / "_frames"
    frames_root.mkdir(parents=True, exist_ok=True)
    state_path = frames_root / "state.json"
    state = queue.load_state(state_path)

    selected = project.shots
    if shot_ids:
        known = {shot.id for shot in project.shots}
        missing = [shot_id for shot_id in shot_ids if shot_id not in known]
        if missing:
            raise ValueError(f"unknown shot(s): {', '.join(missing)}")
        selected = [shot for shot in project.shots if shot.id in shot_ids]

    for shot in selected:
        out = frames_root / shot.id if len(project.shots) > 1 else frames_root
        source = queue.source_hash(project, shot)
        settings = queue.settings_hash(project, shot, width, height, preview)
        if resume and queue.shot_complete(out, shot, state, source, settings):
            print(f"skip {project.id}/{shot.id}: complete")
            continue
        media.clear_dir(out)
        out.mkdir(parents=True, exist_ok=True)
        adapter.prepare(project)
        rendered = replace(project, resolution=(width, height))
        adapter.render(rendered, shot, out)
        produced = len(list(out.glob("frame_*.png")))
        if produced != shot.frames:
            raise RuntimeError(
                f"{project.id}/{shot.id} produced {produced} frames, expected {shot.frames}"
            )
        queue.mark_complete(state, shot, source, settings)
        queue.save_state(state_path, state)
        print(f"done {project.id}/{shot.id}: {produced} frames")

    complete = all(
        queue.shot_complete(
            frames_root / shot.id if len(project.shots) > 1 else frames_root,
            shot,
            state,
            queue.source_hash(project, shot),
            queue.settings_hash(project, shot, width, height, preview),
        )
        for shot in project.shots
    )
    if not complete:
        print(f"partial {project.id}: remaining shots are not encoded yet")
        return frames_root

    if preview:
        media.encode_preview(project, frames_root, width, height)
    else:
        media.encode_project(project, frames_root, width, height)
    return frames_root
