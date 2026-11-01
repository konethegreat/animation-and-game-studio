from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from . import config


def _run(cmd: list[str], label: str) -> None:
    print(f"[{label}] {' '.join(cmd[:5])} ...")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")


def export_web(project_root: Path, out: Path) -> None:
    godot = config.find_tool("godot")
    if not godot:
        raise RuntimeError("godot not found; run studio doctor")
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True, exist_ok=True)

    _run([str(godot), "--headless", "--path", str(project_root), "--import"], "godot import")
    _run(
        [
            str(godot), "--headless", "--path", str(project_root),
            "--export-release", "Web", str(out / "index.html"),
        ],
        "godot export",
    )

    required = [out / "index.html", out / "index.wasm", out / "index.pck"]
    missing = [p.name for p in required if not p.exists()]
    if missing:
        raise RuntimeError(f"godot export missing files: {', '.join(missing)}")
