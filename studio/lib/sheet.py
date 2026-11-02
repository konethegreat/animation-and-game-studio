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
    info = media.probe(input_path)
    duration = info["duration"] or 1.0
    fps = info["fps"] or 24.0
    total = max(1, int(round(duration * fps)))
    step = max(1, total // (cols * rows))
    # Select frames by index; fps resampling before tile can emit them out of order.
    vf = f"select='not(mod(n\\,{step}))',scale=480:-1,tile={cols}x{rows}"
    result = subprocess.run(
        [str(ffmpeg), "-y", "-i", str(input_path), "-vf", vf, "-frames:v", "1", str(output_path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip().splitlines()[-1])
