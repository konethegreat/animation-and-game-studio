# Studio OS Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed three engine pipeline with an engine registry, manifest v2, shot capable resumable rendering, verification, asset licensing and credit generation, and install plus probe the new engines.

**Architecture:** Adapters behind one contract, a manifest that describes films, games and engine artifacts, a resumable queue that writes frames per shot, a media layer that encodes declared outputs with audio, and a verification and asset gate that every project must pass.

**Tech Stack:** Python 3.15, PyYAML, Pillow, pytest, FFmpeg 9, Blender 4.5 LTS, Godot 4.7.2, plus .NET 10, LÖVE 11.5, GDevelop 5.6, Unity 6.3 LTS, Unreal 5.8 and MonoGame 3.8.

**Spec:** `docs/superpowers/specs/2026-11-01-studio-expansion-design.md`

## Global Constraints

- Zero spend. Free and local tools only, no cloud rendering and no paid APIs.
- Blender 4.5 LTS at `C:\Users\Konet\Tools\blender-4.5.10-windows-x64\blender.exe`.
- Godot 4.7.2 at `C:\Users\Konet\Tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`.
- FFmpeg 9.0.2 at `C:\Users\Konet\Tools\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe`.
- Windows 11, Git Bash, repo root `C:\Users\Konet\My animation and game studio`.
- Run Python as `./.venv/Scripts/python`.
- Tests run as `./.venv/Scripts/python -m pytest studio/tests -v`.
- Media budgets: GIF 8 MB, MP4 and WebM 20 MB, poster 500 KB, GLB 5 MB.
- No em dashes in any user facing copy.
- Never commit `.venv`, `node_modules`, raw frames, Godot `.godot/`, caches, voice references or speaker embeddings.
- Build output stays out of git, except the existing tracked `projects/003-micro-game/build/web/` and web builds that pass the 25 MB per build and 40 MB total exception.
- Manifests 001 to 004 must keep rendering with their current commands and outputs.
- The face rule applies to the film plan, not this one. Any face enhancement must be reviewed against the source portrait.

## Plan Split

This is Plan A of three. It produces a working Studio OS core and a measured capability matrix.

- Plan B: engine artifacts 005 to 009.
- Plan C: the cinematic stack and The Maker at Work.

Plan A does not create film assets or engine project artifacts.

## File Structure

```
studio/lib/engines/
  __init__.py        exports registry functions
  base.py            Probe, EngineAdapter, ProbeOnlyAdapter, run_engine, count_frames
  registry.py        adapter table, get, known, supports, probe_all
  pillow.py          Python + Pillow adapter
  blender.py         Blender adapter
  godot.py           Godot adapter
studio/lib/verify/
  __init__.py        run(project, stage) and Check
  frames.py          completeness, black frame, frozen run checks
  media.py           declared output, duration, budget checks
  audio.py           stream presence and loudness checks
  gltf.py            GLB header and JSON chunk inspection
  builds.py          build presence and web build size checks
studio/lib/queue.py  state.json, source hash, settings hash, resume
studio/lib/assets.py catalog, lanes, fetch, verify, credits
studio/tests/test_engines.py
studio/tests/test_manifest.py
studio/tests/test_queue.py
studio/tests/test_media.py
studio/tests/test_verify.py
studio/tests/test_assets.py
studio/tests/test_publish.py
assets/catalog.yaml
assets/README.md
docs/engines.md
```

Modified files:

```
studio/lib/config.py
studio/lib/manifest.py
studio/lib/media.py
studio/lib/render.py
studio/lib/publish.py
studio/studio.py
studio/tests/test_config.py
studio/tests/test_templates.py
.github/workflows/ci.yml
.gitignore
AGENTS.md
README.md
```

---

### Task 1: Tool candidates, probes and engine registry

**Files:**
- Create: `studio/lib/engines/__init__.py`
- Create: `studio/lib/engines/base.py`
- Create: `studio/lib/engines/registry.py`
- Modify: `studio/lib/config.py`
- Test: `studio/tests/test_config.py`
- Test: `studio/tests/test_engines.py`

**Interfaces:**
- Produces: `config.CANDIDATES: dict[str, list[str]]` with keys `python, blender, godot, ffmpeg, dotnet, love, gdevelop, unity_hub, unity, unreal`.
- Produces: `config.gpu_name() -> str`, `config.VERSION_ARGS: dict[str, str]`.
- Produces: `engines.Probe`, `engines.EngineAdapter`, `engines.ProbeOnlyAdapter`, `engines.get(name) -> EngineAdapter`, `engines.known(name) -> bool`, `engines.supports(name, kind) -> bool`, `engines.probe_all() -> list[Probe]`, `engines.names() -> list[str]`.
- Consumes: `config.find_tool`, `config.tool_version`.

- [ ] **Step 1: Write the failing tests**

Replace `studio/tests/test_config.py` with:

```python
from studio.lib import config


def test_root_points_at_repo():
    assert (config.ROOT / "studio").is_dir()


def test_doctor_reports_every_tool_candidate():
    rows = config.doctor()
    assert {r["name"] for r in rows} == set(config.CANDIDATES)
    assert all("ok" in r for r in rows)


def test_version_args_for_non_gnu_tools():
    assert config.VERSION_ARGS["ffmpeg"] == "-version"
    assert config.VERSION_ARGS["unity"] == "-version"
    assert config.VERSION_ARGS["unreal"] == "-version"
    assert config.VERSION_ARGS.get("blender", "--version") == "--version"


def test_gpu_name_returns_a_string(monkeypatch):
    monkeypatch.setattr(config.shutil, "which", lambda name: None)
    assert config.gpu_name() == ""
```

Create `studio/tests/test_engines.py`:

```python
from studio.lib import config, engines


def test_registry_knows_every_engine():
    assert set(engines.names()) == {
        "python", "blender", "godot", "unity",
        "unreal", "gdevelop", "love", "monogame",
    }


def test_registry_checks_supported_kinds():
    assert engines.supports("godot", "game")
    assert engines.supports("blender", "film")
    assert not engines.supports("love", "film")
    assert not engines.supports("monogame", "film")


def test_probe_reports_missing_tool(monkeypatch):
    monkeypatch.setattr(config, "find_tool", lambda name: None)
    probe = engines.get("unity").probe()
    assert probe.name == "unity"
    assert probe.ok is False
    assert probe.blockers == ("unity not found",)


def test_probe_reports_found_tool(monkeypatch, tmp_path):
    fake = tmp_path / "Unity.exe"
    fake.write_text("", encoding="utf-8")
    monkeypatch.setattr(config, "find_tool", lambda name: fake)
    monkeypatch.setattr(config, "tool_version", lambda name, exe: "6000.3.27f2")
    probe = engines.get("unity").probe()
    assert probe.ok is True
    assert probe.version == "6000.3.27f2"
    assert probe.path == str(fake)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_config.py studio/tests/test_engines.py -v`

Expected: `ModuleNotFoundError: No module named 'studio.lib.engines'` and `AttributeError` for `VERSION_ARGS`.

- [ ] **Step 3: Expand config**

Add `import sys` at the top of `studio/lib/config.py`, then replace `CANDIDATES` and `tool_version` with:

```python
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
    flag = VERSION_ARGS.get(name, "--version")
    try:
        out = subprocess.run(
            [str(exe), flag], capture_output=True, text=True, timeout=45
        )
        return (out.stdout or out.stderr).strip().splitlines()[0]
    except Exception as exc:
        return f"error: {exc}"
```

Keep `doctor()` unchanged. It now iterates every candidate.

- [ ] **Step 4: Create the engine package**

Create `studio/lib/engines/base.py`:

```python
from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path

from .. import config


@dataclass(frozen=True)
class Probe:
    name: str
    tool: str
    path: str
    version: str
    kinds: tuple[str, ...]
    ok: bool
    blockers: tuple[str, ...] = ()
    device: str = ""

    def as_dict(self) -> dict:
        return {
            "name": self.name,
            "tool": self.tool,
            "path": self.path,
            "version": self.version,
            "kinds": list(self.kinds),
            "ok": self.ok,
            "blockers": list(self.blockers),
            "device": self.device,
        }


def run_engine(cmd: list[str], label: str) -> None:
    print(f"[{label}] {' '.join(cmd[:5])} ...")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")


def count_frames(path: Path) -> int:
    return sum(1 for frame in path.glob("frame_*.png") if frame.stat().st_size > 0)


class EngineAdapter:
    name = ""
    tool = ""
    kinds: frozenset[str] = frozenset()

    def probe(self) -> Probe:
        exe = config.find_tool(self.tool)
        kinds = tuple(sorted(self.kinds))
        device = config.gpu_name()
        if not exe:
            return Probe(
                self.name, self.tool, "", "", kinds, False,
                (f"{self.name} not found",), device,
            )
        return Probe(
            self.name, self.tool, str(exe), config.tool_version(self.tool, exe),
            kinds, True, (), device,
        )

    def prepare(self, project) -> None:
        return None

    def render(self, project, shot, out: Path) -> int:
        raise NotImplementedError(f"{self.name} cannot render yet")

    def build(self, project, out: Path) -> Path | None:
        return None

    def export(self, project, target: Path) -> Path | None:
        return None

    def verify(self, project) -> list[str]:
        return []


class ProbeOnlyAdapter(EngineAdapter):
    def __init__(self, name: str, tool: str, kinds: set[str]) -> None:
        self.name = name
        self.tool = tool
        self.kinds = frozenset(kinds)
```

Create `studio/lib/engines/registry.py`:

```python
from __future__ import annotations

from .base import EngineAdapter, Probe, ProbeOnlyAdapter

SPECS: dict[str, tuple[str, set[str]]] = {
    "python": ("python", {"film"}),
    "blender": ("blender", {"film"}),
    "godot": ("godot", {"game"}),
    "unity": ("unity", {"film", "game"}),
    "unreal": ("unreal", {"film"}),
    "gdevelop": ("gdevelop", {"game"}),
    "love": ("love", {"game"}),
    "monogame": ("dotnet", {"game"}),
}

ADAPTERS: dict[str, EngineAdapter] = {
    name: ProbeOnlyAdapter(name, tool, kinds)
    for name, (tool, kinds) in SPECS.items()
}


def get(name: str) -> EngineAdapter:
    try:
        return ADAPTERS[name]
    except KeyError:
        raise ValueError(f"unknown engine '{name}'") from None


def known(name: str) -> bool:
    return name in ADAPTERS


def supports(name: str, kind: str) -> bool:
    adapter = ADAPTERS.get(name)
    return bool(adapter and kind in adapter.kinds)


def names() -> list[str]:
    return sorted(ADAPTERS)


def probe_all() -> list[Probe]:
    return [ADAPTERS[name].probe() for name in names()]
```

Create `studio/lib/engines/__init__.py`:

```python
from .base import EngineAdapter, Probe, ProbeOnlyAdapter
from .registry import get, known, names, probe_all, supports

__all__ = [
    "EngineAdapter", "Probe", "ProbeOnlyAdapter",
    "get", "known", "names", "probe_all", "supports",
]
```

