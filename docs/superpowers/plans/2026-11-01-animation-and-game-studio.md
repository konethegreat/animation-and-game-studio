# Animation and Game Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reproducible 2D, 3D and game studio in `C:\Users\Konet\My animation and game studio`, with a public GitHub Pages showcase.

**Architecture:** A Python CLI (`studio/studio.py`) drives three renderers: Pillow for 2D animation, Blender headless for 3D, Godot for playable games. FFmpeg encodes and validates media. A Vite + TypeScript site turns curated media and the exported game into a gallery, and GitHub Actions deploys it to Pages.

**Tech Stack:** Python 3.15 (Pillow, PyYAML, pytest), Blender 4.5 LTS, Godot 4.7.2, FFmpeg 9, Node 24, pnpm, Vite, Three.js, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-01-animation-and-game-studio-design.md`

## Global Constraints

- Repo: `konethegreat/animation-and-game-studio`, public, default branch `main`.
- Local root: `C:\Users\Konet\My animation and game studio`.
- Blender 4.5 LTS only. Godot 4.7.2 standard build only. No paid tools. No Git LFS.
- Media budget: GIF ≤ 8 MB, MP4/WebM ≤ 20 MB, poster ≤ 500 KB.
- Every render is validated with ffprobe: duration, resolution, fps, codec.
- 1080p maximum render resolution. Keep scenes light: 11.4 GB RAM, 4 GB VRAM.
- UI is light mode, restrained, with one distinctive hero. No em dashes in any copy.
- Commit curated media only. Raw frames, caches and node_modules never enter git.
- Work in small commits with conventional messages (`feat:`, `fix:`, `docs:`, `chore:`).
- Windows paths in this plan use forward slashes inside commands; quote paths with spaces.

---

## File Map

| Path | Responsibility |
| --- | --- |
| `studio/studio.py` | CLI entry, subcommand dispatch, exit codes |
| `studio/lib/config.py` | Root paths, tool discovery, version checks |
| `studio/lib/manifest.py` | Load and validate `project.yaml` |
| `studio/lib/media.py` | ffprobe, budget checks, MP4/WebM/GIF/poster encoding |
| `studio/lib/render.py` | Dispatch render to Pillow script or Blender |
| `studio/lib/godot.py` | Godot import, headless web export |
| `studio/lib/publish.py` | Regenerate showcase data and copy media |
| `studio/tests/test_manifest.py` | Manifest validation tests |
| `studio/tests/test_media.py` | ffprobe parsing and budget tests |
| `projects/001-2d-bounce/project.yaml` | Manifest for the 2D animation |
| `projects/001-2d-bounce/render.py` | Pillow frame renderer |
| `projects/002-turntable/project.yaml` | Manifest for the 3D reel |
| `projects/002-turntable/scene.py` | Blender scene, animation, GLB export |
| `projects/003-micro-game/project.yaml` | Manifest for the game |
| `projects/003-micro-game/` | Godot project, GDScript, export preset |
| `tools/blender/render.py` | Shared Blender render bootstrap |
| `showcase/` | Vite site, gallery data, Three.js viewer |
| `.github/workflows/ci.yml` | Tests and site build |
| `.github/workflows/deploy.yml` | Pages deploy |
| `README.md`, `AGENTS.md`, `LICENSE` | Showcase front page, conventions, licensing |

---

### Task 1: Toolchain install and `doctor`

**Files:**
- Create: `studio/lib/config.py`
- Create: `studio/lib/__init__.py`
- Create: `studio/studio.py`
- Create: `studio/tests/test_config.py`

**Interfaces:**
- Produces: `config.ROOT: Path`, `config.find_tool(name) -> Path | None`, `config.tool_version(name) -> str`, `config.doctor() -> list[dict]`.
- `doctor()` returns dicts with keys `name`, `path`, `version`, `ok`.

- [ ] **Step 1: Install the three binaries with winget**

```bash
winget install --id BlenderFoundation.Blender.LTS.4.5 -e --silent --accept-package-agreements --accept-source-agreements
winget install --id GodotEngine.GodotEngine -e --silent --accept-package-agreements --accept-source-agreements
winget install --id Gyan.FFmpeg -e --silent --accept-package-agreements --accept-source-agreements
```

Expected: each exits 0, or reports already installed. Winget may raise a UAC prompt for the Blender MSI; approve it.

- [ ] **Step 2: Locate the executables without relying on a refreshed PATH**

```bash
ls "/c/Program Files/Blender Foundation" 2>/dev/null
ls "$LOCALAPPDATA/Microsoft/WinGet/Packages" | grep -i -E "godot|ffmpeg"
```

Write `find_tool` to search, in order: `PATH`, `C:/Program Files/Blender Foundation/*/blender.exe`, `%LOCALAPPDATA%/Microsoft/WinGet/Packages/**/Godot*.exe`, `%LOCALAPPDATA%/Microsoft/WinGet/Packages/**/ffmpeg.exe`.

```python
# studio/lib/config.py
from __future__ import annotations
import os, shutil, subprocess, glob
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCALAPPDATA = Path(os.environ.get("LOCALAPPDATA", ""))
PROGRAM_FILES = Path(os.environ.get("ProgramFiles", "C:/Program Files"))

