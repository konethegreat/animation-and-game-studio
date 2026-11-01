from __future__ import annotations

import glob
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCALAPPDATA = Path(os.environ.get("LOCALAPPDATA", ""))
PROGRAMFILES = Path(os.environ.get("ProgramFiles", "C:/Program Files"))
TOOLS = Path(os.environ.get("USERPROFILE", "C:/Users/Konet")) / "Tools"

CANDIDATES: dict[str, list[str]] = {
    "blender": [
        str(TOOLS / "**" / "blender.exe"),
        "blender",
        str(PROGRAMFILES / "Blender Foundation" / "*" / "blender.exe"),
    ],
    "godot": [
        str(TOOLS / "**" / "Godot*.exe"),
        "godot",
        "godot4",
        str(LOCALAPPDATA / "Microsoft" / "WinGet" / "Packages" / "**" / "Godot*.exe"),
        str(PROGRAMFILES / "Godot" / "**" / "Godot*.exe"),
    ],
    "ffmpeg": [
        str(TOOLS / "**" / "ffmpeg.exe"),
        "ffmpeg",
        str(LOCALAPPDATA / "Microsoft" / "WinGet" / "Packages" / "**" / "ffmpeg.exe"),
        str(PROGRAMFILES / "ffmpeg" / "**" / "ffmpeg.exe"),
    ],
}


def find_tool(name: str) -> Path | None:
    for candidate in CANDIDATES[name]:
        if any(ch in candidate for ch in "*?[]"):
            matches = sorted(glob.glob(candidate, recursive=True))
            if matches:
                return Path(matches[-1])
        else:
            found = shutil.which(candidate)
            if found:
                return Path(found)
    return None


def find_ffprobe() -> Path | None:
    sibling = ROOT / ".venv" / "Scripts" / "ffprobe.exe"
    if sibling.exists():
        return sibling
    ffmpeg = find_tool("ffmpeg")
    if ffmpeg:
        probe = ffmpeg.with_name("ffprobe.exe")
        if probe.exists():
            return probe
    found = shutil.which("ffprobe")
    return Path(found) if found else None


def tool_version(name: str, exe: Path) -> str:
    flag = "-version" if name == "ffmpeg" else "--version"
    try:
        out = subprocess.run(
            [str(exe), flag], capture_output=True, text=True, timeout=45
        )
        return (out.stdout or out.stderr).strip().splitlines()[0]
    except Exception as exc:
        return f"error: {exc}"


def doctor() -> list[dict]:
    rows = []
    for name in CANDIDATES:
        exe = find_tool(name)
        ok = exe is not None
        if name == "ffmpeg" and ok:
            ok = find_ffprobe() is not None
        rows.append(
            {
                "name": name,
                "path": str(exe) if exe else "",
                "version": tool_version(name, exe) if exe else "",
                "ok": ok,
            }
        )
    return rows