- [ ] **Step 5: Run the tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_config.py studio/tests/test_engines.py -v`

Expected: PASS. `doctor` now includes ten rows, and missing tools are reported, not raised.

- [ ] **Step 6: Commit**

```bash
git add studio/lib/config.py studio/lib/engines studio/tests/test_config.py studio/tests/test_engines.py
git commit -m "feat: add the engine registry and tool probes"
```

---

### Task 2: Wrap Python, Blender and Godot adapters

**Files:**
- Create: `studio/lib/engines/pillow.py`
- Create: `studio/lib/engines/blender.py`
- Create: `studio/lib/engines/godot.py`
- Modify: `studio/lib/engines/registry.py`
- Test: `studio/tests/test_engines.py`

**Interfaces:**
- Produces: `PythonAdapter`, `BlenderAdapter`, `GodotAdapter`, all subclasses of `EngineAdapter`.
- Consumes: `Project` fields `root, entry, engine_args, resolution`, `Shot` fields `entry, frames`.
- Produces: `BlenderAdapter.command(project, shot, out) -> list[str]`, `PythonAdapter.command(project, shot, out) -> list[str]`.
- Produces: `GodotAdapter.build(project, out) -> Path`.

- [ ] **Step 1: Write the failing adapter tests**

Append to `studio/tests/test_engines.py`:

```python
import sys
from pathlib import Path

from studio.lib.manifest import Project, Shot


def make_project(tmp_path: Path) -> Project:
    (tmp_path / "scene.py").write_text("", encoding="utf-8")
    return Project(
        id="099-adapter-test",
        type="3d",
        title="Adapter",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(320, 180),
        fps=24,
        frames=2,
        poster_time=1.0,
        outputs=["media/099-adapter-test/reel.mp4"],
        root=tmp_path,
        kind="film",
        shots=[Shot("main", "scene.py", 2)],
    )


def test_python_command_uses_shot_frames(tmp_path):
    from studio.lib.engines.pillow import PythonAdapter

    project = make_project(tmp_path)
    project.engine = "python"
    shot = Shot("main", "scene.py", 2)
    cmd = PythonAdapter().command(project, shot, tmp_path / "frames")
    assert cmd[0] == sys.executable
    assert "--frames" in cmd
    assert cmd[cmd.index("--frames") + 1] == "2"


def test_blender_command_includes_engine_args(tmp_path, monkeypatch):
    from studio.lib.engines.blender import BlenderAdapter

    project = make_project(tmp_path)
    project.engine_args = ["--engine", "CYCLES"]
    monkeypatch.setattr("studio.lib.engines.blender.config.find_tool", lambda name: Path("C:/blender.exe"))
    cmd = BlenderAdapter().command(project, project.shots[0], tmp_path / "frames")
    assert cmd[:3] == ["C:\\blender.exe", "-b", "--python"]
    assert cmd[-2:] == ["--engine", "CYCLES"]
    assert cmd[cmd.index("--frames-end") + 1] == "2"


def test_blender_export_command_targets_glb(tmp_path, monkeypatch):
    from studio.lib.engines.blender import BlenderAdapter

    project = make_project(tmp_path)
    monkeypatch.setattr("studio.lib.engines.blender.config.find_tool", lambda name: Path("C:/blender.exe"))
    cmd = BlenderAdapter().command_export(project, tmp_path / "out.glb")
    assert cmd[cmd.index("--export-glb") + 1] == str(tmp_path / "out.glb")


def test_godot_build_delegates_to_export_web(tmp_path, monkeypatch):
    from studio.lib.engines.godot import GodotAdapter

    project = make_project(tmp_path)
    project.engine = "godot"
    project.kind = "game"
    calls = []
    monkeypatch.setattr(
        "studio.lib.engines.godot.godot_tool.export_web",
        lambda root, out: calls.append((root, out)),
    )
    target = GodotAdapter().build(project, tmp_path / "build" / "web")
    assert calls == [(tmp_path, tmp_path / "build" / "web")]
    assert target == tmp_path / "build" / "web"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_engines.py -v`

Expected: `ModuleNotFoundError` for `studio.lib.engines.pillow`, `blender` and `godot`.

- [ ] **Step 3: Implement the adapters**

Create `studio/lib/engines/pillow.py`:

```python
from __future__ import annotations

import sys
from pathlib import Path

from .base import EngineAdapter, count_frames, run_engine


class PythonAdapter(EngineAdapter):
    name = "python"
    tool = "python"
    kinds = frozenset({"film"})

    def command(self, project, shot, out: Path) -> list[str]:
        width, height = project.resolution
        return [
            sys.executable, str(project.root / shot.entry),
            "--out", str(out), "--frames", str(shot.frames),
            "--width", str(width), "--height", str(height),
        ]

    def render(self, project, shot, out: Path) -> int:
        out.mkdir(parents=True, exist_ok=True)
        run_engine(self.command(project, shot, out), project.id)
        return count_frames(out)
```

Create `studio/lib/engines/blender.py`:

```python
from __future__ import annotations

from pathlib import Path

from .. import config
from .base import EngineAdapter, count_frames, run_engine


class BlenderAdapter(EngineAdapter):
    name = "blender"
    tool = "blender"
    kinds = frozenset({"film"})

    def _exe(self) -> str:
        exe = config.find_tool("blender")
        if not exe:
            raise RuntimeError("blender not found; run studio doctor")
        return str(exe)

    def command(self, project, shot, out: Path) -> list[str]:
        width, height = project.resolution
        return [
            self._exe(), "-b", "--python", str(project.root / shot.entry), "--",
            "--out", str(out), "--frames-start", "1", "--frames-end", str(shot.frames),
            "--width", str(width), "--height", str(height),
            *project.engine_args,
        ]

    def command_export(self, project, target: Path) -> list[str]:
        return [
            self._exe(), "-b", "--python", str(project.root / project.entry), "--",
            "--export-glb", str(target),
        ]

    def render(self, project, shot, out: Path) -> int:
        out.mkdir(parents=True, exist_ok=True)
        run_engine(self.command(project, shot, out), project.id)
        return count_frames(out)

    def export(self, project, target: Path) -> Path:
        target.parent.mkdir(parents=True, exist_ok=True)
        run_engine(self.command_export(project, target), project.id)
        return target
```

Create `studio/lib/engines/godot.py`:

```python
from __future__ import annotations

from pathlib import Path

from .. import godot as godot_tool
from .base import EngineAdapter


class GodotAdapter(EngineAdapter):
    name = "godot"
    tool = "godot"
    kinds = frozenset({"game"})

    def build(self, project, out: Path) -> Path:
        godot_tool.export_web(project.root, out)
        return out
```

Replace the `ADAPTERS` construction in `studio/lib/engines/registry.py` with explicit instances:

```python
from .blender import BlenderAdapter
from .godot import GodotAdapter
from .pillow import PythonAdapter

SPECS: dict[str, tuple[str, set[str]]] = {
    "unity": ("unity", {"film", "game"}),
    "unreal": ("unreal", {"film"}),
    "gdevelop": ("gdevelop", {"game"}),
    "love": ("love", {"game"}),
    "monogame": ("dotnet", {"game"}),
}

ADAPTERS: dict[str, EngineAdapter] = {
    adapter.name: adapter
    for adapter in (PythonAdapter(), BlenderAdapter(), GodotAdapter())
}
ADAPTERS.update({
    name: ProbeOnlyAdapter(name, tool, kinds)
    for name, (tool, kinds) in SPECS.items()
})
```

- [ ] **Step 4: Run the tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_engines.py -v`

Expected: PASS, including the five earlier registry tests.

- [ ] **Step 5: Commit**

```bash
git add studio/lib/engines studio/tests/test_engines.py
git commit -m "feat: wrap python, blender and godot in engine adapters"
```

---

### Task 3: Manifest v2

**Files:**
- Modify: `studio/lib/manifest.py`
- Modify: `studio/lib/render.py` (only enough to keep importing)
- Test: `studio/tests/test_manifest.py`

**Interfaces:**
- Produces: `manifest.Shot(id: str, entry: str, frames: int, still: bool = False)`.
- Produces: `Project.kind: str`, `Project.shots: list[Shot]`, `Project.audio: dict[str, str]`, `Project.samples: int`, `Project.device: str`, `Project.engine_args: list[str]`, `Project.assets: list[str]`.
- Produces: `Project.output_path(suffix: str) -> Path | None` and `Project.audio_paths() -> dict[str, Path]`.
- Consumes: `engines.known`, `engines.supports`.

- [ ] **Step 1: Write the failing tests**

Replace `studio/tests/test_manifest.py` with:

```python
from pathlib import Path

from studio.lib import manifest

GOOD = """
id: 009-demo
type: 2d
title: Demo
summary: A demo.
tags: [2d]
engine: python
entry: render.py
render: {resolution: [1280, 720], fps: 24, frames: 48}
outputs: [media/009-demo/demo.mp4]
"""

V2 = """
id: 010-demo
kind: film
type: 3d
title: Demo film
summary: A demo film.
tags: [film]
engine: blender
entry: film.py
render:
  resolution: [1920, 800]
  fps: 24
  frames: 24
  samples: 128
  device: optix
  engine_args: ["--engine", "CYCLES"]
shots:
  - {id: a, entry: a.py, frames: 12}
  - {id: b, entry: b.py, frames: 12}
audio:
  score: audio/score.wav
assets: [polyhaven-studio-hdri]
outputs:
  - media/010-demo/film.mp4
  - media/010-demo/poster.jpg
"""


def write(tmp_path: Path, body: str, extra: tuple[str, ...] = ()) -> Path:
    project = tmp_path / "p"
    project.mkdir(exist_ok=True)
    (project / "project.yaml").write_text(body, encoding="utf-8")
    (project / "render.py").write_text("", encoding="utf-8")
    for name in extra:
        (project / name).write_text("", encoding="utf-8")
    return project


def test_loads_valid_manifest(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.id == "009-demo"
    assert project.fps == 24
    assert project.resolution == (1280, 720)
    assert project.kind == "film"
    assert project.shots[0].id == "main"
    assert project.shots[0].frames == 48
    assert manifest.validate(project) == []


def test_poster_time_defaults_and_parses(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.poster_time == 1.0
    tuned = GOOD.replace("frames: 48", "frames: 48, poster_time: 4.4")
    project = manifest.load(write(tmp_path, tuned))
    assert project.poster_time == 4.4


def test_v2_loads_shots_audio_and_engine_args(tmp_path):
    project = manifest.load(write(tmp_path, V2, ("film.py", "a.py", "b.py")))
    assert project.kind == "film"
    assert [s.id for s in project.shots] == ["a", "b"]
    assert project.audio == {"score": "audio/score.wav"}
    assert project.assets == ["polyhaven-studio-hdri"]
    assert project.samples == 128
    assert project.device == "optix"
    assert project.engine_args == ["--engine", "CYCLES"]


def test_game_type_defaults_to_game_kind(tmp_path):
    game = GOOD.replace("type: 2d", "type: game").replace("engine: python", "engine: godot")
    project = manifest.load(write(tmp_path, game))
    assert project.kind == "game"
    assert manifest.validate(project) == []


def test_rejects_unknown_engine(tmp_path):
    bad = GOOD.replace("engine: python", "engine: quartz")
    project = manifest.load(write(tmp_path, bad))
    assert any("unknown engine" in error for error in manifest.validate(project))


def test_rejects_kind_the_engine_cannot_run(tmp_path):
    bad = GOOD.replace("engine: python", "engine: love")
    project = manifest.load(write(tmp_path, bad))
    assert any("cannot run" in error for error in manifest.validate(project))


def test_engine_is_no_longer_tied_to_type(tmp_path):
    project = manifest.load(write(tmp_path, GOOD.replace("engine: python", "engine: blender")))
    assert manifest.validate(project) == []


def test_rejects_shot_frame_sum_mismatch(tmp_path):
    bad = V2.replace("frames: 24\n  samples", "frames: 30\n  samples")
    project = manifest.load(write(tmp_path, bad, ("film.py", "a.py", "b.py")))
    assert any("shots total" in error for error in manifest.validate(project))


def test_rejects_missing_shot_entry(tmp_path):
    bad = V2.replace("entry: a.py", "entry: missing.py")
    project = manifest.load(write(tmp_path, bad, ("film.py", "b.py")))
    assert any("missing.py" in error for error in manifest.validate(project))


def test_rejects_audio_outside_project(tmp_path):
    bad = V2.replace("audio/score.wav", "../../escape.wav")
    project = manifest.load(write(tmp_path, bad, ("film.py", "a.py", "b.py")))
    assert any("audio" in error and "escapes" in error for error in manifest.validate(project))


def test_rejects_missing_entry(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    project.entry = "missing.py"
    assert any("entry" in error for error in manifest.validate(project))


def test_rejects_bad_id(tmp_path):
    bad = GOOD.replace("009-demo", "demo")
    project = manifest.load(write(tmp_path, bad))
    assert any("id" in error for error in manifest.validate(project))


def test_rejects_output_outside_repo(tmp_path):
    bad = GOOD.replace("media/009-demo/demo.mp4", "../../escape.mp4")
    project = manifest.load(write(tmp_path, bad))
    assert any("escapes" in error for error in manifest.validate(project))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_manifest.py -v`

