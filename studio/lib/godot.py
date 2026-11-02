from __future__ import annotations

import shutil
import subprocess
import zipfile
from pathlib import Path

from . import config


def _godot() -> str:
    godot = config.find_tool("godot")
    if not godot:
        raise RuntimeError("godot not found; run studio doctor")
    return str(godot)


def _run(cmd: list[str], label: str) -> None:
    print(f"[{label}] {' '.join(cmd[:5])} ...")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")


def _clean(out: Path) -> None:
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)


def export_web(project_root: Path, out: Path) -> None:
    godot = _godot()
    _clean(out)

    _run([godot, "--headless", "--path", str(project_root), "--import"], "godot import")
    _run(
        [
            godot, "--headless", "--path", str(project_root),
            "--export-release", "Web", str(out / "index.html"),
        ],
        "godot export",
    )

    required = [out / "index.html", out / "index.wasm", out / "index.pck"]
    missing = [p.name for p in required if not p.exists()]
    if missing:
        raise RuntimeError(f"godot export missing files: {', '.join(missing)}")


def zip_dir(source: Path, dest: Path) -> Path:
    if dest.exists():
        dest.unlink()
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(source))
    return dest


def export_windows(project_root: Path, out: Path, exe: str = "game.exe") -> Path:
    godot = _godot()
    _clean(out)

    _run([godot, "--headless", "--path", str(project_root), "--import"], "godot import")
    _run(
        [
            godot, "--headless", "--path", str(project_root),
            "--export-release", "Windows Desktop", str(out / exe),
        ],
        "godot export",
    )

    required = [out / exe, out / Path(exe).with_suffix(".pck")]
    missing = [p.name for p in required if not p.exists()]
    if missing:
        raise RuntimeError(f"godot export missing files: {', '.join(missing)}")

    return zip_dir(out, out.parent / f"{Path(exe).stem}-windows.zip")
