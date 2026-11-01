from __future__ import annotations

import subprocess
from pathlib import Path

from . import media
from .config import find_tool


def contact_sheet(input_path: Path, output_path: Path, cols: int = 4, rows: int = 3) -> None:
    ffmpeg = find_tool("ffmpeg")
    if not ffmpeg:
        raise RuntimeError("ffmpeg not found; run studio doctor")
    output_path.parent.mkdir(parents=True, exist_ok=True)
    duration = media.probe(input_path)["duration"] or 1.0
    rate = max(cols * rows / duration, 0.25)
    vf = f"fps={rate:.4f},scale=480:-1,tile={cols}x{rows}"
    result = subprocess.run(
        [str(ffmpeg), "-y", "-i", str(input_path), "-vf", vf, "-frames:v", "1", str(output_path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip().splitlines()[-1])