Expected: failures for missing `kind`, `shots`, `audio`, `samples`, `device`, `engine_args`, `assets`.

- [ ] **Step 3: Implement manifest v2**

Replace `studio/lib/manifest.py` with:

```python
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import engines
from .config import ROOT

ID_RE = re.compile(r"^\d{3}-[a-z0-9-]+$")
KINDS = {"film", "game"}


@dataclass(frozen=True)
class Shot:
    id: str
    entry: str
    frames: int
    still: bool = False


@dataclass
class Project:
    id: str
    type: str
    title: str
    summary: str
    tags: list[str]
    engine: str
    entry: str
    resolution: tuple[int, int]
    fps: int
    frames: int
    poster_time: float
    outputs: list[str]
    kind: str = "film"
    shots: list[Shot] = field(default_factory=list)
    audio: dict[str, str] = field(default_factory=dict)
    samples: int = 0
    device: str = ""
    engine_args: list[str] = field(default_factory=list)
    assets: list[str] = field(default_factory=list)
    root: Path = field(default=ROOT)

    @property
    def media_dir(self) -> Path:
        return ROOT / "media" / self.id

    def output_path(self, suffix: str) -> Path | None:
        for output in self.outputs:
            if Path(output).suffix.lower() == suffix.lower():
                return ROOT / output
        return None

    def audio_paths(self) -> dict[str, Path]:
        return {key: self.root / value for key, value in self.audio.items()}


def load(project_dir: Path) -> Project:
    data = yaml.safe_load((project_dir / "project.yaml").read_text(encoding="utf-8"))
    render = data.get("render") or {}
    resolution = tuple(render.get("resolution") or (1920, 1080))
    entry = str(data["entry"])
    raw_shots = data.get("shots") or []
    shots = [
        Shot(
            id=str(item["id"]),
            entry=str(item.get("entry", entry)),
            frames=int(item["frames"]),
            still=bool(item.get("still", False)),
        )
        for item in raw_shots
    ]
    if not shots:
        total = int(render.get("frames", 1))
        shots = [Shot(id="main", entry=entry, frames=total)]
    frame_total = int(render.get("frames", sum(shot.frames for shot in shots)))
    return Project(
        id=str(data["id"]),
        type=str(data["type"]),
        title=str(data["title"]),
        summary=str(data.get("summary", "")),
        tags=[str(t) for t in data.get("tags") or []],
        engine=str(data["engine"]),
        entry=entry,
        resolution=(int(resolution[0]), int(resolution[1])),
        fps=int(render.get("fps", 24)),
        frames=frame_total,
        poster_time=float(render.get("poster_time", 1.0)),
        outputs=[str(o) for o in data.get("outputs") or []],
        kind=str(data.get("kind") or ("game" if data["type"] == "game" else "film")),
        shots=shots,
        audio={str(k): str(v) for k, v in (data.get("audio") or {}).items()},
        samples=int(render.get("samples", 0)),
        device=str(render.get("device", "")),
        engine_args=[str(a) for a in render.get("engine_args") or []],
        assets=[str(a) for a in data.get("assets") or []],
        root=project_dir,
    )


def load_all(projects_root: Path | None = None) -> list[Project]:
    projects_root = projects_root or (ROOT / "projects")
    found = []
    for manifest_path in sorted(projects_root.glob("*/project.yaml")):
        if manifest_path.parent.name.startswith("_"):
            continue
        found.append(load(manifest_path.parent))
    return found


def validate(project: Project) -> list[str]:
    errors: list[str] = []
    if not ID_RE.match(project.id):
        errors.append(f"id '{project.id}' must look like 001-name")
    if project.type not in {"2d", "3d", "game"}:
        errors.append("type must be one of 2d, 3d, game")
    if project.kind not in KINDS:
        errors.append("kind must be film or game")
    if not engines.known(project.engine):
        errors.append(f"unknown engine '{project.engine}'")
    elif project.kind in KINDS and not engines.supports(project.engine, project.kind):
        errors.append(
            f"engine '{project.engine}' cannot run kind '{project.kind}'"
        )
    if not (project.root / project.entry).exists():
        errors.append(f"entry '{project.entry}' does not exist in {project.root}")
    width, height = project.resolution
    if width <= 0 or height <= 0:
        errors.append("resolution must be positive")
    if width > 1920 or height > 1080:
        errors.append("resolution must not exceed 1080p on this machine")
    if project.fps <= 0:
        errors.append("fps must be positive")
    if project.frames <= 0:
        errors.append("frames must be positive")
    if not project.outputs:
        errors.append("at least one output is required")
    for output in project.outputs:
        target = (ROOT / output).resolve()
        if not str(target).startswith(str(ROOT.resolve())):
            errors.append(f"output '{output}' escapes the repo root")
    if not project.shots:
        errors.append("at least one shot is required")
    seen: set[str] = set()
    for shot in project.shots:
        if shot.id in seen:
            errors.append(f"shot id '{shot.id}' is duplicated")
        seen.add(shot.id)
        if shot.frames <= 0:
            errors.append(f"shot '{shot.id}' needs a positive frame count")
        if not (project.root / shot.entry).exists():
            errors.append(f"shot '{shot.id}' entry '{shot.entry}' does not exist")
    total = sum(shot.frames for shot in project.shots)
    if total != project.frames:
        errors.append(
            f"shots total {total} frames but render.frames says {project.frames}"
        )
    for key, value in project.audio.items():
        target = (project.root / value).resolve()
        if not str(target).startswith(str(project.root.resolve())):
            errors.append(f"audio '{key}' escapes the project root")
    return errors


def find(project_id: str) -> Project:
    for project in load_all():
        if project.id == project_id:
            return project
    raise SystemExit(f"unknown project '{project_id}'")
```

- [ ] **Step 4: Keep the old render import alive**

The existing `render.py` still reads `project.entry` and works with the implicit shot. Do not change it in this task. Run the full suite to confirm nothing else breaks:

Run: `./.venv/Scripts/python -m pytest studio/tests -v`

Expected: PASS. `test_templates` still passes because templates stay v1 and gain `kind` and an implicit shot.

- [ ] **Step 5: Commit**

```bash
git add studio/lib/manifest.py studio/tests/test_manifest.py
git commit -m "feat: support film manifests with shots and audio"
```

---

### Task 4: Doctor deep and CLI wiring

**Files:**
- Modify: `studio/studio.py`
- Test: `studio/tests/test_engines.py`

**Interfaces:**
- Produces: `studio doctor --deep` prints tool rows and adapter rows.
- Produces: `cmd_doctor(args)` returns 0 when all tools are ok, or when `--soft`.
- Consumes: `engines.probe_all`, `config.gpu_name`.

- [ ] **Step 1: Write the failing test**

Append to `studio/tests/test_engines.py`:

```python
from studio import studio as cli


def test_doctor_deep_prints_adapters(monkeypatch, capsys):
    from studio.lib.engines.base import Probe

    monkeypatch.setattr(cli.config, "doctor", lambda: [
        {"name": "blender", "path": "C:/blender.exe", "version": "4.5.10", "ok": True},
    ])
    monkeypatch.setattr(cli.engines, "probe_all", lambda: [
        Probe("blender", "blender", "C:/blender.exe", "4.5.10", ("film",), True),
        Probe("unity", "unity", "", "", ("film", "game"), False, ("unity not found",)),
    ])
    code = cli.main(["doctor", "--deep"])
    out = capsys.readouterr().out
    assert code == 0
    assert "adapters" in out
    assert "unity" in out
    assert "unity not found" in out
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_engines.py::test_doctor_deep_prints_adapters -v`

Expected: `SystemExit` for unrecognized argument `--deep`.

- [ ] **Step 3: Implement doctor deep**

In `studio/studio.py`, add `engines` to the import line:

```python
from studio.lib import config, engines, godot, manifest, publish, render, sheet  # noqa: E402
```

Replace `cmd_doctor` with:

```python
def cmd_doctor(args: argparse.Namespace) -> int:
    rows = config.doctor()
    for row in rows:
        mark = "ok" if row["ok"] else "missing"
        print(f"{row['name']:10} {mark:8} {row['path']}")
        if row["version"]:
            print(f"           {row['version']}")
    if args.deep:
        print("\nadapters")
        for probe in engines.probe_all():
            mark = "ok" if probe.ok else "blocked"
            kinds = ",".join(probe.kinds)
            print(f"{probe.name:10} {mark:8} {kinds:10} {probe.path}")
            if probe.version:
                print(f"           {probe.version}")
            for blocker in probe.blockers:
                print(f"           {blocker}")
        gpu = config.gpu_name()
        if gpu:
            print(f"\ngpu        {gpu}")
    ok = all(row["ok"] for row in rows)
    return 0 if ok or args.soft else 1
```

