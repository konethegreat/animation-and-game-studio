from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

from .config import find_ffprobe, find_tool

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


def encode(
    frames_dir: Path, out_dir: Path, fps: int, width: int, height: int
) -> dict[str, Path]:
    ffmpeg = find_tool("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found; run studio doctor")
    out_dir.mkdir(parents=True, exist_ok=True)
    pattern = frames_dir / "frame_%04d.png"
    outs = {
        "mp4": out_dir / "reel.mp4",
        "webm": out_dir / "reel.webm",
        "gif": out_dir / "reel.gif",
        "poster": out_dir / "poster.jpg",
    }
    _run([
        str(ffmpeg), "-y", "-framerate", str(fps), "-start_number", "1",
        "-i", str(pattern), "-c:v", "libx264", "-preset", "slow", "-crf", "18",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(outs["mp4"]),
    ])
    _run([
        str(ffmpeg), "-y", "-i", str(outs["mp4"]), "-c:v", "libvpx-vp9",
        "-crf", "34", "-b:v", "0", "-row-mt", "1", "-deadline", "good",
        "-cpu-used", "4", str(outs["webm"]),
    ])
    palette = out_dir / "_palette.png"
    _run([
        str(ffmpeg), "-y", "-i", str(outs["mp4"]), "-vf",
        "fps=24,scale=960:-1:flags=lanczos,palettegen=max_colors=128",
        str(palette),
    ])
    _run([
        str(ffmpeg), "-y", "-i", str(outs["mp4"]), "-i", str(palette), "-lavfi",
        "fps=24,scale=960:-1:flags=lanczos[x];[x][1:v]"
        "paletteuse=dither=bayer:bayer_scale=3",
        str(outs["gif"]),
    ])
    palette.unlink(missing_ok=True)
    _run([
        str(ffmpeg), "-y", "-ss", "1", "-i", str(outs["mp4"]), "-frames:v", "1",
        "-q:v", "3", str(outs["poster"]),
    ])
    info = assert_spec(outs["mp4"], width, height, fps)
    for key in ("webm", "gif", "poster"):
        check_budget(outs[key])
    print(
        f"encoded {width}x{height} {fps}fps {info['duration']:.2f}s "
        f"({info['codec']}) -> {out_dir}"
    )
    return outs


def clear_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)
