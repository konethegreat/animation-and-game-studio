from __future__ import annotations

from dataclasses import replace
from pathlib import Path

from . import media
from .config import find_tool


def _shot_master(shot, shot_dir: Path, fps: int) -> Path:
    ffmpeg = find_tool("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found; run studio doctor")
    shot_mp4 = shot_dir / "shot.mp4"
    media._run([
        str(ffmpeg), "-y", "-framerate", str(fps), "-start_number", "1",
        "-i", str(shot_dir / "frame_%04d.png"),
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "12",
        "-pix_fmt", "yuv420p", str(shot_mp4),
    ])
    return shot_mp4


def cut(project, shot_ids: list[str], out: Path, audio: Path | None = None) -> Path:
    by_id = {shot.id: shot for shot in project.shots}
    unknown = [shot_id for shot_id in shot_ids if shot_id not in by_id]
    if unknown:
        raise ValueError(f"unknown shot(s): {', '.join(unknown)}")
    if not shot_ids:
        raise ValueError("select at least one shot")

    frames_root = project.media_dir / "_frames"
    selected = [by_id[shot_id] for shot_id in shot_ids]
    for shot in selected:
        shot_dir = frames_root / shot.id
        produced = len(list(shot_dir.glob("frame_*.png")))
        if produced != shot.frames:
            raise ValueError(
                f"shot '{shot.id}' has {produced} frames, expected {shot.frames}"
            )

    pilot = replace(project, shots=selected, frames=sum(s.frames for s in selected))
    if len(selected) == 1:
        master = _shot_master(selected[0], frames_root / selected[0].id, project.fps)
    else:
        parts = [
            _shot_master(shot, frames_root / shot.id, project.fps) for shot in selected
        ]
        concat = frames_root / "_cut.txt"
        concat.write_text(
            "\n".join(f"file '{part.as_posix()}'" for part in parts) + "\n",
            encoding="utf-8",
        )
        master = frames_root / "_cut_master.mp4"
        ffmpeg = find_tool("ffmpeg")
        media._run([
            str(ffmpeg), "-y", "-f", "concat", "-safe", "0", "-i", str(concat),
            "-c", "copy", str(master),
        ])

    out = out.resolve()
    out.parent.mkdir(parents=True, exist_ok=True)
    media._final_mp4(pilot, master, out, audio)
    info = media.probe(out)
    expected = pilot.frames / project.fps
    if abs(info["duration"] - expected) > 0.25:
        raise ValueError(
            f"{out.name} runs {info['duration']:.2f}s, expected {expected:.2f}s"
        )
    media.check_budget(out)
    width, height = project.resolution
    print(
        f"cut {len(selected)} shot(s) {width}x{height} {project.fps}fps "
        f"{info['duration']:.2f}s -> {out}"
    )
    return out
