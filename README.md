# Animation and Game Studio

2D and 3D animation plus playable games, built in public by one maker.

Live showcase: https://konethegreat.github.io/animation-and-game-studio/

## Ownership

Original studio work is by Kone Tshivhinda at Kone Studio. The original code, films, models, game art, audio and text are proprietary and all rights are reserved. You are welcome to view the source and play the published work. Copying, redistribution, commercial use, derivative works and AI training of that original work are not permitted without written permission. See [LICENSE](LICENSE).

Third party assets, tools, libraries and fonts keep their own licences. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the [creator beta asset notice](assets/repo/creator-beta-NOTICE.txt). The creator uses Meta's MHR base under Apache-2.0, not an originally authored studio base mesh.

## Film

**The Maker at Work** is a short film built from the maker's own photograph and voice, rendered on this laptop with no paid services. The pilot runs 25 seconds across three shots: a night desk that pushes into a framed portrait, the portrait itself moving on a depth map, and the return to the desk with the lantern and the title. The portrait is never redrawn by a model. The face is the real photograph.

- Watch it: https://konethegreat.github.io/animation-and-game-studio/project/010-maker-at-work
- How it was made: [docs/making-the-maker.md](docs/making-the-maker.md)

## Work

| Project | Type | What it is |
| --- | --- | --- |
| 001 Bounce | 2D | Squash and stretch study rendered with Python and Pillow |
| 002 Turntable | 3D | Robot companion turntable modelled and lit in Blender |
| 003 Orbit Run | Game | One-screen arcade game made with Godot, playable in the browser |
| 004 Lantern Keeper | 3D | Character walk loop with a spline camera move, exported as GLB |
| 010 The Maker at Work | Film | Photographic portrait film with an original score and a consented voice |

## How it works

Everything is authored as code, rendered headless and validated before it ships.

- A `project.yaml` manifest is the single source of truth for each piece.
- `studio/studio.py` dispatches to rendering adapters for Pillow, Blender, Godot and Unity. LÖVE, MonoGame, GDevelop and Unreal are registered and probed until their artifacts land.
- Films render shot by shot with resumable state. FFmpeg concatenates the shots, muxes declared audio and normalises loudness.
- ffprobe, frame scans, GLB inspection and build size checks run before a render is accepted.
- `studio publish` copies curated media into `showcase/public`, regenerates the gallery data and writes third party notices.
- Vite and Three.js build the showcase, GitHub Actions deploys it to Pages.

## Character creator beta

The showcase includes `creator-probe.html`, linked as Creator beta. Mouth and expressions are unfinished, and Portrait B is a sculpt study rather than an approved likeness. Desktop is recommended; the initial download is roughly 40 MB, with additional hairstyles downloaded on demand.

Before running `pnpm --dir showcase dev --port 5200 --strictPort` or building the site, run `python -m studio.lib.creator_assets restore`. This restores the versioned release archive pinned by `assets/creator-beta.json` into ignored `showcase/public/models/probe/`. Archive and individual file hashes are checked before any asset is written. The local creator opens at `http://localhost:5200/animation-and-game-studio/creator-probe.html`. For offline builds, pass `--archive` with the downloaded ZIP path.

The beta package includes the MHR Apache-2.0 licence and a separate modification notice. No VALID reference-avatar morphs or hair followers are shipped: source-avatar redistribution rights were not established. The builder includes reference heads only when `--heads` is explicitly supplied for local research; the release packager rejects those outputs. AI reference portraits and private owner assets are not part of the creator package.

Skin scattering uses shadow-attenuated incident light, not emission. Eye-white brightness uses sRGB like the eye-colour swatches. Run `node showcase/scripts/check-creator-materials.mjs` with the dev server active to check unlit skin, scattering response and eye-white colour mapping in Chrome. This manual browser check requires an installed Playwright module; set `PLAYWRIGHT_MODULE` to its module specifier or absolute file URL if `playwright` is not resolvable. Set `CREATOR_URL` to check a built or deployed page. `check-creator-beta.mjs` checks desktop and phone-width navigation, controls, licences and the Bin City shell; `check-creator-errors.mjs` checks invalid imports and failed hair downloads. These scripts use the same Playwright module setting.

The Portrait B starting look is a local sculpt study based on the owner's selected AI portrait, not an approved likeness or an automatically reconstructed head. Its blend control changes facial proportions and lip contours without replacing the other presets. `studio/tools/character/check_face_shapes.py` runs inside Blender with `--source` pointing to the MHR FBX and `--out` to a local preview directory; it checks head-only deformation, mouth-seam stability, eye apertures, smoothness and attachment following. The reference is frontal only, so its profile remains unknown. Morph normals are exported so lighting follows the sculpt; scalp displacement is fitted to the affine transform shared by strands and their cap. Rebuild the GLB and all hair followers after changing the sculpt.

To rebuild beta assets, run Blender with `--python-exit-code 1` so script failures fail the command. Do not pass `--heads` or reuse research output directories:

```bash
blender --background --python-exit-code 1 --python studio/tools/character/build_probe.py -- --source /path/to/MHR/lod1.fbx --out assets/embed/mhr/beta/probe.glb --bake --bake-ao
python -m studio.lib.creator_assets package assets/embed/mhr/beta assets/embed/creator-beta-01.zip --url https://github.com/konethegreat/animation-and-game-studio/releases/download/creator-beta-01/creator-beta-01.zip --manifest assets/creator-beta.json
python -m studio.lib.creator_assets restore --archive assets/embed/creator-beta-01.zip
pnpm --dir showcase typecheck
pnpm --dir showcase build
node showcase/scripts/check-creator-build.mjs
python -m studio.lib.creator_assets verify showcase/dist/models/probe
```

Future asset revisions need a new release tag and archive name, not an overwrite of the pinned beta archive. The packager includes only runtime files plus licence notices, never reference portraits, FBX sources, intermediate textures or raw previews. Both CI and Pages restore and verify the same package before building.

## Engine matrix

Measured on this machine. `docs/engines.md` has paths, probe output and blockers.

| Engine | Version | Status | Output |
| --- | --- | --- | --- |
| Python and Pillow | 3.15 | Working | 2D frame sequences |
| Blender | 4.5 LTS | Working | Cycles renders, GLB |
| Godot | 4.7.2 | Working | Playable web build |
| LÖVE | 11.5 | Probed, artifact next | Lua game, captured frames |
| MonoGame | 3.8 on .NET 10 | Probed, artifact next | C# game templates |
| GDevelop | 5.6 | Installed, export unproven | Event driven web game |
| Unity | 6.3 LTS | Licensed, editor runs headless | WebGL build |
| Unreal | 5.8 | Not installed | Capability report |

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
./.venv/Scripts/python studio/studio.py teaser
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
| `teaser` | Cuts the short silent loop a work card plays, under 2 MB at 432p; `render` also writes it |
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

- GIF under 8 MB, MP4 and WebM under 20 MB, card teaser under 2 MB, poster under 500 KB, GLB under 5 MB.
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

## Licence

Proprietary. All rights reserved by Kone Tshivhinda. See `LICENSE`. Third party components keep their own licences in `THIRD_PARTY_NOTICES.md`.