Add the flag in `build_parser`:

```python
doctor.add_argument("--deep", action="store_true", help="also probe engine adapters")
```

- [ ] **Step 4: Run the tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_engines.py -v`

Expected: PASS.

Then run the real command and inspect the matrix:

Run: `./.venv/Scripts/python studio/studio.py doctor --deep --soft`

Expected: blender, godot and ffmpeg are ok. Unity, Unreal, GDevelop, LÖVE, .NET and Unity Hub are missing until Task 5.

- [ ] **Step 5: Commit**

```bash
git add studio/studio.py studio/tests/test_engines.py
git commit -m "feat: probe every engine from studio doctor"
```

---

### Task 5: Install the missing engines and record the capability matrix

**Files:**
- Create: `docs/engines.md`
- Modify: `studio/lib/config.py` only if a new install location is discovered.

**Interfaces:**
- Produces: measured versions and paths for .NET 10, MonoGame, LÖVE 11.5, GDevelop 5.6, Unity 6.3 LTS and Unreal 5.8.
- Produces: `docs/engines.md` with the matrix and per engine recipes.

This task is environment work. Its test is `studio doctor --deep`.

- [ ] **Step 1: Install the small tools**

Run these one at a time. Accept the source and package agreements. UAC prompts may appear.

```bash
winget install --id Microsoft.DotNet.SDK.10 --exact --silent --accept-package-agreements --accept-source-agreements
winget install --id Love2d.Love2d --exact --silent --accept-package-agreements --accept-source-agreements
winget install --id GDevelop.GDevelop --exact --silent --accept-package-agreements --accept-source-agreements
```

Install the MonoGame templates:

```bash
dotnet new install MonoGame.Templates.CSharp
```

Verify:

```bash
dotnet --version
dotnet new mgdesktopgl -o "$TEMP/mg-probe" --force
dotnet build "$TEMP/mg-probe"
./.venv/Scripts/python studio/studio.py doctor --deep --soft
```

Expected: .NET reports 10.0.x, the MonoGame probe builds, LÖVE reports 11.5, GDevelop is found.

If `dotnet` is not on PATH in Git Bash, open a new shell or use `C:/Program Files/dotnet/dotnet.exe`.

- [ ] **Step 2: Install Unity Hub and Unity 6.3 LTS**

```bash
winget install --id Unity.UnityHub --exact --silent --accept-package-agreements --accept-source-agreements
```

The current LTS version on 2026-11-01 is `6000.3.27f2` with changeset `22188f149405`. Install the editor with Windows and WebGL modules:

```bash
"/c/Program Files/Unity Hub/Unity Hub.exe" -- --headless install --version 6000.3.27f2 --changeset 22188f149405 --module windows-il2cpp --module webgl
```

If the Hub ignores the module flags, install `windows-il2cpp` and `webgl` from the Hub GUI. Sign in once in the Hub, then verify headless launch:

```bash
"/c/Program Files/Unity/Hub/Editor/6000.3.27f2/Editor/Unity.exe" -batchmode -quit -logFile - -projectPath "$TEMP/unity-probe"
```

If the licence is not activated, sign in through the Hub and repeat. Record the blocker if activation cannot be completed.

- [ ] **Step 3: Install the Epic Games Launcher and stage Unreal**

```bash
winget install --id EpicGames.EpicGamesLauncher --exact --silent --accept-package-agreements --accept-source-agreements
```

Unreal 5.8 needs an Epic sign-in and a roughly 100 GB install through the launcher. Do not start the download silently. Record the launcher path and mark Unreal as blocked until the owner signs in and starts the install. The adapter and probe stay registered.

- [ ] **Step 4: Probe and record**

Run:

```bash
./.venv/Scripts/python studio/studio.py doctor --deep --soft
```

Create `docs/engines.md` with the measured results:

```markdown
# Engine capability matrix

Measured on 2026-11-01 on Windows 11, 12 logical cores, 11.4 GB RAM, RTX 3050 Laptop 4 GB, 265 GB free.

| Engine | Version | Path | Render | Build | Status |
| --- | --- | --- | --- | --- | --- |
```

Add one row per engine with the exact path and version from the probe. Add a short section per engine recording:

- the install command,
- the probe command,
- whether headless mode works,
- the known blockers,
- the adapter status (`wrapped` or `probe only`).

- [ ] **Step 5: Commit**

```bash
git add docs/engines.md studio/lib/config.py
git commit -m "chore: install and probe the expanded engine set"
```

---

### Task 6: Shot queue and resumable render

**Files:**
- Create: `studio/lib/queue.py`
- Modify: `studio/lib/render.py`
- Modify: `studio/studio.py`
- Test: `studio/tests/test_queue.py`

**Interfaces:**
- Produces: `queue.source_hash(project, shot) -> str`, `queue.settings_hash(project, shot, width, height, preview) -> str`.
- Produces: `queue.load_state(path) -> dict`, `queue.save_state(path, state) -> None`, `queue.shot_complete(out, shot, state, source, settings) -> bool`.
- Produces: `render.run(project, shot_ids=None, preview=False, resume=True) -> Path`.
- Consumes: `engines.get`, `media.clear_dir`, `media.encode_project`, `media.encode_preview`.

- [ ] **Step 1: Write the failing queue tests**

Create `studio/tests/test_queue.py`:

```python
from pathlib import Path

from studio.lib import manifest, queue
from studio.lib.manifest import Project, Shot


def make_project(tmp_path: Path) -> Project:
    (tmp_path / "scene.py").write_text("print('a')", encoding="utf-8")
    return Project(
        id="099-queue-test",
        type="3d",
        title="Queue",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(320, 180),
        fps=24,
        frames=2,
        poster_time=1.0,
        outputs=["media/099-queue-test/reel.mp4"],
        kind="film",
        shots=[Shot("main", "scene.py", 2)],
        root=tmp_path,
    )


def test_state_roundtrip(tmp_path):
    path = tmp_path / "state.json"
    state = {"shots": {"main": {"frames": 2}}}
    queue.save_state(path, state)
    assert queue.load_state(path) == state


def test_source_hash_changes_with_file(tmp_path):
    project = make_project(tmp_path)
    shot = project.shots[0]
    first = queue.source_hash(project, shot)
    (tmp_path / "scene.py").write_text("print('b')", encoding="utf-8")
    assert queue.source_hash(project, shot) != first


def test_settings_hash_changes_with_resolution(tmp_path):
    project = make_project(tmp_path)
    shot = project.shots[0]
    assert queue.settings_hash(project, shot, 320, 180, False) != queue.settings_hash(
        project, shot, 160, 90, False
    )


def test_complete_requires_state_and_frames(tmp_path):
    project = make_project(tmp_path)
    shot = project.shots[0]
    out = tmp_path / "frames"
    out.mkdir()
    source = queue.source_hash(project, shot)
    settings = queue.settings_hash(project, shot, 320, 180, False)
    state = {"shots": {"main": {"frames": 2, "source": source, "settings": settings}}}
    assert queue.shot_complete(out, shot, state, source, settings) is False
    (out / "frame_0001.png").write_bytes(b"x")
    (out / "frame_0002.png").write_bytes(b"x")
    assert queue.shot_complete(out, shot, state, source, settings) is True
    assert queue.shot_complete(out, shot, state, source + "x", settings) is False
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_queue.py -v`

Expected: `ModuleNotFoundError` for `studio.lib.queue`.

- [ ] **Step 3: Implement the queue**

Create `studio/lib/queue.py`:

```python
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from . import media


def source_hash(project, shot) -> str:
    digest = hashlib.sha256()
    digest.update((project.root / shot.entry).read_bytes())
    digest.update(project.engine.encode("utf-8"))
    digest.update("|".join(project.engine_args).encode("utf-8"))
    return digest.hexdigest()


def settings_hash(project, shot, width: int, height: int, preview: bool) -> str:
    payload = {
        "frames": shot.frames,
        "width": width,
        "height": height,
        "fps": project.fps,
        "preview": preview,
        "device": project.device,
        "samples": project.samples,
    }
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True).encode("utf-8")
    ).hexdigest()


def load_state(path: Path) -> dict:
    if not path.exists():
        return {"shots": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"shots": {}}
    if not isinstance(data, dict) or not isinstance(data.get("shots"), dict):
        return {"shots": {}}
    return data


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2), encoding="utf-8")


def mark_complete(state: dict, shot, source: str, settings: str) -> None:
    state.setdefault("shots", {})[shot.id] = {
        "frames": shot.frames,
        "source": source,
        "settings": settings,
        "updated": datetime.now(timezone.utc).isoformat(),
    }


def shot_complete(out: Path, shot, state: dict, source: str, settings: str) -> bool:
    entry = (state.get("shots") or {}).get(shot.id)
    if not isinstance(entry, dict):
        return False
    if entry.get("frames") != shot.frames:
        return False
    if entry.get("source") != source or entry.get("settings") != settings:
        return False
    files = sorted(out.glob("frame_*.png"))
    return len(files) == shot.frames and all(path.stat().st_size > 0 for path in files)
```

- [ ] **Step 4: Write the failing render pipeline test**

Append to `studio/tests/test_queue.py`:

```python
from dataclasses import replace

from PIL import Image

from studio.lib import render


class FakeAdapter:
    name = "blender"

    def __init__(self):
        self.calls = 0

    def prepare(self, project):
        return None

    def render(self, project, shot, out):
        self.calls += 1
        out.mkdir(parents=True, exist_ok=True)
        for index in range(1, shot.frames + 1):
            Image.new("RGB", (2, 2), (index * 20, 40, 80)).save(out / f"frame_{index:04d}.png")
        return shot.frames


