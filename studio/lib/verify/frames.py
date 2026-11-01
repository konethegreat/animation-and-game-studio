from __future__ import annotations

from pathlib import Path

from PIL import Image


def _stats(path: Path) -> tuple[float, bytes]:
    with Image.open(path) as image:
        small = image.convert("L").resize((64, 36))
        data = small.tobytes()
        mean = sum(data) / len(data)
    return mean, data


def scan(out: Path, shot) -> list[str]:
    problems: list[str] = []
    files = sorted(out.glob("frame_*.png"))
    if len(files) != shot.frames:
        problems.append(f"{shot.id}: {len(files)} frames, expected {shot.frames}")
        return problems
    empty = [path.name for path in files if path.stat().st_size == 0]
    if empty:
        problems.append(f"{shot.id}: empty frames {', '.join(empty[:4])}")
        return problems
    black = []
    signatures = []
    for path in files:
        try:
            mean, data = _stats(path)
        except Exception:
            problems.append(f"{shot.id}: unreadable frame {path.name}")
            return problems
        if mean < 2.0:
            black.append(path.name)
        signatures.append(data)
    if black:
        problems.append(f"{shot.id}: black frames {', '.join(black[:4])}")
    if not shot.still:
        run = 1
        longest = 1
        for index in range(1, len(signatures)):
            if signatures[index] == signatures[index - 1]:
                run += 1
                longest = max(longest, run)
            else:
                run = 1
        if longest > 12:
            problems.append(f"{shot.id}: frozen for {longest} frames")
    return problems
