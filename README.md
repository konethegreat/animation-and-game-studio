# Animation and Game Studio

2D and 3D animation plus playable games, built in the open.

Live showcase: https://konethegreat.github.io/animation-and-game-studio/

## Work

| Project | Type | What it is |
| --- | --- | --- |
| 001 Bounce | 2D | Squash and stretch study rendered with Python and Pillow |
| 002 Turntable | 3D | Robot companion turntable modelled and lit in Blender |
| 003 Orbit Run | Game | One-screen arcade game made with Godot, playable in the browser |
| 004 Lantern Keeper | 3D | Character walk loop with a spline camera move, exported as GLB |

## How it works

Everything is authored as code, rendered headless and validated before it ships.

- A `project.yaml` manifest is the single source of truth for each piece.
- `studio/studio.py` dispatches to engine adapters: Pillow, Blender, Godot, Unity, Unreal, GDevelop, LÖVE and MonoGame.
- Films render shot by shot with resumable state. FFmpeg concatenates the shots, muxes declared audio and normalises loudness.
- ffprobe, frame scans, GLB inspection and build size checks run before a render is accepted.
- `studio publish` copies curated media into `showcase/public`, regenerates the gallery data and writes third party notices.
- Vite and Three.js build the showcase, GitHub Actions deploys it to Pages.

## Toolchain

| Tool | Version | Used for |
| --- | --- | --- |
| Python | 3.15 | Studio CLI, Pillow rendering, tests |
| Blender | 4.5 LTS | 3D scenes, animation and GLB export |
| Godot | 4.7.2 standard | Playable games and web export |
| Unity | 6.3 LTS | 3D and game scenes |
| GDevelop | 5.6 | Event driven web games |
| LÖVE | 11.5 | Lua games |
| .NET and MonoGame | 10 and 3.8 | C# games |
| Unreal | 5.8 | High fidelity scenes, blocked until sign in |
| FFmpeg | 9 | Encoding, probing, loudness and contact sheets |
| Node | 24+ with pnpm 11 | Showcase build |

`docs/engines.md` records what each engine can do on this machine and what blocks it. `studio doctor --deep` measures the same matrix live.

## Quick start

```bash
python -m venv .venv
./.venv/Scripts/pip install -r requirements.txt
./.venv/Scripts/python studio/studio.py doctor --deep
cd showcase && pnpm install && cd ..
```

`studio doctor --deep` prints the path and version of every tool and adapter, and fails if a required tool is missing. Use `doctor --deep --soft` in environments without the desktop tools.

## Commands

```bash
./.venv/Scripts/python studio/studio.py validate
./.venv/Scripts/python studio/studio.py new 2d 004-my-study --title "My Study"
./.venv/Scripts/python studio/studio.py render 001-2d-bounce
./.venv/Scripts/python studio/studio.py render 002-turntable
./.venv/Scripts/python studio/studio.py render 004-lantern-keeper --shot main
./.venv/Scripts/python studio/studio.py render 010-maker-at-work --preview
./.venv/Scripts/python studio/studio.py build 003-micro-game
./.venv/Scripts/python studio/studio.py export 004-lantern-keeper
./.venv/Scripts/python studio/studio.py verify 004-lantern-keeper
./.venv/Scripts/python studio/studio.py assets verify --offline
./.venv/Scripts/python studio/studio.py sheet media/001-2d-bounce/reel.mp4 media/001-2d-bounce/sheet.jpg
./.venv/Scripts/python studio/studio.py publish
cd showcase && pnpm dev
```

| Command | Result |
| --- | --- |
| `doctor` | Checks every tool and, with `--deep`, every engine adapter |
| `validate` | Checks every manifest, engine kind, entry file, shot total and resolution ceiling |
| `new` | Copies a starter template into `projects/` and fills in the id and title |
| `render` | Renders shots with resume, encodes declared outputs and verifies them |
| `build` | Builds a playable web game through its engine adapter |
| `export` | Writes a GLB for Blender projects or a web build for game projects |
| `verify` | Checks frames, media, audio, glTF and build size |
| `assets` | Fetches, verifies or credits catalogued assets |
| `sheet` | Builds a contact sheet from a rendered video |
| `publish` | Copies media, models and builds into the showcase and writes the data and notices |

## Add a project

```bash
./.venv/Scripts/python studio/studio.py new 2d 004-my-study --title "My Study"
./.venv/Scripts/python studio/studio.py render 004-my-study
./.venv/Scripts/python studio/studio.py sheet media/004-my-study/reel.mp4 media/004-my-study/sheet.jpg
./.venv/Scripts/python studio/studio.py publish
```

Templates live in `studio/templates/{2d,3d,game}` and are tested by the suite. A project is published only after it has a poster at `media/<id>/poster.jpg`.

## Media rules

- GIF under 8 MB, MP4 and WebM under 20 MB, poster under 500 KB, GLB under 5 MB.
- 1080p maximum render resolution.
- Curated output only. Raw frames, caches, `node_modules` and build output stay out of git.
- Long reels belong in GitHub Releases, never in git.

## Automation

- `ci.yml` runs the Python tests, manifest validation, the showcase typecheck and the site build on every push and pull request.
- `deploy.yml` rebuilds the showcase on `main` and publishes `showcase/dist` to GitHub Pages.

## Limits

- No hand-drawn frame by frame workflow. 2D is scripted with Pillow.
- 1080p ceiling on this machine, with a 4 GB VRAM budget.
- No Git LFS. Media stays under the budgets above or moves to Releases.

## License

Code is MIT. Animation, models, game art and video are CC BY 4.0. See `LICENSE`.
