# Animation and Game Studio

2D and 3D animation plus playable games, built in the open.

Live showcase: https://konethegreat.github.io/animation-and-game-studio/

## Work

| Project | Type | What it is |
| --- | --- | --- |
| 001 Bounce | 2D | Squash and stretch study rendered with Python and Pillow |
| 002 Turntable | 3D | Robot companion turntable modelled and lit in Blender |
| 003 Orbit Run | Game | One-screen arcade game made with Godot, playable in the browser |

## How it works

Everything is authored as code, rendered headless and validated before it ships.

- A `project.yaml` manifest is the single source of truth for each piece.
- `studio/studio.py` renders 2D frames with Pillow, 3D frames in Blender and game builds in Godot.
- FFmpeg encodes MP4, WebM and GIF, and ffprobe enforces the media budget.
- `studio publish` copies curated media into `showcase/public` and regenerates the gallery data.
- Vite and Three.js build the showcase, GitHub Actions deploys it to Pages.

## Toolchain

| Tool | Version | Used for |
| --- | --- | --- |
| Python | 3.13+ | Studio CLI, Pillow rendering, tests |
| Blender | 4.5 LTS | 3D scenes, animation and GLB export |
| Godot | 4.7.2 standard | Playable games and web export |
| FFmpeg | 9 | Encoding, probing and contact sheets |
| Node | 24+ with pnpm 11 | Showcase build |

## Quick start

```bash
python -m venv .venv
./.venv/Scripts/pip install -r requirements.txt
./.venv/Scripts/python studio/studio.py doctor
cd showcase && pnpm install && cd ..
```

`studio doctor` prints the path and version of Blender, Godot and FFmpeg, and fails if one is missing. Use `doctor --soft` in environments without the desktop tools.

## Commands

```bash
./.venv/Scripts/python studio/studio.py validate
./.venv/Scripts/python studio/studio.py new 2d 004-my-study --title "My Study"
./.venv/Scripts/python studio/studio.py render 001-2d-bounce
./.venv/Scripts/python studio/studio.py render 002-turntable
./.venv/Scripts/python studio/studio.py export 002-turntable
./.venv/Scripts/python studio/studio.py export 003-micro-game
./.venv/Scripts/python studio/studio.py sheet media/001-2d-bounce/reel.mp4 media/001-2d-bounce/sheet.jpg
./.venv/Scripts/python studio/studio.py publish
cd showcase && pnpm dev
```

| Command | Result |
| --- | --- |
| `validate` | Checks every manifest, engine pairing, entry file and resolution ceiling |
| `new` | Copies a starter template into `projects/` and fills in the id and title |
| `render` | Writes frames to an ignored folder, then encodes `reel.mp4`, `reel.webm`, `reel.gif` and `poster.jpg` |
| `export` | Writes a GLB for Blender projects or a web build for Godot projects |
| `sheet` | Builds a contact sheet from a rendered video |
| `publish` | Copies media, model and game build into the showcase and writes `projects.generated.ts` |

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