def test_render_resumes_and_skips_complete_shots(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    media_dir = tmp_path / "media"
    monkeypatch.setattr(Project, "media_dir", property(lambda self: media_dir))
    fake = FakeAdapter()
    monkeypatch.setattr(render.engines, "get", lambda name: fake)
    monkeypatch.setattr(render.media, "encode_project", lambda *args, **kwargs: {"mp4": tmp_path / "out.mp4"})

    frames = render.run(project)

    assert fake.calls == 1
    assert (frames / "frame_0001.png").exists()
    assert (frames / "frame_0002.png").exists()

    render.run(project)

    assert fake.calls == 1


def test_render_single_shot_invalidates_when_source_changes(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    media_dir = tmp_path / "media"
    monkeypatch.setattr(Project, "media_dir", property(lambda self: media_dir))
    fake = FakeAdapter()
    monkeypatch.setattr(render.engines, "get", lambda name: fake)
    encoded = []
    monkeypatch.setattr(render.media, "encode_project", lambda *args, **kwargs: encoded.append(1))

    render.run(project)
    (tmp_path / "scene.py").write_text("print('changed')", encoding="utf-8")
    render.run(project)

    assert fake.calls == 2


def test_render_partial_shot_does_not_encode(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    project.shots = [Shot("a", "scene.py", 1), Shot("b", "scene.py", 1)]
    project.frames = 2
    media_dir = tmp_path / "media"
    monkeypatch.setattr(Project, "media_dir", property(lambda self: media_dir))
    fake = FakeAdapter()
    monkeypatch.setattr(render.engines, "get", lambda name: fake)
    encoded = []
    monkeypatch.setattr(render.media, "encode_project", lambda *args, **kwargs: encoded.append(1))

    render.run(project, shot_ids=["a"])

    assert fake.calls == 1
    assert encoded == []
```

- [ ] **Step 5: Run the render tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_queue.py -v`

Expected: failures because `render.run` takes no `shot_ids` and does not resume.

- [ ] **Step 6: Implement shot rendering**

Replace `studio/lib/render.py` with:

```python
from __future__ import annotations

from dataclasses import replace
from pathlib import Path

from . import engines, media, queue
from .manifest import Project


def run(
    project: Project,
    shot_ids: list[str] | None = None,
    preview: bool = False,
    resume: bool = True,
) -> Path:
    if project.kind != "film":
        raise ValueError(f"{project.id} is a game; use studio build")

    adapter = engines.get(project.engine)
    width, height = project.resolution
    if preview:
        width = max(2, width // 2)
        height = max(2, height // 2)

    frames_root = project.media_dir / "_frames"
    frames_root.mkdir(parents=True, exist_ok=True)
    state_path = frames_root / "state.json"
    state = queue.load_state(state_path)

    selected = project.shots
    if shot_ids:
        known = {shot.id for shot in project.shots}
        missing = [shot_id for shot_id in shot_ids if shot_id not in known]
        if missing:
            raise ValueError(f"unknown shot(s): {', '.join(missing)}")
        selected = [shot for shot in project.shots if shot.id in shot_ids]

    for shot in selected:
        out = frames_root / shot.id if len(project.shots) > 1 else frames_root
        source = queue.source_hash(project, shot)
        settings = queue.settings_hash(project, shot, width, height, preview)
        if resume and queue.shot_complete(out, shot, state, source, settings):
            print(f"skip {project.id}/{shot.id}: complete")
            continue
        media.clear_dir(out)
        out.mkdir(parents=True, exist_ok=True)
        adapter.prepare(project)
        rendered = replace(project, resolution=(width, height))
        adapter.render(rendered, shot, out)
        produced = len(list(out.glob("frame_*.png")))
        if produced != shot.frames:
            raise RuntimeError(
                f"{project.id}/{shot.id} produced {produced} frames, expected {shot.frames}"
            )
        queue.mark_complete(state, shot, source, settings)
        queue.save_state(state_path, state)
        print(f"done {project.id}/{shot.id}: {produced} frames")

    complete = all(
        queue.shot_complete(
            frames_root / shot.id if len(project.shots) > 1 else frames_root,
            shot,
            state,
            queue.source_hash(project, shot),
            queue.settings_hash(project, shot, width, height, preview),
        )
        for shot in project.shots
    )
    if not complete:
        print(f"partial {project.id}: remaining shots are not encoded yet")
        return frames_root

    if preview:
        media.encode_preview(project, frames_root, width, height)
    else:
        media.encode_project(project, frames_root, width, height)
    return frames_root
```

- [ ] **Step 7: Wire the CLI**

In `studio/studio.py`, replace `cmd_render` with:

```python
def cmd_render(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    errors = manifest.validate(project)
    if errors:
        raise SystemExit("invalid project:\n  " + "\n  ".join(errors))
    shot_ids = [args.shot] if args.shot else None
    render.run(project, shot_ids=shot_ids, preview=args.preview, resume=args.resume)
    return 0
```

Replace the `render_cmd` parser block with:

```python
render_cmd = sub.add_parser("render", help="render a project to media")
render_cmd.add_argument("id")
render_cmd.add_argument("--shot", default="", help="render one shot")
render_cmd.add_argument("--resume", action="store_true", help="skip completed shots")
render_cmd.add_argument("--preview", action="store_true", help="half resolution preview")
render_cmd.set_defaults(func=cmd_render)
```

Make resume the default for films in `cmd_render`:

```python
resume = args.resume or project.kind == "film"
render.run(project, shot_ids=shot_ids, preview=args.preview, resume=resume)
```

- [ ] **Step 8: Run the queue and manifest tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_queue.py studio/tests/test_manifest.py -v`

Expected: PASS. `media.encode_project` does not exist yet, but it is monkeypatched in these tests. The real render path fails until Task 7.

- [ ] **Step 9: Commit**

```bash
git add studio/lib/queue.py studio/lib/render.py studio/studio.py studio/tests/test_queue.py
git commit -m "feat: render films shot by shot with resume"
```

---

### Task 7: Declared outputs, audio and encoding

**Files:**
- Modify: `studio/lib/media.py`
- Modify: `studio/lib/render.py` only if the signatures differ.
- Test: `studio/tests/test_media.py`

**Interfaces:**
- Produces: `media.encode_project(project, frames_root: Path, width: int, height: int) -> dict[str, Path]`.
- Produces: `media.encode_preview(project, frames_root: Path, width: int, height: int) -> Path`.
- Produces: `media.has_audio(path: Path) -> bool`, `media.measure_loudness(path: Path) -> dict`.
- Produces: `media.resolve_poster(project) -> Path`.
- Consumes: `Project.outputs`, `Project.shots`, `Project.audio`, `Project.poster_time`.

- [ ] **Step 1: Write the failing media tests**

Replace `studio/tests/test_media.py` with:

```python
import subprocess
from pathlib import Path

import pytest
from PIL import Image

from studio.lib import media
from studio.lib.manifest import Project, Shot


def make_project(tmp_path: Path, outputs: list[str], shots: list[Shot] | None = None) -> Project:
    return Project(
        id="099-media-test",
        type="3d",
        title="Media",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(160, 90),
        fps=24,
        frames=4,
        poster_time=0.0,
        outputs=outputs,
        kind="film",
        shots=shots or [Shot("main", "scene.py", 4)],
        root=tmp_path,
    )


def frames(path: Path, count: int) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    for index in range(1, count + 1):
        Image.new("RGB", (160, 90), (index * 20, 40, 80)).save(path / f"frame_{index:04d}.png")
    return path


def test_budget_rejects_oversize(tmp_path, monkeypatch):
    path = tmp_path / "a.gif"
    path.write_bytes(b"x" * 100)
    monkeypatch.setattr(media, "BUDGET_MB", {".gif": 0.00001})
    with pytest.raises(ValueError, match="budget"):
        media.check_budget(path)


def test_parse_fps():
    assert media.parse_fps("24/1") == 24.0
    assert media.parse_fps("30000/1001") == pytest.approx(29.97, abs=0.01)


def test_budget_allows_small(tmp_path):
    path = tmp_path / "a.mp4"
    path.write_bytes(b"x" * 100)
    media.check_budget(path)


def test_unknown_suffix_is_ignored(tmp_path):
    path = tmp_path / "a.xyz"
    path.write_bytes(b"x" * 10_000_000)
    media.check_budget(path)


def test_resolve_poster_prefers_named_poster(tmp_path):
    project = make_project(tmp_path, [
        "media/099-media-test/hero.png",
        "media/099-media-test/poster.jpg",
    ])
    assert media.resolve_poster(project).name == "poster.jpg"


def test_encode_project_writes_declared_outputs(tmp_path):
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/reel.webm",
        "media/099-media-test/poster.jpg",
    ])
    source = frames(tmp_path / "frames", 4)
    outs = media.encode_project(project, source, 160, 90)
    assert outs["mp4"].exists()
    assert outs["webm"].exists()
    assert outs["poster"].exists()
    info = media.probe(outs["mp4"])
    assert (info["width"], info["height"]) == (160, 90)
    assert info["duration"] == pytest.approx(4 / 24, abs=0.15)


def test_encode_project_muxes_audio(tmp_path):
    audio = tmp_path / "score.wav"
    subprocess.run([
        str(media.find_tool("ffmpeg")), "-y", "-f", "lavfi",
        "-i", "sine=frequency=220:duration=0.2", str(audio),
    ], check=True, capture_output=True)
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/poster.jpg",
    ])
    project.audio = {"score": "score.wav"}
    source = frames(tmp_path / "frames", 4)
    outs = media.encode_project(project, source, 160, 90)
    assert media.has_audio(outs["mp4"]) is True


