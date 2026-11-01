from __future__ import annotations

import glob
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCALAPPDATA = Path(os.environ.get("LOCALAPPDATA", ""))
PROGRAMFILES = Path(os.environ.get("ProgramFiles", "C:/Program Files"))
TOOLS = Path(os.environ.get("USERPROFILE", "C:/Users/Konet")) / "Tools"

CANDIDATES: dict[str, list[str]] = {
    "python": [sys.executable, "python3", "python"],
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
    "dotnet": [
        str(PROGRAMFILES / "dotnet" / "dotnet.exe"),
        "dotnet",
        str(TOOLS / "**" / "dotnet.exe"),
    ],
    "love": [
        str(TOOLS / "**" / "love.exe"),
        "love",
        str(PROGRAMFILES / "LOVE" / "love.exe"),
        str(LOCALAPPDATA / "Programs" / "LOVE" / "love.exe"),
        str(LOCALAPPDATA / "Microsoft" / "WinGet" / "Packages" / "Love2d.Love2d*" / "**" / "love.exe"),
    ],
    "gdevelop": [
        str(TOOLS / "**" / "GDevelop.exe"),
        "gdevelop",
        str(LOCALAPPDATA / "Programs" / "GDevelop" / "GDevelop.exe"),
        str(LOCALAPPDATA / "Programs" / "GDevelop" / "**" / "GDevelop.exe"),
        str(PROGRAMFILES / "GDevelop" / "**" / "GDevelop.exe"),
        str(LOCALAPPDATA / "Microsoft" / "WinGet" / "Packages" / "GDevelop.GDevelop*" / "**" / "GDevelop.exe"),
    ],
    "unity_hub": [
        str(PROGRAMFILES / "Unity Hub" / "Unity Hub.exe"),
        str(LOCALAPPDATA / "Programs" / "Unity Hub" / "Unity Hub.exe"),
        str(TOOLS / "**" / "Unity Hub.exe"),
    ],
    "unity": [
        str(PROGRAMFILES / "Unity" / "Hub" / "Editor" / "*" / "Editor" / "Unity.exe"),
        str(TOOLS / "**" / "Unity.exe"),
    ],
    "unreal": [
        str(PROGRAMFILES / "Epic Games" / "UE_*" / "Engine" / "Binaries" / "Win64" / "UnrealEditor-Cmd.exe"),
        str(TOOLS / "**" / "UnrealEditor-Cmd.exe"),
    ],
}

VERSION_ARGS = {"ffmpeg": "-version", "unity": "-version", "unreal": "-version"}
# GUI-only tools either open a window or block when asked for a version.
NO_VERSION = {"gdevelop", "unity_hub"}


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


def gpu_name() -> str:
    exe = shutil.which("nvidia-smi")
    if not exe:
        return ""
    try:
        result = subprocess.run(
            [exe, "--query-gpu=name,memory.total", "--format=csv,noheader"],
            capture_output=True, text=True, timeout=20,
        )
    except Exception:
        return ""
    if result.returncode != 0:
        return ""
    lines = [line.strip() for line in (result.stdout or "").splitlines() if line.strip()]
    return lines[0] if lines else ""


def tool_version(name: str, exe: Path) -> str:
    if name in NO_VERSION:
        return ""
    flag = VERSION_ARGS.get(name, "--version")
    try:
        out = subprocess.run(
            [str(exe), flag], capture_output=True, text=True, timeout=45
        )
        lines = (out.stdout or out.stderr).strip().splitlines()
        return lines[0] if lines else ""
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
