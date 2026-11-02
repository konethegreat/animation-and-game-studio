from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from .config import ROOT, find_ffprobe, find_tool

BUDGET_MB = {
    ".gif": 8.0,
    ".mp4": 20.0,
    ".webm": 20.0,
    ".jpg": 0.5,
    ".jpeg": 0.5,
    ".png": 2.0,
    ".glb": 5.0,
}


def parse_fps(value: str) -> float:
    if "/" in value:
        num, den = value.split("/", 1)
        return float(num) / float(den) if float(den) else 0.0
    return float(value)


def probe(path: Path) -> dict:
    ffprobe = find_ffprobe()
    if not ffprobe:
        raise RuntimeError("ffprobe not found; run studio doctor")
    cmd = [
        str(ffprobe), "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height,r_frame_rate,codec_name",
        "-show_entries", "format=duration", "-of", "json", str(path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise RuntimeError(f"ffprobe failed for {path}: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    stream = (data.get("streams") or [{}])[0]
    return {
        "width": int(stream.get("width", 0)),
        "height": int(stream.get("height", 0)),
        "fps": parse_fps(stream.get("r_frame_rate", "0/1")),
        "codec": stream.get("codec_name", ""),
        "duration": float((data.get("format") or {}).get("duration", 0.0)),
    }


def check_budget(path: Path) -> None:
    limit = BUDGET_MB.get(path.suffix.lower())
    if limit is None:
        return
    size_mb = path.stat().st_size / (1024 * 1024)
    if size_mb > limit:
        raise ValueError(
            f"{path.name} exceeds {limit} MB budget ({size_mb:.2f} MB)"
        )


def assert_spec(
    path: Path, width: int, height: int, fps: float, tol: float = 0.06
) -> dict:
    info = probe(path)
    if (info["width"], info["height"]) != (width, height):
        raise ValueError(
            f"{path.name} is {info['width']}x{info['height']}, expected {width}x{height}"
        )
    if abs(info["fps"] - fps) > tol:
        raise ValueError(f"{path.name} is {info['fps']:.2f} fps, expected {fps}")
    check_budget(path)
    return info


def _run(cmd: list[str]) -> None:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        tail = "\n".join((result.stderr or "").strip().splitlines()[-8:])
        raise RuntimeError(f"command failed: {' '.join(cmd[:3])} ...\n{tail}")


def resolve_mp4(project) -> Path | None:
    return project.output_path(".mp4")


def resolve_webm(project) -> Path | None:
    return project.output_path(".webm")


def resolve_gif(project) -> Path | None:
    return project.output_path(".gif")


def resolve_poster(project) -> Path:
    for output in project.outputs:
        path = Path(output)
        if path.suffix.lower() in {".jpg", ".jpeg", ".png"} and path.stem.lower().startswith("poster"):
            return ROOT / output
    return project.media_dir / "poster.jpg"


def audio_source(project) -> Path | None:
    for key in ("mix", "score"):
        value = project.audio.get(key)
        if value:
            path = project.root / value
            if not path.exists():
                raise RuntimeError(f"declared audio '{key}' is missing: {path}")
            return path
    return None


def has_audio(path: Path) -> bool:
    ffprobe = find_ffprobe()
    if not ffprobe:
        raise RuntimeError("ffprobe not found; run studio doctor")
    result = subprocess.run(
        [str(ffprobe), "-v", "error", "-select_streams", "a:0",
         "-show_entries", "stream=codec_name", "-of", "csv=p=0", str(path)],
        capture_output=True, text=True, timeout=60,
    )
    return result.returncode == 0 and bool((result.stdout or "").strip())


def measure_loudness(path: Path) -> dict:
    ffmpeg = find_tool("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found; run studio doctor")
    result = subprocess.run(
        [str(ffmpeg), "-hide_banner", "-nostats", "-i", str(path),
         "-af", "loudnorm=I=-14:TP=-1:LRA=11:print_format=json",
         "-f", "null", "-"],
        capture_output=True, text=True, timeout=300,
    )
    text = result.stderr or ""
    start = text.rfind("{")
    end = text.rfind("}")
    if result.returncode != 0 or start == -1 or end == -1:
        raise RuntimeError(f"loudness measurement failed for {path}")
    return json.loads(text[start:end + 1])


def _encode_master(project, frames_root: Path, width: int, height: int) -> Path:
    ffmpeg = find_tool("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found; run studio doctor")
    master = frames_root / "_master.mp4"
    if len(project.shots) == 1:
        _run([
            str(ffmpeg), "-y", "-framerate", str(project.fps), "-start_number", "1",
            "-i", str(frames_root / "frame_%04d.png"),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "12",
            "-pix_fmt", "yuv420p", str(master),
        ])
        return master
    concat = frames_root / "_concat.txt"
    lines = []
    for shot in project.shots:
        shot_dir = frames_root / shot.id
        shot_mp4 = shot_dir / "shot.mp4"
        _run([
            str(ffmpeg), "-y", "-framerate", str(project.fps), "-start_number", "1",
            "-i", str(shot_dir / "frame_%04d.png"),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "12",
            "-pix_fmt", "yuv420p", str(shot_mp4),
        ])
        lines.append(f"file '{shot_mp4.as_posix()}'")
    concat.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _run([
        str(ffmpeg), "-y", "-f", "concat", "-safe", "0", "-i", str(concat),
        "-c", "copy", str(master),
    ])
    return master


def _final_mp4(project, master: Path, mp4: Path, audio: Path | None) -> None:
    ffmpeg = find_tool("ffmpeg")
    cmd = [str(ffmpeg), "-y", "-i", str(master)]
    if audio:
        cmd += ["-i", str(audio)]
    cmd += ["-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p"]
    if audio:
        cmd += ["-c:a", "aac", "-b:a", "160k", "-af", "loudnorm=I=-14:TP=-1:LRA=11", "-shortest"]
    cmd += ["-movflags", "+faststart", str(mp4)]
    _run(cmd)


def encode_project(project, frames_root: Path, width: int, height: int) -> dict[str, Path]:
    mp4 = resolve_mp4(project)
    webm = resolve_webm(project)
    gif = resolve_gif(project)
    poster = resolve_poster(project)
    if not mp4 and not webm:
        raise ValueError(f"{project.id} declares no video output")
    mp4.parent.mkdir(parents=True, exist_ok=True)
    master = _encode_master(project, frames_root, width, height)
    audio = audio_source(project)
    outs: dict[str, Path] = {}
    if mp4:
        _final_mp4(project, master, mp4, audio)
        outs["mp4"] = mp4
        info = assert_spec(mp4, width, height, project.fps)
        print(
            f"encoded {width}x{height} {project.fps}fps {info['duration']:.2f}s "
            f"({info['codec']}) -> {mp4}"
        )
    if webm:
        cmd = [str(find_tool("ffmpeg")), "-y", "-i", str(mp4 or master)]
        if audio and not mp4:
            cmd += ["-i", str(audio)]
        cmd += ["-c:v", "libvpx-vp9", "-crf", "34", "-b:v", "0", "-row-mt", "1",
                "-deadline", "good", "-cpu-used", "4"]
        if audio:
            cmd += ["-c:a", "libopus", "-b:a", "96k", "-af", "loudnorm=I=-14:TP=-1:LRA=11", "-shortest"]
        cmd += [str(webm)]
        _run(cmd)
        check_budget(webm)
        outs["webm"] = webm
    if gif:
        gif.parent.mkdir(parents=True, exist_ok=True)
        palette = gif.parent / "_palette.png"
        fps = project.gif_fps or project.fps
        scale = f"fps={fps},scale={project.gif_width}:-1:flags=lanczos"
        dither = "bayer:bayer_scale=3" if project.gif_dither == "bayer" else "none"
        _run([
            str(find_tool("ffmpeg")), "-y", "-i", str(mp4 or master), "-vf",
            f"{scale},palettegen=max_colors={project.gif_colors}", str(palette),
        ])
        _run([
            str(find_tool("ffmpeg")), "-y", "-i", str(mp4 or master), "-i", str(palette),
            "-lavfi", f"{scale}[x];[x][1:v]"
            f"paletteuse=dither={dither}", str(gif),
        ])
        palette.unlink(missing_ok=True)
        check_budget(gif)
        outs["gif"] = gif
    if poster:
        poster.parent.mkdir(parents=True, exist_ok=True)
        _run([
            str(find_tool("ffmpeg")), "-y", "-ss", f"{project.poster_time:g}",
            "-i", str(mp4 or master), "-frames:v", "1", "-q:v", "3", str(poster),
        ])
        check_budget(poster)
        outs["poster"] = poster
    return outs


def encode_preview(project, frames_root: Path, width: int, height: int) -> Path:
    ffmpeg = find_tool("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found; run studio doctor")
    master = _encode_master(project, frames_root, width, height)
    out = project.media_dir / "_preview" / "preview.mp4"
    out.parent.mkdir(parents=True, exist_ok=True)
    _run([
        str(ffmpeg), "-y", "-i", str(master), "-c:v", "libx264",
        "-preset", "veryfast", "-crf", "22", "-pix_fmt", "yuv420p", str(out),
    ])
    assert_spec(out, width, height, project.fps)
    print(f"preview -> {out}")
    return out


def clear_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)
