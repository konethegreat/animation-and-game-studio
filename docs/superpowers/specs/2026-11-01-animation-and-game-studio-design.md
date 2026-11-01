# Animation and Game Studio: Design

Date: 2026-11-01
Status: approved
Repo: `konethegreat/animation-and-game-studio` (public)
Local root: `C:\Users\Konet\My animation and game studio`

## Goal

One reproducible workspace where an agent authors, renders, exports and publishes 2D animation, 3D animation and playable games. A public GitHub Pages showcase plays the games and shows the reels. The repo itself is the portfolio piece.

## Non-goals

- Hand-drawn character acting, photorealistic rendering, console or mobile store publishing.
- Multiplayer, live services, paid asset stores.
- Multi-repo architecture, Git LFS, or paid software.

## People

- **Owner** directs, reviews and plays. Can open the GUI apps to explore.
- **Agent** writes scripts and scenes, runs headless renders and exports, publishes.
- **Public** sees a gallery, playable builds and readable source.

## Toolchain

All free and open source. Installed with winget where available.

| Tool | Version | Role |
| --- | --- | --- |
| Blender LTS | 4.5.x | 3D modeling, rigging, animation, headless render |
| Godot | 4.7.2 standard | 2D and 3D game runtime, 2D animation, web export |
| FFmpeg | 9.x | Encode MP4, WebM, GIF, posters, contact sheets |
| Python | 3.15 venv | Studio CLI, procedural assets, validation |
| Node + pnpm | 24 | Showcase site, Three.js demo |
| gh + GitHub Actions | installed | Repo, CI, Pages deploy |

Blender 4.5 LTS is chosen over 5.2 for a stable Python API. Godot standard build, not Mono, because GDScript is fully scriptable and the runtime is smaller.

## Architecture

```
scene code / assets
        |
        v
Blender (3D)   Godot (2D + games)   Python/Pillow (2D art)
        |                |                    |
        +--------- studio/studio.py ---------+
                         |
                    FFmpeg encode
                         |
             media/ + showcase data
                         |
                  Vite static site
                         |
               GitHub Actions -> Pages
```

The pipeline is a single Python CLI. Every project is reproducible from its manifest and source alone. Raw frames and caches never enter git.

## Repo layout

```
animation-and-game-studio/
├─ README.md                gallery front page
├─ AGENTS.md                studio conventions for future sessions
├─ studio/
│  ├─ studio.py             CLI entry point
│  ├─ lib/                  manifest, blender, godot, media, publish
│  └─ templates/            project and script templates
├─ projects/
│  ├─ 001-2d-bounce/        2D animation
│  ├─ 002-turntable/        3D animation
│  └─ 003-micro-game/       playable Godot game
├─ assets/
│  ├─ shared/               fonts, palettes, textures, sfx
│  └─ generated/            ignored, reproducible outputs
├─ tools/blender/           reusable camera rig, lighting, render helpers
├─ media/                   curated committed output only
├─ showcase/                Vite + TypeScript site
├─ docs/                    specs and how-tos
└─ .github/workflows/       CI and Pages deploy
```

## Project manifest

Each project has `project.yaml`:

```yaml
id: 002-turntable
type: 3d            # 2d | 3d | game
title: Turntable
summary: One sentence for the gallery.
tags: [3d, blender, character]
engine: blender     # blender | godot | python
entry: scene.py     # script or Godot project file
render:
  resolution: [1920, 1080]
  fps: 24
  frames: 240
outputs:
  - media/002-turntable/turntable.mp4
  - media/002-turntable/turntable.gif
  - media/002-turntable/poster.jpg
```

## CLI contract

```
studio doctor                 verify tools, versions, ffmpeg codecs
studio new <type> <name>      scaffold a project from template
studio render <id>            headless render + encode + media budget check
studio export <id>            GLB for 3D, web build for games
studio sheet <file>           contact sheet or sprite sheet
studio publish                regenerate showcase project data
```

Exit code 0 means validated output. Non-zero prints the failing check. `render` refuses to finish if ffprobe reports the wrong duration, resolution or codec, or if a file exceeds the media budget.

## Media policy

| Kind | Limit | Notes |
| --- | --- | --- |
| GIF | 8 MB | gallery loops |
| MP4 / WebM | 20 MB | 1080p, h264 or vp9 |
| Poster | 500 KB | JPEG or WebP |
| Full reel | any | GitHub Releases attachment, not git |

Raw frames, Blender caches and Godot import caches are ignored. No Git LFS.

## Showcase

- `/` gallery grid with type filters (2D, 3D, Game), poster hover preview, links.
- `/project/<id>` summary, stills, video, "made with" notes, source link.
- `/play/<id>` embedded Godot web build.
- `/demo/three` interactive Three.js scene for instant 3D on load.
- README mirrors the gallery: posters, GIFs, play links, toolchain notes.
- URL: `https://konethegreat.github.io/animation-and-game-studio/`

Visual direction: light background, restrained layout, one distinctive hero. No em dashes in copy.

## Web export constraint

Godot 4 web builds normally need cross-origin isolation headers for shared memory. GitHub Pages cannot set response headers. The build will disable thread support first and be tested in a real browser. If that fails, load `coi-serviceworker` inside the exported build, or host the game bundle on Cloudflare Pages with headers and iframe it into the showcase. The first option is preferred because it keeps everything on Pages.

## CI

- `ci.yml` on pull request and push: install Node, build showcase, run `studio doctor`, lint manifests.
- `deploy.yml` on push to `main`: build showcase, publish to GitHub Pages via Actions.
- Render CI is manual and local only, because headless Blender and Godot rendering is slow and heavy for hosted runners. CI validates the site, not the renders.

## Milestones

1. **M1 Toolchain**: Blender, Godot, FFmpeg installed, `studio doctor` green.
2. **M2 Scaffold plus 001**: repo structure, CLI, 2D animation rendered to MP4 and GIF.
3. **M3 002**: 3D turntable rendered at 1080p.
4. **M4 003**: playable game exported to web.
5. **M5 Showcase plus deploy**: site live on Pages, verified in browser.

## Verification

- `studio doctor` exits 0 and lists exact versions.
- ffprobe asserts duration, resolution, fps, codec for every encoded file.
- Blender and Godot commands are checked by exit code, not log scraping.
- Godot web export is opened in a real browser and played: movement, score, restart.
- Deployed Pages URL is opened in a real browser; gallery, video playback, game embed and mobile layout checked.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| 11.4 GB RAM | 1080p renders, low sample counts, light scenes, close other apps for finals |
| 4 GB VRAM | Cycles GPU with denoise, fall back to CPU; EEVEE for previews |
| Godot web needs COOP/COEP | Threads off first, coi-serviceworker fallback |
| Git growth from binaries | Media budget in CLI, raw output ignored, releases for long reels |
| Version drift breaks API scripts | Pin LTS Blender, pin engine version in `doctor` |
| Agent art quality ceiling | Stylized and procedural by design, honest copy, iterate from feedback |

## Open decisions

- Optional GUI tools (Krita, Inkscape, Audacity, Libresprite) are added only when a task needs them.
- Portfolio link to the studio is added after the studio is live and reviewed.