def test_encode_project_concatenates_shots(tmp_path):
    first = frames(tmp_path / "frames" / "a", 2)
    second = frames(tmp_path / "frames" / "b", 2)
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/poster.jpg",
    ], shots=[Shot("a", "scene.py", 2), Shot("b", "scene.py", 2)])
    outs = media.encode_project(project, tmp_path / "frames", 160, 90)
    info = media.probe(outs["mp4"])
    assert info["duration"] == pytest.approx(4 / 24, abs=0.2)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_media.py -v`

Expected: failures for missing `resolve_poster`, `encode_project`, `has_audio`.

- [ ] **Step 3: Implement media encoding**

In `studio/lib/media.py`, keep `probe`, `check_budget`, `assert_spec`, `clear_dir`. Replace `encode` with these functions:

```python
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
        _run([
            str(find_tool("ffmpeg")), "-y", "-i", str(mp4 or master), "-vf",
            "fps=24,scale=720:-1:flags=lanczos,palettegen=max_colors=128", str(palette),
        ])
        _run([
            str(find_tool("ffmpeg")), "-y", "-i", str(mp4 or master), "-i", str(palette),
            "-lavfi", "fps=24,scale=720:-1:flags=lanczos[x];[x][1:v]"
            "paletteuse=dither=bayer:bayer_scale=3", str(gif),
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
```

Import `ROOT`, `find_ffprobe` and `find_tool` from `.config` at the top of `media.py`. `resolve_poster` uses `ROOT` directly. Every encode input is a real file because `_encode_master` always writes `_master.mp4`, so `_final_mp4`, the WebM pass, the GIF pass, the poster pass and `encode_preview` all read a file.

`assert_spec` checks budget; preview MP4 under 20 MB fine.

- [ ] **Step 4: Run the media tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_media.py -v`

Expected: PASS. FFmpeg encodes small 160x90 clips.

- [ ] **Step 5: Run the queue tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_queue.py -v`

Expected: PASS with the real `encode_project` patched.

- [ ] **Step 6: Commit**

```bash
git add studio/lib/media.py studio/tests/test_media.py
git commit -m "feat: encode declared outputs with shots and audio"
```

---

### Task 8: Verification

**Files:**
- Create: `studio/lib/verify/__init__.py`
- Create: `studio/lib/verify/frames.py`
- Create: `studio/lib/verify/media.py`
- Create: `studio/lib/verify/audio.py`
- Create: `studio/lib/verify/gltf.py`
- Create: `studio/lib/verify/builds.py`
- Modify: `studio/lib/render.py`
- Modify: `studio/studio.py`
- Test: `studio/tests/test_verify.py`

**Interfaces:**
- Produces: `verify.Check(name: str, ok: bool, detail: str)`.
- Produces: `verify.run(project, stage="render"|"all") -> list[Check]`.
- Produces: `frames.scan(out, shot) -> list[str]`, `audio.check(path) -> list[str]`, `gltf.inspect(path) -> dict`, `builds.check(project) -> list[str]`.
- Consumes: `media.probe`, `media.has_audio`, `media.measure_loudness`, `project.shots`, `project.outputs`.

- [ ] **Step 1: Write the failing verification tests**

Create `studio/tests/test_verify.py`:

```python
import json
import struct
from pathlib import Path

from PIL import Image

from studio.lib import verify
from studio.lib.manifest import Project, Shot
from studio.lib.verify import frames, gltf


def make_project(tmp_path: Path) -> Project:
    return Project(
        id="099-verify-test",
        type="3d",
        title="Verify",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(64, 36),
        fps=24,
        frames=3,
        poster_time=0.0,
        outputs=["media/099-verify-test/reel.mp4"],
        kind="film",
        shots=[Shot("main", "scene.py", 3)],
        root=tmp_path,
    )


def test_black_frames_are_flagged(tmp_path):
    out = tmp_path / "frames"
    out.mkdir()
    Image.new("RGB", (64, 36), (0, 0, 0)).save(out / "frame_0001.png")
    problems = frames.scan(out, Shot("main", "scene.py", 1))
    assert any("black" in problem for problem in problems)


def test_frozen_run_is_flagged_unless_still(tmp_path):
    out = tmp_path / "frames"
    out.mkdir()
    for index in range(1, 21):
        Image.new("RGB", (64, 36), (40, 40, 40)).save(out / f"frame_{index:04d}.png")
    problems = frames.scan(out, Shot("main", "scene.py", 20))
    assert any("frozen" in problem for problem in problems)
    assert frames.scan(out, Shot("main", "scene.py", 20, still=True)) == []


def test_glb_header_and_animation_count(tmp_path):
    document = {"asset": {"version": "2.0"}, "animations": [{}]}
    payload = json.dumps(document).encode("utf-8")
    while len(payload) % 4:
        payload += b" "
    total = 12 + 8 + len(payload)
    data = struct.pack("<4sII", b"glTF", 2, total)
    data += struct.pack("<II", len(payload), 0x4E4F534A) + payload
    path = tmp_path / "model.glb"
    path.write_bytes(data)
    info = gltf.inspect(path)
    assert info["animations"] == 1
    assert info["version"] == 2


def test_verify_reports_missing_outputs(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    monkeypatch.setattr(Project, "media_dir", property(lambda self: tmp_path / "media"))
    checks = verify.run(project, stage="render")
    assert any(not check.ok and "missing" in check.detail for check in checks)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_verify.py -v`

Expected: `ModuleNotFoundError` for `studio.lib.verify`.

- [ ] **Step 3: Implement frame, media, audio, glTF and build checks**

Create `studio/lib/verify/frames.py`:

```python
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
        mean, data = _stats(path)
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
```

Create `studio/lib/verify/media.py`:

```python
from __future__ import annotations

from pathlib import Path

from .. import media
from ..config import ROOT


def check(project) -> list[str]:
    problems: list[str] = []
    for suffix in (".mp4", ".webm", ".gif", ".jpg", ".jpeg", ".png", ".glb"):
        for output in project.outputs:
            path = Path(output)
            if path.suffix.lower() != suffix:
                continue
            full = ROOT / output if not path.is_absolute() else path
            if not full.exists():
                problems.append(f"missing output {output}")
                continue
            try:
                media.check_budget(full)
            except ValueError as exc:
                problems.append(str(exc))
            if suffix in {".mp4", ".webm"}:
                try:
                    info = media.probe(full)
                except RuntimeError as exc:
                    problems.append(str(exc))
                    continue
                if (info["width"], info["height"]) != project.resolution:
                    problems.append(
                        f"{output} is {info['width']}x{info['height']}, "
                        f"expected {project.resolution[0]}x{project.resolution[1]}"
                    )
                if abs(info["fps"] - project.fps) > 0.06:
                    problems.append(f"{output} is {info['fps']:.2f} fps, expected {project.fps}")
    return problems
```

Create `studio/lib/verify/audio.py`:

```python
from __future__ import annotations

from pathlib import Path

from .. import media


def check(project) -> list[str]:
    if not project.audio:
        return []
    mp4 = project.output_path(".mp4")
    if not mp4 or not mp4.exists():
        return [f"audio declared but {project.id} has no mp4"]
    if not media.has_audio(mp4):
        return [f"{mp4.name} has no audio stream"]
    try:
        loudness = media.measure_loudness(mp4)
        integrated = float(loudness.get("input_i", 0))
    except Exception as exc:
        return [f"loudness check failed: {exc}"]
    problems = []
    if abs(integrated + 14.0) > 1.0:
        problems.append(f"integrated loudness {integrated:.1f} LUFS, expected -14")
    return problems
```

Create `studio/lib/verify/gltf.py`:

```python
from __future__ import annotations

import json
import struct
from pathlib import Path


def inspect(path: Path) -> dict:
    data = path.read_bytes()
    if len(data) < 20:
        raise ValueError(f"{path.name} is too small to be a GLB")
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"{path.name} is not a GLB")
    if version != 2:
        raise ValueError(f"{path.name} is glTF version {version}, expected 2")
    if length != len(data):
        raise ValueError(f"{path.name} length header says {length}, file is {len(data)}")
    chunk_length, chunk_type = struct.unpack_from("<II", data, 12)
    if chunk_type != 0x4E4F534A:
        raise ValueError(f"{path.name} first chunk is not JSON")
    document = json.loads(data[20:20 + chunk_length])
    return {
        "version": version,
        "animations": len(document.get("animations") or []),
        "meshes": len(document.get("meshes") or []),
        "nodes": len(document.get("nodes") or []),
    }
```

Create `studio/lib/verify/builds.py`:

```python
from __future__ import annotations

from pathlib import Path

from ..config import ROOT

MAX_BUILD_MB = 25.0


def check(project) -> list[str]:
    problems: list[str] = []
    for output in project.outputs:
        path = ROOT / output
        if path.name != "index.html" or not path.exists():
            continue
        total = sum(item.stat().st_size for item in path.parent.rglob("*") if item.is_file())
        total_mb = total / (1024 * 1024)
        if total_mb > MAX_BUILD_MB:
            problems.append(f"{path.parent.name} build is {total_mb:.1f} MB, budget {MAX_BUILD_MB:g} MB")
    return problems
```

Create `studio/lib/verify/__init__.py`:

```python
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from ..config import ROOT
from . import audio, builds, frames, gltf
from . import media as media_checks


@dataclass
class Check:
    name: str
    ok: bool
    detail: str = ""


def run(project, stage: str = "all") -> list[Check]:
    checks: list[Check] = []
    problems = []
    for shot in project.shots:
        out = project.media_dir / "_frames"
        out = out / shot.id if len(project.shots) > 1 else out
        problems.extend(frames.scan(out, shot))
    checks.append(Check("frames", not problems, "; ".join(problems)))
    media_problems = media_checks.check(project)
    checks.append(Check("media", not media_problems, "; ".join(media_problems)))
    if stage == "all":
        audio_problems = audio.check(project)
        checks.append(Check("audio", not audio_problems, "; ".join(audio_problems)))
        asset_problems = []
        for output in project.outputs:
            path = Path(output)
            if path.suffix.lower() == ".glb":
                full = ROOT / output if not path.is_absolute() else path
                try:
                    info = gltf.inspect(full)
                    if info["animations"] == 0:
                        asset_problems.append(f"{path.name} has no animations")
                except Exception as exc:
                    asset_problems.append(str(exc))
        checks.append(Check("gltf", not asset_problems, "; ".join(asset_problems)))
        build_problems = builds.check(project)
        checks.append(Check("builds", not build_problems, "; ".join(build_problems)))
    return checks
```

`verify/__init__.py` imports the media checks module as `media_checks`, because `media` already names the sibling package. To avoid a circular import, `verify/media.py` imports `from .. import media`, which is the library module, not the verify submodule.

Also `frames.scan` returns early when count mismatches, skipping black/frozen. Fine.

- [ ] **Step 4: Wire verify into the CLI and render**

In `studio/studio.py` add `verify` to imports and add:

```python
def cmd_verify(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    checks = verify.run(project, stage="all")
    failed = False
    for check in checks:
        mark = "ok  " if check.ok else "FAIL"
        print(f"{mark} {check.name:8} {check.detail}")
        failed = failed or not check.ok
    return 1 if failed else 0
```

Add parser:

```python
verify_cmd = sub.add_parser("verify", help="verify rendered outputs")
verify_cmd.add_argument("id")
verify_cmd.set_defaults(func=cmd_verify)
```

In `render.run`, after encoding, call a light verification and raise if frames or media fail:

```python
problems = [
    check for check in verify.run(project, stage="render") if not check.ok
]
if problems:
    raise RuntimeError("verification failed: " + "; ".join(
        f"{check.name}: {check.detail}" for check in problems
    ))
```

Import `verify` in `render.py`.

- [ ] **Step 5: Run the tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_verify.py studio/tests/test_queue.py studio/tests/test_media.py -v`

Expected: PASS. The queue tests monkeypatch `encode_project`; verify is patched or runs on synthetic frames? The queue tests use 2x2 PNGs of `b"x"`, so `frames.scan` will fail to open them. Either patch `verify.run` in the queue tests or use real tiny PNGs in `FakeAdapter`. Change `FakeAdapter.render` to write a valid 2x2 PNG with Pillow:

```python
from PIL import Image
...
Image.new("RGB", (2, 2), (index * 20, 40, 80)).save(out / f"frame_{index:04d}.png")
```

Update the test code accordingly. Then verification passes (2x2 nonblack). Settings resolution is 320x180 but frames are 2x2; `verify` does not check frame pixel size, only media. Fine. `encode_project` is patched in those tests. Good.

- [ ] **Step 6: Commit**

```bash
git add studio/lib/verify studio/lib/render.py studio/studio.py studio/tests/test_verify.py studio/tests/test_queue.py
git commit -m "feat: verify frames, media, audio, glTF and builds"
```

---

### Task 9: Asset catalog, lanes and credits

**Files:**
- Create: `studio/lib/assets.py`
- Create: `assets/catalog.yaml`
- Create: `assets/README.md`
- Modify: `studio/lib/manifest.py`
- Modify: `studio/studio.py`
- Modify: `.gitignore`
- Test: `studio/tests/test_assets.py`
- Test: `studio/tests/test_manifest.py`

**Interfaces:**
- Produces: `assets.Asset(id, lane, license, source, path, sha256, credit="", download="")`.
- Produces: `assets.load() -> list[Asset]`, `assets.ids() -> set[str]`, `assets.verify(entries=None, offline=True) -> list[str]`, `assets.fetch(entries=None) -> list[str]`, `assets.credits_markdown(entries=None) -> str`, `assets.write_credits(entries=None) -> Path`.
- Consumes: `config.ROOT`.

- [ ] **Step 1: Write the failing asset tests**

Create `studio/tests/test_assets.py`:

```python
from pathlib import Path

from studio.lib import assets


def make_asset(tmp_path: Path, **overrides) -> assets.Asset:
    repo = tmp_path / "assets" / "repo"
    repo.mkdir(parents=True, exist_ok=True)
    path = repo / "texture.png"
    path.write_bytes(b"hello")
    values = {
        "id": "texture",
        "lane": "repo",
        "license": "CC0-1.0",
        "source": "https://example.com/texture",
        "path": "assets/repo/texture.png",
        "sha256": assets.sha256_file(path),
        "credit": "Example",
    }
    values.update(overrides)
    return assets.Asset(**values)


def test_verify_accepts_a_valid_repo_asset(tmp_path):
    entry = make_asset(tmp_path)
    assert assets.verify([entry], root=tmp_path, offline=True) == []


def test_verify_rejects_wrong_lane_location(tmp_path):
    entry = make_asset(tmp_path, path="assets/embed/texture.png")
    assert any("lane" in problem for problem in assets.verify([entry], root=tmp_path))


def test_verify_rejects_hash_mismatch(tmp_path):
    entry = make_asset(tmp_path, sha256="0" * 64)
    assert any("hash" in problem for problem in assets.verify([entry], root=tmp_path))


def test_offline_verify_skips_missing_embed_files(tmp_path):
    entry = make_asset(
        tmp_path, lane="embed", path="assets/embed/missing.hdr",
        source="https://example.com/a.hdr",
    )
    assert assets.verify([entry], root=tmp_path, offline=True) == []
    assert any("missing" in problem for problem in assets.verify([entry], root=tmp_path, offline=False))


def test_fetch_copies_a_file_url(tmp_path):
    source = tmp_path / "source.png"
    source.write_bytes(b"asset")
    entry = assets.Asset(
        id="remote", lane="repo", license="CC0-1.0",
        source=source.as_uri(), path="assets/repo/remote.png",
        sha256=assets.sha256_file(source), credit="Example",
    )
    assert assets.fetch([entry], root=tmp_path) == []
    assert (tmp_path / "assets/repo/remote.png").read_bytes() == b"asset"


def test_credits_only_list_repo_assets(tmp_path):
    repo = make_asset(tmp_path)
    embed = make_asset(
        tmp_path, id="hidden", lane="embed", path="assets/embed/x.bin",
        source="https://example.com/x",
    )
    text = assets.credits_markdown([repo, embed])
    assert "texture" in text
    assert "hidden" not in text
    assert "CC0-1.0" in text
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_assets.py -v`

Expected: `ModuleNotFoundError` for `studio.lib.assets`.

- [ ] **Step 3: Implement assets**

Create `studio/lib/assets.py`:

```python
from __future__ import annotations

import hashlib
import json
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import yaml

from .config import ROOT

LANES = {
    "repo": "assets/repo",
    "embed": "assets/embed",
    "private": "assets/private",
}
CATALOG = ROOT / "assets" / "catalog.yaml"
NOTICES = ROOT / "THIRD_PARTY_NOTICES.md"
CREDITS_TS = ROOT / "showcase" / "src" / "credits.generated.ts"


@dataclass(frozen=True)
class Asset:
    id: str
    lane: str
    license: str
    source: str
    path: str
    sha256: str
    credit: str = ""
    download: str = ""


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path | None = None) -> list[Asset]:
    catalog = path or CATALOG
    if not catalog.exists():
        return []
    data = yaml.safe_load(catalog.read_text(encoding="utf-8")) or []
    return [Asset(**entry) for entry in data]


def ids() -> set[str]:
    return {entry.id for entry in load()}


def verify(entries: list[Asset] | None = None, root: Path | None = None, offline: bool = True) -> list[str]:
    root = root or ROOT
    entries = entries if entries is not None else load()
    problems: list[str] = []
    for entry in entries:
        if entry.lane not in LANES:
            problems.append(f"{entry.id}: unknown lane {entry.lane}")
            continue
        if not entry.license or not entry.source or not entry.sha256:
            problems.append(f"{entry.id}: license, source and sha256 are required")
        prefix = LANES[entry.lane]
        if not entry.path.startswith(prefix + "/"):
            problems.append(f"{entry.id}: lane {entry.lane} path must live under {prefix}/")
            continue
        file = root / entry.path
        if not file.exists():
            if entry.lane == "repo":
                problems.append(f"{entry.id}: missing {entry.path}")
            elif not offline:
                problems.append(f"{entry.id}: missing {entry.path}")
            continue
        if sha256_file(file) != entry.sha256:
            problems.append(f"{entry.id}: hash mismatch for {entry.path}")
    return problems


def fetch(entries: list[Asset] | None = None, root: Path | None = None) -> list[str]:
    root = root or ROOT
    entries = entries if entries is not None else load()
    problems: list[str] = []
    for entry in entries:
        if entry.lane == "private":
            problems.append(f"{entry.id}: private assets are never fetched")
            continue
        target = root / entry.path
        if target.exists() and sha256_file(target) == entry.sha256:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        url = entry.download or entry.source
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                target.write_bytes(response.read())
        except Exception as exc:
            problems.append(f"{entry.id}: download failed: {exc}")
            continue
        if sha256_file(target) != entry.sha256:
            target.unlink(missing_ok=True)
            problems.append(f"{entry.id}: downloaded hash mismatch")
    return problems


def credits_markdown(entries: list[Asset] | None = None) -> str:
    entries = entries if entries is not None else load()
    public = sorted((entry for entry in entries if entry.lane == "repo"), key=lambda item: item.id)
    lines = [
        "# Third party notices",
        "",
        "Assets in the repo lane. Engine and tool versions are listed in docs/engines.md.",
        "",
        "| Asset | Author | License | Source |",
        "| --- | --- | --- | --- |",
    ]
    for entry in public:
        lines.append(
            f"| {entry.id} | {entry.credit or 'Unknown'} | {entry.license} | {entry.source} |"
        )
    return "\n".join(lines) + "\n"


def write_credits(entries: list[Asset] | None = None) -> Path:
    entries = entries if entries is not None else load()
    NOTICES.write_text(credits_markdown(entries), encoding="utf-8")
    public = sorted((entry for entry in entries if entry.lane == "repo"), key=lambda item: item.id)
    payload = json.dumps([
        {"id": entry.id, "author": entry.credit, "license": entry.license, "source": entry.source}
        for entry in public
    ], indent=2)
    CREDITS_TS.write_text(
        "// generated by studio assets credits, do not edit\n"
        "export type Credit = { id: string; author: string; license: string; source: string };\n"
        f"export const credits: Credit[] = {payload};\n",
        encoding="utf-8",
    )
    return NOTICES
```

- [ ] **Step 4: Add the catalog, policy and ignore rules**

Create `assets/catalog.yaml`:

```yaml
# Curated third party assets. One entry per file.
# lane: repo (committed), embed (baked, not committed), private (owner files).
[]
```

Create `assets/README.md`:

```markdown
# Assets

Three lanes, one catalog.

- `repo/` is committed. Only CC0, CC-BY, MIT, OFL or public domain. Every entry is credited.
- `embed/` is not committed. EULA or royalty free files that are baked into renders or builds.
- `private/` is not committed. Owner files such as the portrait source and voice reference.

Every file has an entry in `catalog.yaml` with lane, license, source, path and sha256.
Run `studio assets verify --offline` before committing.
```

Add to `.gitignore`:

```
assets/embed/
assets/private/
showcase/src/credits.generated.ts
```

Keep `assets/generated/` and add `THIRD_PARTY_NOTICES.md`? Notices are committed, so do not ignore.

- [ ] **Step 5: Validate asset ids in manifests**

At the top of `studio/lib/manifest.py` add `from . import assets`. In `validate`, before returning, add:

```python
known_assets = assets.ids()
for asset_id in project.assets:
    if asset_id not in known_assets:
        errors.append(f"asset '{asset_id}' is not in assets/catalog.yaml")
```

Add to `studio/tests/test_manifest.py`:

```python
def test_rejects_unknown_asset_id(tmp_path):
    project = manifest.load(write(tmp_path, V2, ("film.py", "a.py", "b.py")))
    project.assets = ["not-in-catalog"]
    assert any("not in assets/catalog.yaml" in error for error in manifest.validate(project))
```

- [ ] **Step 6: Add the assets CLI**

In `studio/studio.py`, add `assets` to the imports and add:

```python
def cmd_assets(args: argparse.Namespace) -> int:
    if args.action == "fetch":
        problems = assets.fetch()
    elif args.action == "verify":
        problems = assets.verify(offline=args.offline)
    else:
        path = assets.write_credits()
        print(f"credits -> {path}")
        return 0
    for problem in problems:
        print(f"FAIL {problem}")
    return 1 if problems else 0
```

Add the parser:

```python
assets_cmd = sub.add_parser("assets", help="fetch, verify or credit assets")
assets_cmd.add_argument("action", choices=["fetch", "verify", "credits"])
assets_cmd.add_argument("--offline", action="store_true", help="skip missing embed and private files")
assets_cmd.set_defaults(func=cmd_assets)
```

- [ ] **Step 7: Run the tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_assets.py studio/tests/test_manifest.py -v`

Expected: PASS.

Run the real empty catalog check:

Run: `./.venv/Scripts/python studio/studio.py assets verify --offline`

Expected: exit 0 with no output.

- [ ] **Step 8: Commit**

```bash
git add studio/lib/assets.py studio/lib/manifest.py studio/studio.py assets .gitignore studio/tests/test_assets.py studio/tests/test_manifest.py
git commit -m "feat: gate assets by license lane and generate credits"
```

---

### Task 10: Publish v2

**Files:**
- Modify: `studio/lib/publish.py`
- Modify: `showcase/src/content.ts` only if a type label is needed.
- Test: `studio/tests/test_publish.py`

**Interfaces:**
- Produces: `publish.build_entry(project) -> dict | None` (pure entry construction).
- Produces: generated `Project` type with `kind: "film" | "game"`.
- Consumes: `assets.write_credits`.

- [ ] **Step 1: Write the failing publish test**

Create `studio/tests/test_publish.py`:

```python
from studio.lib import publish
from studio.lib.manifest import Project, Shot


def test_entry_uses_declared_media_names(tmp_path, monkeypatch):
    for name in ("maker.mp4", "maker.webm", "poster.jpg"):
        path = tmp_path / name
        path.write_bytes(b"x")
    project = Project(
        id="010-maker",
        type="3d",
        title="Maker",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(1920, 800),
        fps=24,
        frames=24,
        poster_time=0.0,
        outputs=[
            "media/010-maker/maker.mp4",
            "media/010-maker/maker.webm",
            "media/010-maker/poster.jpg",
        ],
        kind="film",
        shots=[Shot("main", "scene.py", 24)],
        root=tmp_path,
    )
    monkeypatch.setattr(publish, "ROOT", tmp_path)
    (tmp_path / "media" / "010-maker").mkdir(parents=True)
    for name in ("maker.mp4", "maker.webm", "poster.jpg"):
        (tmp_path / "media" / "010-maker" / name).write_bytes(b"x")
    monkeypatch.setattr(publish.media, "probe", lambda path: {"duration": 12.0})
    entry = publish.build_entry(project)
    assert entry["kind"] == "film"
    assert entry["mp4"] == "media/010-maker/maker.mp4"
    assert entry["webm"] == "media/010-maker/maker.webm"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_publish.py -v`

Expected: `AttributeError: module 'studio.lib.publish' has no attribute 'build_entry'`.

- [ ] **Step 3: Refactor publish**

In `studio/lib/publish.py`, replace the per-project entry block with a helper. Keep copying media in `run()`. Exact replacement for the loop body:

```python
def build_entry(project) -> dict | None:
    outputs = [ROOT / output for output in project.outputs if (ROOT / output).exists()]
    if not outputs:
        return None
    media_dir = ROOT / "media" / project.id
    if not (media_dir / "poster.jpg").exists():
        return None
    by_suffix: dict[str, Path] = {}
    for path in outputs:
        suffix = path.suffix.lower()
        if suffix not in by_suffix and suffix in {".mp4", ".webm", ".gif", ".jpg", ".png", ".glb"}:
            by_suffix[suffix] = path
    entry: dict = {
        "id": project.id,
        "kind": project.kind,
        "type": project.type,
        "title": project.title,
        "summary": project.summary,
        "tags": project.tags,
        "poster": f"media/{project.id}/poster.jpg",
        "engine": project.engine,
        "resolution": f"{project.resolution[0]}x{project.resolution[1]}",
        "fps": project.fps,
        "frames": project.frames,
    }
    if mp4 := by_suffix.get(".mp4"):
        entry["mp4"] = f"media/{project.id}/{mp4.name}"
        entry["duration"] = _duration_label(media.probe(mp4)["duration"])
    if webm := by_suffix.get(".webm"):
        entry["webm"] = f"media/{project.id}/{webm.name}"
    if gif := by_suffix.get(".gif"):
        entry["gif"] = f"media/{project.id}/{gif.name}"
    if glb := by_suffix.get(".glb"):
        entry["model"] = f"models/{project.id}.glb"
    sheet = project.media_dir / "sheet.jpg"
    if sheet.exists():
        entry["sheet"] = f"media/{project.id}/sheet.jpg"
    hero = project.media_dir / "hero.png"
    if hero.exists():
        entry["hero"] = f"media/{project.id}/hero.png"
    if project.kind == "game":
        build = project.root / "build" / "web"
        if (build / "index.html").exists():
            entry["play"] = f"builds/{project.id}/index.html"
    return entry
```

In `run()`, replace the per-project copy and entry logic with:

```python
for project in projects:
    entry = build_entry(project)
    if not entry:
        print(f"skip {project.id}: no outputs or poster yet")
        continue
    target = PUBLIC / "media" / project.id
    target.mkdir(parents=True, exist_ok=True)
    for output in project.outputs:
        path = ROOT / output
        if path.exists() and path.suffix.lower() in {".mp4", ".webm", ".gif", ".jpg", ".png"}:
            shutil.copy2(path, target / path.name)
    if entry.get("model"):
        model = next((ROOT / output for output in project.outputs if output.lower().endswith(".glb")), None)
        if model and model.exists():
            (PUBLIC / "models").mkdir(parents=True, exist_ok=True)
            shutil.copy2(model, PUBLIC / "models" / f"{project.id}.glb")
    if entry.get("play"):
        build = project.root / "build" / "web"
        play_dir = PUBLIC / "builds" / project.id
        if play_dir.exists():
            shutil.rmtree(play_dir)
        shutil.copytree(build, play_dir)
        (play_dir / ".nojekyll").touch()
    entries.append(entry)
```

Update the generated TypeScript type:

```python
'  id: string; kind: "film" | "game"; type: "2d" | "3d" | "game"; title: string; summary: string;\n'
```

Call `assets.write_credits()` at the end of `run()` before writing the generated projects file, and print the path.

- [ ] **Step 4: Run the tests**

Run: `./.venv/Scripts/python -m pytest studio/tests/test_publish.py -v`

Expected: PASS.

Run the real publish:

Run: `./.venv/Scripts/python studio/studio.py publish`

Expected: 001, 002, 003 and 004 still publish. The generated file has `kind`.

- [ ] **Step 5: Build the site**

Run:

```bash
cd showcase && pnpm typecheck && pnpm build
```

Expected: PASS. The new required `kind` field is present in every generated entry.

- [ ] **Step 6: Commit**

```bash
git add studio/lib/publish.py studio/tests/test_publish.py
git commit -m "feat: publish films and engine artifacts by declared output"
```

---

### Task 11: Docs, CI and regression

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `.github/workflows/ci.yml`
- Modify: `studio/tests/test_templates.py` only if template expectations change.

**Interfaces:**
- Produces: documented commands and lane rules.
- Produces: CI that runs the asset gate offline.

- [ ] **Step 1: Update AGENTS.md**

Replace the commands block with:

```bash
./.venv/Scripts/python studio/studio.py doctor --deep
./.venv/Scripts/python studio/studio.py validate
./.venv/Scripts/python studio/studio.py new 2d 004-my-study --title "My Study"
./.venv/Scripts/python studio/studio.py render 001-2d-bounce
./.venv/Scripts/python studio/studio.py render 010-maker-at-work --preview
./.venv/Scripts/python studio/studio.py render 010-maker-at-work --shot s02-portrait
./.venv/Scripts/python studio/studio.py build 003-micro-game
./.venv/Scripts/python studio/studio.py export 004-lantern-keeper
./.venv/Scripts/python studio/studio.py verify 004-lantern-keeper
./.venv/Scripts/python studio/studio.py assets verify --offline
./.venv/Scripts/python studio/studio.py publish
./.venv/Scripts/python -m pytest studio/tests -v
```

Add sections:

```markdown
## Engines

Every engine lives behind an adapter in `studio/lib/engines/`. `studio doctor --deep` reports version, path, supported kinds and blockers. A missing engine is a blocker, not a crash.

Manifests use `kind: film | game` and may declare `shots`. A shot has an id, an entry and a frame count. Shot frames must total `render.frames`. Projects without shots get one implicit `main` shot.

## Assets

Three lanes: `repo/` committed and credited, `embed/` baked and not committed, `private/` owner files and not committed. Every asset has a catalog entry with license, source, path and sha256. Run `studio assets verify --offline` before committing. Mixamo is banned.
```

- [ ] **Step 2: Update README.md**

Add a short engine matrix section listing Blender, Godot, Unity, Unreal, GDevelop, LÖVE, MonoGame and the Python 2D path, with the status measured in `docs/engines.md`. Add the new commands. Keep copy free of em dashes.

- [ ] **Step 3: Update CI**

In `.github/workflows/ci.yml`, after `Validate project manifests`, add:

```yaml
      - name: Verify assets
        run: python studio/studio.py assets verify --offline
```

The `publish` step now generates credits and the project data.

- [ ] **Step 4: Add the build command**

In `studio/studio.py`, add:

```python
def cmd_build(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    if project.kind != "game":
        raise SystemExit(f"{project.id} is not a game; use studio render")
    adapter = engines.get(project.engine)
    out = project.root / "build" / "web"
    target = adapter.build(project, out)
    if not target:
        raise SystemExit(f"{project.engine} has no build target")
    print(f"web build -> {target}")
    return 0
```

Add the parser:

```python
build_cmd = sub.add_parser("build", help="build a playable game")
build_cmd.add_argument("id")
build_cmd.set_defaults(func=cmd_build)
```

Replace `cmd_export` with adapter dispatch:

```python
def cmd_export(args: argparse.Namespace) -> int:
    project = manifest.find(args.id)
    adapter = engines.get(project.engine)
    if project.engine == "blender":
        target = project.output_path(".glb") or project.root / "build" / f"{project.id}.glb"
        result = adapter.export(project, target)
        print(f"glb -> {result}")
        return 0
    if project.kind == "game":
        return cmd_build(args)
    raise SystemExit(f"{project.id} has no export target")
```

- [ ] **Step 5: Run the full test suite**

Run: `./.venv/Scripts/python -m pytest studio/tests -v`

Expected: PASS.

- [ ] **Step 6: Validate every manifest**

Run: `./.venv/Scripts/python studio/studio.py validate`

Expected: `ok` for 001, 002, 003 and 004.

- [ ] **Step 7: Re-render the regression projects**

Render 001, then verify:

```bash
./.venv/Scripts/python studio/studio.py render 001-2d-bounce
./.venv/Scripts/python studio/studio.py verify 001-2d-bounce
```

Render 004, then verify and export:

```bash
./.venv/Scripts/python studio/studio.py render 004-lantern-keeper
./.venv/Scripts/python studio/studio.py export 004-lantern-keeper
./.venv/Scripts/python studio/studio.py verify 004-lantern-keeper
```

Build 003:

```bash
./.venv/Scripts/python studio/studio.py build 003-micro-game
```

Expected: no regression in durations, resolutions or file budgets.

- [ ] **Step 8: Publish and build the site**

```bash
./.venv/Scripts/python studio/studio.py publish
cd showcase && pnpm typecheck && pnpm build
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add AGENTS.md README.md .github/workflows/ci.yml studio/studio.py studio/tests
git commit -m "docs: record the studio OS commands and asset rules"
```

---

## Self-Review

**Spec coverage in this plan:**

- Engine registry and adapter contract: Tasks 1, 2, 4.
- Manifest v2, kinds, shots, audio, engine independence: Task 3.
- Doctor deep and capability matrix: Tasks 4, 5.
- Install Unity, Unreal, GDevelop, LÖVE, MonoGame: Task 5.
- Shot pipeline and resumable queue: Task 6.
- Declared outputs, audio mux, budgets: Task 7.
- Verification of media, frames, audio, glTF and builds: Task 8.
- Asset lanes, catalog, fetch, credits: Task 9.
- Publish by declared output, kind in showcase data: Task 10.
- Docs, CI and regression: Task 11.
- Engine artifacts 005 to 009: Plan B.
- Film, likeness, voice, score: Plan C.

**Known deferrals:**

- Playwright browser smoke tests for builds land in Plan B, when there are new builds to test.
- SSIM baselines land in Plan C, when the film has approved frames.
- `studio new film` and film templates land in Plan C, with the first real film scaffold.
- The site credits page lands in Plan C. This plan generates the data and notices.

**Type consistency:**

- `Shot(id, entry, frames, still)` is used by Tasks 2, 3, 6, 7, 8.
- `Project` fields used by adapters and media come from Task 3.
- `render.run(project, shot_ids, preview, resume)` matches the CLI in Task 6.
- `media.encode_project(project, frames_root, width, height)` matches Task 6.
- `verify.run(project, stage)` matches Task 6 and the CLI in Task 8.
- `assets.Asset` fields match the catalog and Task 9.
- `publish.build_entry(project)` matches Task 10 and the existing `run()` flow.