CANDIDATES = {
    "blender": [
        "blender",
        str(PROGRAM_FILES / "Blender Foundation" / "*" / "blender.exe"),
    ],
    "godot": [
        "godot", "godot4",
        str(LOCALAPPDATA / "Microsoft" / "WinGet" / "Packages" / "**" / "Godot*.exe"),
    ],
    "ffmpeg": [
        "ffmpeg",
        str(LOCALAPPDATA / "Microsoft" / "WinGet" / "Packages" / "**" / "ffmpeg.exe"),
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

def tool_version(name: str, exe: Path) -> str:
    flag = "-version" if name == "ffmpeg" else "--version"
    try:
        out = subprocess.run([str(exe), flag], capture_output=True, text=True, timeout=30)
        return (out.stdout or out.stderr).strip().splitlines()[0]
    except Exception as exc:
        return f"error: {exc}"

def doctor() -> list[dict]:
    rows = []
    for name in CANDIDATES:
        exe = find_tool(name)
        rows.append({
            "name": name,
            "path": str(exe) if exe else "",
            "version": tool_version(name, exe) if exe else "",
            "ok": exe is not None,
        })
    return rows
```

- [ ] **Step 3: Write the failing test**

```python
# studio/tests/test_config.py
from studio.lib import config

def test_root_points_at_repo():
    assert (config.ROOT / "studio").is_dir()

def test_doctor_reports_all_tools():
    rows = config.doctor()
    assert {r["name"] for r in rows} == {"blender", "godot", "ffmpeg"}
    assert all("ok" in r for r in rows)
```

- [ ] **Step 4: Run it**

```bash
python -m pytest studio/tests/test_config.py -v
```

Expected: FAIL first (`studio.lib` not importable) until `studio/__init__.py` and `studio/lib/__init__.py` exist, then PASS.

- [ ] **Step 5: Add the CLI shell**

`studio/studio.py` uses argparse with `doctor`, `validate`, `new`, `render`, `export`, `sheet`, `publish`. Only `doctor` and `validate` are implemented now; others raise `NotImplementedError` until their task lands. `doctor` prints a table and exits 1 if any tool is missing, or 0 with `--soft`.

- [ ] **Step 6: Verify versions**

```bash
python studio/studio.py doctor
```

Expected: Blender 4.5.x, Godot 4.7.2, ffmpeg 9.x, exit 0.

- [ ] **Step 7: Commit**

```bash
git add studio .gitignore
git commit -m "feat: add studio cli skeleton and toolchain doctor"
```

---

### Task 2: Repo skeleton, manifests, and Python environment

**Files:**
- Create: `.gitignore`, `.gitattributes`, `AGENTS.md`, `README.md` (stub), `LICENSE`
- Create: `requirements.txt` (pyyaml, pillow, pytest)
- Create: `studio/lib/manifest.py`, `studio/tests/test_manifest.py`
- Create: `projects/001-2d-bounce/project.yaml`, `projects/002-turntable/project.yaml`, `projects/003-micro-game/project.yaml`
- Create: `assets/shared/.gitkeep`, `media/.gitkeep`, `tools/blender/.gitkeep`

**Interfaces:**
- Produces: `manifest.Project` dataclass with fields `id, type, title, summary, tags, engine, entry, resolution, fps, frames, outputs, root`.
- Produces: `manifest.load(project_dir: Path) -> Project`, `manifest.load_all(root: Path) -> list[Project]`, `manifest.validate(project: Project) -> list[str]`.
- `Project.media_dir` property returns `ROOT / "media" / id`.

- [ ] **Step 1: Write ignore and attribute rules**

```gitignore
.venv/
__pycache__/
*.pyc
.pytest_cache/
node_modules/
showcase/dist/
showcase/public/media/
showcase/public/play/
showcase/public/models/
showcase/src/projects.generated.ts
assets/generated/
projects/**/build/
projects/**/.godot/
projects/**/*.blend1
media/**/_frames/
*.log
```

`.gitattributes` normalizes text to LF and marks media binary:

```gitattributes
* text=auto eol=lf
*.png binary
*.jpg binary
*.gif binary
*.mp4 binary
*.webm binary
*.glb binary
*.blend binary
```

- [ ] **Step 2: Create the Python environment**

```bash
python -m venv .venv
./.venv/Scripts/python -m pip install -U pip
./.venv/Scripts/pip install pyyaml pillow pytest
./.venv/Scripts/python -m pip freeze > requirements.txt
```

- [ ] **Step 3: Write the failing manifest tests**

```python
# studio/tests/test_manifest.py
from pathlib import Path
import pytest
from studio.lib import manifest

def write(tmp_path: Path, body: str) -> Path:
    p = tmp_path / "p"; p.mkdir()
    (p / "project.yaml").write_text(body, encoding="utf-8")
    return p

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

def test_loads_valid_manifest(tmp_path):
    p = manifest.load(write(tmp_path, GOOD))
    assert p.id == "009-demo" and p.fps == 24
    assert manifest.validate(p) == []

def test_rejects_engine_type_mismatch(tmp_path):
    bad = GOOD.replace("engine: python", "engine: blender")
    p = manifest.load(write(tmp_path, bad))
    assert any("engine" in e for e in manifest.validate(p))

def test_rejects_missing_entry(tmp_path):
    p = manifest.load(write(tmp_path, GOOD))
    p.entry = "missing.py"
    assert any("entry" in e for e in manifest.validate(p))
```

- [ ] **Step 4: Run tests, expect failure**

```bash
./.venv/Scripts/python -m pytest studio/tests/test_manifest.py -v
```

Expected: FAIL, `manifest.load` missing.

- [ ] **Step 5: Implement manifests**

`manifest.py` uses PyYAML, checks id pattern `^\d{3}-[a-z0-9-]+$`, maps type to allowed engine (`2d→python`, `3d→blender`, `game→godot`), requires positive resolution/fps/frames, and requires entry to exist in the project directory. `load_all` skips directories starting with `_`.

- [ ] **Step 6: Write the three project manifests**

001: `type: 2d`, `engine: python`, `render: {resolution: [1920,1080], fps: 24, frames: 144}`, outputs MP4, WebM, GIF, poster.
002: `type: 3d`, `engine: blender`, `render: {resolution: [1920,1080], fps: 24, frames: 192}`, outputs MP4, GIF, poster, plus `media/002-turntable/turntable.glb`.
003: `type: game`, `engine: godot`, `entry: project.godot`, `render: {resolution: [960,540], fps: 60, frames: 1}`, outputs `projects/003-micro-game/build/web/index.html`.

- [ ] **Step 7: Run all tests and commit**

```bash
./.venv/Scripts/python -m pytest studio/tests -v
git add .gitignore .gitattributes AGENTS.md README.md LICENSE requirements.txt studio projects assets media tools docs
git commit -m "feat: add repo skeleton, manifests and validation"
```

---

### Task 3: Media pipeline

**Files:**
- Create: `studio/lib/media.py`, `studio/tests/test_media.py`
- Create: `tools/blender/render.py`
- Create: `studio/lib/render.py`, `studio/lib/godot.py`

**Interfaces:**
- Produces: `media.probe(path) -> dict` with `width, height, fps, duration, codec`.
- Produces: `media.assert_spec(path, width, height, fps, max_mb) -> None` raising `ValueError`.
- Produces: `media.encode(frames_dir, out_dir, fps, pattern="frame_%04d.png") -> dict[str, Path]` writing `reel.mp4`, `reel.webm`, `reel.gif`, `poster.jpg`.
- Produces: `render.run(project: Project) -> Path` returning frames directory.
- Produces: `godot.export_web(project_root: Path, out: Path) -> None`.

- [ ] **Step 1: Write failing media tests**

```python
# studio/tests/test_media.py
from pathlib import Path
import pytest
from studio.lib import media

def test_budget_rejects_oversize(tmp_path, monkeypatch):
    f = tmp_path / "a.gif"; f.write_bytes(b"x" * 100)
    monkeypatch.setattr(media, "BUDGET_MB", {".gif": 0.00001})
    with pytest.raises(ValueError, match="budget"):
        media.check_budget(f)

def test_parse_fps():
    assert media.parse_fps("24/1") == 24.0
    assert media.parse_fps("30000/1001") == pytest.approx(29.97, abs=0.01)

def test_budget_allows_small(tmp_path):
    f = tmp_path / "a.mp4"; f.write_bytes(b"x" * 100)
    media.check_budget(f)
```

- [ ] **Step 2: Implement `media.py`**

ffprobe command: `ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate,codec_name -show_entries format=duration -of json <file>`.

Budget map: `.gif: 8`, `.mp4: 20`, `.webm: 20`, `.jpg: 0.5`, `.png: 2`. `check_budget` raises `ValueError(f"{path.name} exceeds {limit} MB budget")`.

`encode` runs, with `check=True`:

```bash
ffmpeg -y -framerate {fps} -i {pattern} -c:v libx264 -preset slow -crf 18 \
  -pix_fmt yuv420p -movflags +faststart reel.mp4
ffmpeg -y -i reel.mp4 -c:v libvpx-vp9 -crf 32 -b:v 0 -row-mt 1 reel.webm
ffmpeg -y -i reel.mp4 -vf "fps=24,scale=960:-1:flags=lanczos,palettegen=max_colors=128" palette.png
ffmpeg -y -i reel.mp4 -i palette.png -lavfi \
  "fps=24,scale=960:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" reel.gif
ffmpeg -y -ss 1 -i reel.mp4 -frames:v 1 -q:v 3 poster.jpg
```

Then call `assert_spec` for mp4 (width, height, fps) and `check_budget` for each output. Delete `palette.png` after.

- [ ] **Step 3: Implement render dispatch**

`render.run(project)` creates `media/<id>/_frames`, removes prior frames, then:

- `2d`: `[sys.executable, entry, "--out", frames, "--frames", str(project.frames), "--width", ..., "--height", ...]`
- `3d`: `[blender, "-b", "--python", entry, "--", "--frames-start", "1", "--frames-end", str(frames), "--out", frames, "--width", ..., "--height", ...]`

Both must exit 0 and produce the expected frame count before encoding.

- [ ] **Step 4: Implement Godot export**

`godot.export_web` runs `[godot, "--headless", "--path", str(root), "--import"]` then `[godot, "--headless", "--path", str(root), "--export-release", "Web", str(out / "index.html")]`, checks both exit 0, and verifies `index.html`, `index.wasm`, `index.pck` exist.

- [ ] **Step 5: Test and commit**

```bash
./.venv/Scripts/python -m pytest studio/tests -v
git add studio tools requirements.txt
git commit -m "feat: add media encoding, validation and render dispatch"
```

---

### Task 4: Project 001, 2D animation

**Files:**
- Create: `projects/001-2d-bounce/render.py`
- Create: `projects/001-2d-bounce/README.md`
- Test: `projects/001-2d-bounce/test_render.py`

**Interfaces:**
- Produces: `render.render_frame(t, width, height) -> PIL.Image.Image` where `t` is normalized 0..1.
- Produces: `render.bounce_y(t) -> float`, `render.squash(t) -> float` (1.0 = neutral, >1 wide, <1 tall).
- Consumes: `--out`, `--frames`, `--width`, `--height` arguments.

- [ ] **Step 1: Write failing motion tests**

```python
def test_bounce_is_periodic():
    assert abs(render.bounce_y(0.0) - render.bounce_y(1.0)) < 1e-6

def test_squash_peaks_at_impact():
    impact = max(range(100), key=lambda i: render.squash(i / 100))
    assert 0.35 < impact / 100 < 0.55  # first impact

def test_frame_size():
    img = render.render_frame(0.5, 320, 180)
    assert img.size == (320, 180) and img.mode == "RGB"
```

- [ ] **Step 2: Implement the renderer**

Draw at 2x and downscale with `Image.LANCZOS`. Scene: warm cream gradient background, ink floor line, soft ellipse shadow that scales inversely with height, a rounded blob character with two eyes and a scarf ribbon, motion arc, dust puffs on impact, and a small type tag `001 / bounce` in the corner using `C:/Windows/Fonts/segoeui.ttf` with a fallback to `ImageFont.load_default()`.

Motion: two bounces per 6-second loop. Use a parabolic arc with easing and a 3-frame anticipation crouch before launch. Compute squash from vertical velocity, clamp to 0.62..1.32, plus a follow-through wobble on the scarf driven by `sin`. Everything derives from `t`, so the loop is seamless.

Palette: bg `#F6F1E7`, ink `#14140F`, coral `#FF5A3C`, lime `#C9F24E`, shadow `rgba(20,20,15,60)`.

- [ ] **Step 3: Render a one-frame smoke test**

```bash
./.venv/Scripts/python projects/001-2d-bounce/render.py --out /tmp/frames001 --frames 1 --width 480 --height 270
```

Expected: one PNG, exit 0.

- [ ] **Step 4: Full render through the CLI**

```bash
./.venv/Scripts/python studio/studio.py render 001-2d-bounce
```

Expected: 144 frames, then `media/001-2d-bounce/reel.mp4|webm|gif|poster.jpg`, all within budget, ffprobe validates.

- [ ] **Step 5: Inspect output**

Run `ffprobe` on the MP4: 1920x1080, 24 fps, 6.0 s, h264. Extract 3 stills and view them to confirm the character reads clearly and the loop has no jump.

- [ ] **Step 6: Commit**

```bash
git add projects/001-2d-bounce media/001-2d-bounce
git commit -m "feat: add project 001 squash and stretch animation"
```

---

### Task 5: Project 002, 3D turntable

**Files:**
- Create: `projects/002-turntable/scene.py`
- Create: `projects/002-turntable/README.md`
- Modify: `tools/blender/render.py` if shared helpers are needed

**Interfaces:**
- Produces: `build_scene(width, height, frames) -> bpy.types.Scene`
- CLI args after `--`: `--out`, `--frames-start`, `--frames-end`, `--width`, `--height`, `--check`, `--export-glb PATH`.
- `--check` builds the scene, prints object/light/camera counts, and exits without rendering.

- [ ] **Step 1: Verify Blender headless**

```bash
"<blender>" -b --python-expr "import bpy; print('BLENDER', bpy.app.version_string)"
```

- [ ] **Step 2: Build the scene**

Robot companion from primitives: beveled capsule torso, sphere head, cylinder arms, floating hands, ring antenna with emissive tip, visor with emission. Joints as spheres. Materials: matte off-white body, ink joints, coral accents, lime emission. Circular pedestal with bevel. Backdrop: large curved plane or seamless world color. Three area lights (key, fill, rim) plus a soft world light.

Animation: robot parented to an empty, 360 degrees linear over the frame range; separate hover bob on Z using a sine; antenna sway; slight head turn. Camera 50 mm at a 3/4 angle, focus on the torso.

Render: try `BLENDER_EEVEE_NEXT` first. If the one-frame test fails or is blank, switch to `CYCLES` with CPU, 32 samples, denoise, transparent glass off. Set `file_format=PNG`, `color_mode=RGB`, `film_transparent=False`.

- [ ] **Step 3: Check build and one frame**

```bash
"<blender>" -b --python projects/002-turntable/scene.py -- --check
"<blender>" -b --python projects/002-turntable/scene.py -- --frames-start 1 --frames-end 1 --out /tmp/f002 --width 960 --height 540
```

Expected: object counts printed, one PNG that is not blank. View it.

- [ ] **Step 4: Full render**

```bash
./.venv/Scripts/python studio/studio.py render 002-turntable
```

Run in the background; expect 10 to 40 minutes depending on engine. Validate with ffprobe: 1920x1080, 24 fps, 8.0 s.

- [ ] **Step 5: Export the GLB for the site**

```bash
"<blender>" -b --python projects/002-turntable/scene.py -- --export-glb media/002-turntable/turntable.glb
```

Expected: GLB < 5 MB, loads in the Three.js viewer.

- [ ] **Step 6: Commit**

```bash
git add projects/002-turntable media/002-turntable
git commit -m "feat: add project 002 robot turntable and glb"
```

---

### Task 6: Project 003, playable game

**Files:**
- Create: `projects/003-micro-game/project.godot`
- Create: `projects/003-micro-game/main.tscn`
- Create: `projects/003-micro-game/main.gd`
- Create: `projects/003-micro-game/export_presets.cfg`
- Create: `projects/003-micro-game/audio/make_sfx.py` (generates `collect.wav`, `hit.wav`)
- Create: `projects/003-micro-game/tests/smoke.gd`

**Interfaces:**
- Game: `Orbit Run`, 960x540, gl_compatibility renderer, thread support off.
- Produces: `projects/003-micro-game/build/web/index.html|wasm|pck`.

- [ ] **Step 1: Install export templates**

Download `Godot_v4.7.2-stable_export_templates.tpz` from the Godot 4.7.2 GitHub release, extract, and place the version folder at `%APPDATA%/Godot/export_templates/4.7.2.stable/`. Verify a `web_nothreads_release.zip` (or `web_release.zip` when threads off) exists.

- [ ] **Step 2: Write the game**

Single `main.gd` on a Node2D. Systems:

- State: `MENU`, `PLAY`, `OVER`; 3 lives; score; best score in `user://best.cfg`.
- Player: x position with acceleration and clamping; ship drawn as a triangle with a glow trail; keyboard arrows/A-D, mouse/touch drag.
- Spawner: stars (`+10`) and rocks (lose a life); interval shrinks from 0.9 s to 0.35 s; fall speed ramps.
- Collision: circle distance checks.
- Particles: arrays of position/velocity/life for collect sparks and hit debris, drawn each frame.
- Background: vertical gradient bands, parallax star field, drift.
- HUD: score, lives, best; titles and restart prompt drawn with `draw_string` using `ThemeDB.fallback_font`.
- Restart: Space, Enter, click or tap.

`project.godot` pins `config/features=PackedStringArray("4.7", "GL Compatibility")`, `rendering/renderer/rendering_method="gl_compatibility"`, display size 960x540, stretch `canvas_items`, and the main scene.

- [ ] **Step 3: Generate and import audio**

```bash
./.venv/Scripts/python projects/003-micro-game/audio/make_sfx.py
"<godot>" --headless --path projects/003-micro-game --import
```

Expected: `.godot/imported/` contains both WAV imports, exit 0.

- [ ] **Step 4: Headless smoke test**

`tests/smoke.gd` extends SceneTree: load `main.tscn`, instantiate, add to root, process a few frames, assert children exist, print `SMOKE OK`, quit. Run:

```bash
"<godot>" --headless --path projects/003-micro-game --script tests/smoke.gd
```

Expected: `SMOKE OK`, exit 0.

- [ ] **Step 5: Web export**

```bash
./.venv/Scripts/python studio/studio.py export 003-micro-game
```

Expected: three build files. Serve locally with `python -m http.server` from the build folder and play in a browser: move, collect, lose a life, game over, restart.

- [ ] **Step 6: Commit**

```bash
git add projects/003-micro-game
git commit -m "feat: add project 003 playable orbit run game"
```

---

### Task 7: Showcase site

**Files:**
- Create: `showcase/package.json`, `showcase/index.html`, `showcase/vite.config.ts`, `showcase/tsconfig.json`
- Create: `showcase/src/main.ts`, `showcase/src/styles.css`, `showcase/src/viewer.ts`
- Create: `studio/lib/publish.py`
- Create: `showcase/public/favicon.svg`

**Interfaces:**
- Produces: `publish.run() -> Path` writing `showcase/src/projects.generated.ts` and copying media to `showcase/public/media/<id>/`, GLB to `showcase/public/models/`, web build to `showcase/public/play/003-micro-game/`.
- Consumes: manifests and `media/`.

- [ ] **Step 1: Scaffold Vite**

```bash
pnpm create vite@latest showcase --template vanilla-ts
cd showcase && pnpm add three && pnpm add -D @types/three
```

Remove the demo files. Keep `index.html`, `src/main.ts`, `src/style.css`.

- [ ] **Step 2: Implement publish**

For each valid manifest with existing outputs, emit:

```ts
export type Project = {
  id: string; type: "2d" | "3d" | "game"; title: string; summary: string;
  tags: string[]; poster: string; mp4?: string; webm?: string; gif?: string;
  model?: string; play?: string; duration: string;
};
export const projects: Project[] = [...];
```

Copy only outputs listed in the manifest. Fail loudly if a declared output is missing.

- [ ] **Step 3: Build the page**

Light cream background, ink type, electric lime accent, generous whitespace. Sections:

1. Hero: studio name, one-line promise, glowing "Play the game" CTA, live Three.js robot viewer as the centerpiece.
2. Work: filter chips `All / 2D / 3D / Game`, cards with poster or looping video, type chip, duration, hover state.
3. Project detail blocks: reel video with controls, GIF fallback, "Made with" line, project 003 iframe embed at 16:9 with a play overlay.
4. Studio: toolchain table, reproduce commands, GitHub link.
5. Footer: license note.

No em dashes. Use system font stack plus `ui-monospace` for labels. Respect `prefers-reduced-motion` (pause autoplay videos, stop viewer rotation).

- [ ] **Step 4: Three.js viewer**

Load `/models/turntable.glb` with GLTFLoader, RoomEnvironment for reflections, ACES tone mapping, soft contact shadow, lime rim light, orbit controls with auto-rotate, clamped zoom. If the model fails to load, show a styled fallback panel, not an error.

- [ ] **Step 5: Build and preview**

```bash
./.venv/Scripts/python studio/studio.py publish
cd showcase && pnpm build && pnpm preview
```

Open the preview in a browser: hero viewer renders, cards show posters, video plays, iframe game boots.

- [ ] **Step 6: Commit**

```bash
git add showcase studio/lib/publish.py
git commit -m "feat: add showcase site with gallery and 3d viewer"
```

---

### Task 8: CI, Pages, and the public repo

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/workflows/deploy.yml`
- Create: `README.md` (full), `AGENTS.md` (full), `LICENSE`
- Create: `.nojekyll` in build output

**Interfaces:**
- `deploy.yml` publishes `showcase/dist` to Pages on push to `main`.

- [ ] **Step 1: Write CI**

```yaml
name: ci
on:
  push: { branches: [main] }
  pull_request:
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.13" }
      - run: pip install pyyaml pillow pytest
      - run: python -m pytest studio/tests -v
      - uses: pnpm/action-setup@v4
        with: { version: 10 }
      - uses: actions/setup-node@v4
        with: { node-version: 24, cache: pnpm, cache-dependency-path: showcase/pnpm-lock.yaml }
      - run: pnpm install --frozen-lockfile
        working-directory: showcase
      - run: pnpm build
        working-directory: showcase
```

- [ ] **Step 2: Write deploy**

```yaml
name: deploy
on:
  push: { branches: [main] }
  workflow_dispatch:
permissions:
  contents: read
  pages: write
  id-token: write
concurrency: { group: pages, cancel-in-progress: true }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 10 }
      - uses: actions/setup-node@v4
        with: { node-version: 24, cache: pnpm, cache-dependency-path: showcase/pnpm-lock.yaml }
      - run: pnpm install --frozen-lockfile
        working-directory: showcase
      - run: pnpm build
        working-directory: showcase
      - uses: actions/configure-pages@v5
      - uses: actions/upload-pages-artifact@v3
        with: { path: showcase/dist }
  deploy:
    needs: build
    environment: { name: github-pages, url: "${{ steps.deployment.outputs.page_url }}" }
    runs-on: ubuntu-latest
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

Set `base: "/animation-and-game-studio/"` in `vite.config.ts` for production.

- [ ] **Step 3: Create the repo and push**

```bash
gh repo create konethegreat/animation-and-game-studio --public \
  --description "2D and 3D animation plus playable games, built in the open." \
  --source . --remote origin --push
```

- [ ] **Step 4: Enable Pages via Actions**

```bash
gh api -X POST repos/konethegreat/animation-and-game-studio/pages \
  -H "Accept: application/vnd.github+json" -f build_type=workflow
```

Then push an empty commit or use `gh workflow run deploy.yml`.

- [ ] **Step 5: Watch the deploy**

```bash
gh run watch
gh api repos/konethegreat/animation-and-game-studio/pages
```

Expected: workflow success, site URL `https://konethegreat.github.io/animation-and-game-studio/`.

- [ ] **Step 6: Commit**

```bash
git add .github README.md AGENTS.md LICENSE showcase/vite.config.ts
git commit -m "chore: add ci, pages deploy and project documentation"
git push
```

---

### Task 9: Full verification

**Files:**
- Modify: `README.md` with final media and live links.

- [ ] **Step 1: Local checks**

```bash
./.venv/Scripts/python studio/studio.py doctor
./.venv/Scripts/python -m pytest studio/tests -v
ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -show_entries format=duration media/001-2d-bounce/reel.mp4
ffprobe -v error -show_entries stream=width,height,r_frame_rate,codec_name -show_entries format=duration media/002-turntable/reel.mp4
```

- [ ] **Step 2: Browser checks on the deployed site**

Using Chrome DevTools MCP, open the Pages URL and confirm:

1. Hero viewer loads the GLB and rotates.
2. Reels play inline on desktop; GIF fallback visible.
3. `Play` CTA scrolls to the iframe; the game boots, keyboard moves the ship, score increases, a hit removes a life, game over shows, restart works.
4. Mobile viewport 390x844: no horizontal scroll, cards stack, game iframe fits.
5. Console has no errors; all links resolve.

- [ ] **Step 3: Fix anything found, rerun checks, commit**

```bash
git add -A
git commit -m "fix: resolve issues found in live verification"
git push
```

- [ ] **Step 4: Report**

Summarize: live URL, repo URL, what each project is, how to reproduce each render, remaining limits (no hand-drawn animation, 1080p ceiling), and the next project options.

---

## Self-Review

- **Spec coverage:** toolchain (Task 1), repo and manifests (Task 2), media/validation (Task 3), 2D (Task 4), 3D (Task 5), game + web export (Task 6), showcase (Task 7), CI and Pages (Task 8), verification (Task 9). Non-goals and risks are honored: no LFS, no paid tools, 1080p, budgets, light mode, no em dashes.
- **Placeholders:** none. Commands, file paths, schemas and signatures are explicit. Large creative files are specified by behavior and palette rather than line-by-line copy.
- **Consistency:** `media.encode` names (`reel.mp4`, `reel.webm`, `reel.gif`, `poster.jpg`) match manifests, publish and README references. `godot.export_web` output (`build/web/index.html`) matches manifest 003 and publish's play path.
