# Studio Expansion and The Maker at Work: Design

Date: 2026-11-01
Status: awaiting owner review
Repo: `konethegreat/animation-and-game-studio` (public)
Local root: `C:\Users\Konet\My animation and game studio`
Extends: `docs/superpowers/specs/2026-11-01-animation-and-game-studio-design.md`

The original design still describes the repo, the showcase and the media policy. This document changes the manifest, the CLI and the engine layer, and adds a film. It supersedes the original non-goal on photorealistic rendering only to the extent of cinematic realism. Photoreal likeness remains a non-goal.

## Goal

Turn the studio from a three engine pipeline into one Studio OS that drives Blender, Godot, Unity, Unreal, GDevelop, LÖVE and MonoGame, alongside the existing Python 2D path, from the same manifest and the same CLI. Raise the output to cinematic quality on local hardware only. Build and publish a short film about the owner, using the public portrait and a cloned voice, as the proof that the whole system works.

## Non-goals

- Photoreal single photo 3D reconstruction. It is still unsolved and the hardware cannot fake it at film length.
- Paid software, paid asset stores, cloud rendering, paid APIs. Every stage runs on this machine.
- Console, mobile store or Steam publishing.
- Multiplayer or live services.
- Redistributing third party assets. We use them, we credit them, we do not republish them as assets.

## People and consent

- **Owner** directs, reviews, listens and plays. Owner supplied the public portrait and the voice reference, and consented to publishing the finished film with the cloned voice.
- **Agent** writes scenes, adapters, verification and publish steps, runs local renders and reports measured results.
- **Public** sees the gallery, the film, engine artifacts, credits and source.

Consent rules:

- The portrait used is already public on the portfolio. No private photo is added.
- The voice reference and any speaker embeddings stay in gitignored `assets/private/`. Model weights, reference audio and raw stems are never committed and never published.
- Only the finished mixed film is published, with a site note that the voice is a synthetic clone of the owner, made with consent.
- No CV detail beyond what is already public appears in the repo or the film.

## Measured hardware reality

| Resource | Value | Consequence |
| --- | --- | --- |
| CPU | 12 logical cores | Cycles CPU fallback; FFmpeg and encodes are cheap |
| RAM | 11.4 GB | No Unreal editor comfort; one heavy app at a time; render overnight |
| GPU | RTX 3050 Laptop, 4 GB VRAM | Cycles OptiX works on light scenes; Unity real-time is fine; Unreal is experimental |
| Disk | 256 GB free | Engines plus sample libraries fit if we prune installers and caches |
| OS | Windows 11, Git Bash | Long path care for Unity and Unreal; local scripts use `.venv/Scripts/python` |

Unreal 5.8 lists 32 GB RAM and 8 GB VRAM as practical minimums. It gets a probe, not a promise. Everything else is expected to run. Cost is zero in money: downloads, disk, electricity and time only.

## Studio OS architecture

```
project.yaml (kind, engine, shots, assets, outputs)
                    |
          studio/lib/engines registry
                    |
   +--------+--------+--------+--------+--------+--------+--------+
   Blender  Godot   Unity    Unreal  GDevelop  LÖVE  MonoGame  Python
   +--------+--------+--------+--------+--------+--------+--------+
                    |
        render / build / export contract
                    |
        frames -> shot encodes -> final mix
                    |
        verify -> assets -> credits -> publish
```

One manifest, one CLI, one verification gate. The engine is a detail inside the project, not a branch in the CLI.

### Adapter contract

Each adapter implements the same small interface in `studio/lib/engines/`:

```python
class EngineAdapter(Protocol):
    name: str                      # blender, godot, unity, unreal, gdevelop, love, monogame, python
    kinds: set[str]                # film, game
    tool: str                      # key in the tool registry

    def probe(self) -> Probe:      # version, path, device, capabilities, blockers
    def prepare(self, p: Project) -> None          # sync assets, write engine config
    def render(self, p: Project, shot: Shot, out: Path) -> int   # frames written
    def build(self, p: Project, out: Path) -> Path | None        # playable build
    def export(self, p: Project, target: Path) -> Path | None    # GLB or equivalent
    def verify(self, p: Project) -> list[Check]    # engine level checks
```

`probe` is the contract that matters most. `studio doctor --deep` prints one row per adapter with version, path, GPU device, supported kinds and blockers. An adapter that cannot run on this machine says so and keeps the rest of the pipeline green.

Adapters call native CLIs, not third party MCP servers. Vendor MCP servers are editor bound, early and not reproducible in CI. "Connected to you" means every engine is drivable from one manifest and one command, with a probe that reports the truth. If a vendor MCP later becomes reliable, it wraps the same adapter instead of replacing it.

### Manifest v2

```yaml
id: 010-maker-at-work
kind: film                   # film | game
type: 3d                     # showcase label: 2d | 3d | game
title: The Maker at Work
summary: A maker sits down to work and the studio opens into the worlds the work makes possible.
tags: [film, portrait, blender, cycles, sound]
engine: blender              # any registered adapter
entry: film/film.py
render:
  resolution: [1920, 800]
  fps: 24
  frames: 1800
  samples: 128
  device: optix
  engine_args: ["--engine", "CYCLES", "--denoise"]
shots:
  - {id: s01-desk, entry: shots/s01_desk.py, frames: 168}
  - {id: s02-portrait, entry: shots/s02_portrait.py, frames: 216}
  - {id: s03-open, entry: shots/s03_open.py, frames: 144}
  - {id: s04-desert, entry: shots/s04_desert.py, frames: 288}
  - {id: s05-neon, entry: shots/s05_neon.py, frames: 264}
  - {id: s06-paper, entry: shots/s06_paper.py, frames: 240}
  - {id: s07-cosmos, entry: shots/s07_cosmos.py, frames: 264}
  - {id: s08-return, entry: shots/s08_return.py, frames: 216}
audio:
  score: audio/score.wav
  voice: audio/voice.wav
outputs:
  - media/010-maker-at-work/maker-at-work.mp4
  - media/010-maker-at-work/maker-at-work.webm
  - media/010-maker-at-work/poster.jpg
```

Backwards compatibility: a manifest without `kind` infers it from `type` (`game` becomes `game`, everything else becomes `film`). A manifest without `shots` becomes one implicit shot covering all frames. Projects 001 to 004 do not change behaviour.

`type` keeps driving the gallery filter. `kind` drives the pipeline. `engine` is no longer tied to `type`. The old rule `2d -> python, 3d -> blender, game -> godot` is removed. Validation instead checks that the engine is registered and supports the declared kind.

Publishing stops matching the filenames `reel.mp4` and `reel.webm`. It uses the first declared MP4 and WebM in `outputs`, so films and engine artifacts can use descriptive names. Generated showcase data gains `kind`, and the site can label films separately from games.

`audio`, `samples`, `device`, `engine_args` and `shots` are optional. Missing values get documented defaults so the existing projects stay valid. A shot may set `still: true` for a deliberate hold, which exempts it from the frozen frame check. A silent engine capture is valid; the main film declares a score, and `verify` fails a project that declares audio but produces no audio stream.

### Shot based film pipeline

A film is a list of shots, each with its own source file and frame count. `render` runs shots in order, writes `media/<id>/_frames/<shot>/frame_0001.png`, and encodes each shot separately before the final mix. This gives three things:

- A failing shot is re-rendered alone.
- A shot can change without re-rendering the film.
- Frame counts in the manifest must sum to `render.frames`, and `verify` fails if they do not.

Final mix order: concatenate shot encodes with the FFmpeg concat demuxer, mux the score and voice stems, apply loudness normalisation once, then run the media budget check. The encoder gains an optional audio input and a loudness pass; silent projects behave exactly as they do today.

### Resumable render queue

`studio render <id>` keeps a `state.json` beside the frames with, per shot: expected frames, completed frames, source file hash, settings hash and last update time.

- A frame that exists and matches the settings hash is skipped.
- A changed source or setting invalidates only that shot.
- `--resume` is the default for films and an explicit flag for everything else.
- `--shot <id>` renders one shot.
- `--preview` renders at half resolution with low samples and writes to `_frames/preview/`.
- Ctrl-C leaves the queue intact.

This matters because a 75 second Cycles film is an overnight job, and one crash must not cost six hours.

### Verification

`studio verify <id>` runs every check and exits non-zero on the first failure. `render` calls it automatically.

| Check | Detail |
| --- | --- |
| Media spec | ffprobe duration within 0.1 s, declared resolution, fps, codec, pixel format |
| Media budget | GIF 8 MB, MP4 and WebM 20 MB, poster 500 KB, GLB 5 MB |
| Frame completeness | every shot has exactly its declared frames, none zero length |
| Frame sanity | all black frames flagged; frozen runs longer than 12 frames flagged unless the shot sets `still: true` |
| Audio | when audio is declared, the stream exists and EBU R128 integrated loudness sits at -14 LUFS plus or minus 1, true peak at or below -1 dBTP |
| glTF | Khronos glTF Validator clean, animations present when the manifest promises them |
| Assets | every referenced asset exists, hash matches, licence and source fields present, lane rules respected |
| Builds | web build loads and runs a scripted smoke test in Playwright, desktop build launches and exits clean |
| Credits | generated credits match the asset catalog |

A contact sheet is written to `qa/<id>/` every 5 seconds for the owner to review. `qa/` is gitignored.

### Asset provenance and licence lanes

Every asset belongs to exactly one lane.

| Lane | Location | In git | Allowed licences | Use |
| --- | --- | --- | --- | --- |
| repo | `assets/repo/` | yes | CC0, CC-BY, MIT, OFL, public domain | committed source, shipped in builds, credited |
| embed | `assets/embed/` | no, recipe and hash yes | EULA, royalty free, per seat | baked into renders and builds, never shipped as a raw file |
| private | `assets/private/` | no | owner files | portrait source, voice reference, never published raw |

`assets/catalog.yaml` is the single registry:

```yaml
- id: polyhaven-studio-hdri
  lane: repo
  license: CC0-1.0
  source: https://polyhaven.com/a/studio_small_09
  path: assets/repo/hdri/studio_small_09_2k.hdr
  sha256: "..."
  credit: Poly Haven
```

`studio assets fetch` downloads missing repo and embed assets, checks the hash and refuses mismatches. `studio assets verify` enforces the lane table and checks hashes for files that exist. `--offline` skips missing embed and private files, which is what CI uses because those lanes are not in git. `studio assets credits` regenerates `THIRD_PARTY_NOTICES.md` and `showcase/src/credits.generated.ts` from the catalog. `studio validate` checks that every referenced asset has a catalog entry, a licence, a source and a legal lane, so a project with an unlicensed asset cannot render or publish.

Banned outright: Mixamo (no redistribution, AI training restrictions), Asset Store or Fab assets in the repo or in web builds, Sketchfab licences below CC0 or CC-BY, and any asset whose terms forbid synthetic or AI assisted production.

### CLI changes

```
studio doctor [--deep]                 tools plus adapters, GPU and blockers
studio new film <name> --engine <e>    scaffold a film for any adapter
studio render <id> [--shot S] [--resume] [--preview]
studio build <id>                      playable build for games
studio export <id>                     GLB or engine export
studio verify <id> [--baseline]        full verification, optional SSIM baseline
studio assets fetch|verify [--offline]|credits
studio publish
```

`studio new` keeps the `2d`, `3d` and `game` shortcuts and maps them to `python`, `blender` and `godot`. Films use `studio new film <name> --engine <engine>`.

## Engine plan

| Engine | Version | Role | Artifact | Risk |
| --- | --- | --- | --- | --- |
| Blender | 4.5 LTS (installed) | film, 3D, Cycles OptiX | `010-maker-at-work` | medium, render time |
| Godot | 4.7.2 (installed) | 2D and 3D games, web | existing `003-micro-game` | low |
| Python + Pillow | 3.15 venv (installed) | 2D motion graphics | existing `001-2d-bounce` | low |
| Unity | 6 LTS | real-time lit scene, batch capture, WebGL | `005-unity-room` | medium, licence sign-in |
| GDevelop | 5 | 2D game, web export | `006-gdevelop-lantern` | medium, export automation |
| LÖVE | 11.5 | Lua arcade, deterministic capture | `007-love-orbit` | low, web export unlikely |
| MonoGame | 3.8 with .NET LTS | C# game, render target capture | `008-monogame-river` | low |
| Unreal | 5.8 | cinematic probe | `009-unreal-probe` | high, below practical minimums |

Artifacts:

- **005-unity-room**: a lit cream gallery room with CC0 props and a slow camera move. Unity runs in batch mode with the GPU, renders through a RenderTexture and writes PNG frames. A poster and a 20 second MP4 go on the site. A WebGL build is attempted and goes to `/play` only under the budget rule; otherwise the scene ships as video plus source.
- **006-gdevelop-lantern**: a short 2D lantern platformer vignette using our own art. GDevelop export is automated if the CLI is reliable; the web build goes to `/play` under the budget rule, and a poster and a 20 second MP4 are captured from the build. The project file plus the export recipe is committed either way.
- **007-love-orbit**: a neon orbit arcade prototype with deterministic input replay. LÖVE renders frames offscreen for video. A Windows zip is attached to a release. love.js web export is attempted and goes to `/play` only if it is stable and under budget.
- **008-monogame-river**: a paper boat river game in C# with deterministic update steps and RenderTarget capture. Windows build attached to a release.
- **009-unreal-probe**: an 8 second, 720p, low scalability scene. If Unreal cannot sustain a usable frame time, the artifact becomes a committed capability report in `docs/engines.md` with measured numbers, and the adapter stays registered and reports the blocker.

Web play follows one budget rule. A build goes to `/play` only if CI can regenerate it or it is small enough to track under an explicit `.gitignore` exception, with a 40 MB per build ceiling and 40 MB total. Godot 4.7 ships a 38 MB wasm, so the measured ceiling replaced the original 25 MB target. `003-micro-game` is the existing exception because CI cannot run the Godot exporter. GDevelop and love.js builds qualify if they land under budget. Unity WebGL and anything larger ship as video plus a release download, so CI never depends on licence activation. The repo stays source first, and the rule is enforced by a size check in `studio verify`. `AGENTS.md` records this one exemption and its budget.

### Install gates

Phase 0 installs and probes in this order, stopping only for sign-ins the owner must perform:

1. Unity Hub and Unity 6 LTS with Windows build support, then `-batchmode -quit` licence check.
2. GDevelop 5, then determine whether its CLI can export without the GUI.
3. LÖVE 11.5 portable, MonoGame templates with `dotnet new`.
4. Epic Games Launcher and Unreal 5.8. This is the largest download and the least likely to be useful.
5. `studio doctor --deep` writes the capability matrix to `docs/engines.md`.

A failed install does not block the rest. The capability matrix records what works, what does not, and why.

## Asset libraries

All in the repo lane unless noted.

| Source | Content | Licence |
| --- | --- | --- |
| Kenney | 2D and 3D kits, UI, audio | CC0 |
| Poly Haven | HDRIs, textures, a few models | CC0 |
| ambientCG | PBR materials | CC0 |
| Quaternius | low poly models | CC0 |
| Godot demo projects | engine reference assets | MIT |
| CMU Graphics Lab mocap | BVH motion | free, credit |
| VSCO 2 Community Edition | orchestral samples, selected instruments only | CC0 |
| Freesound (CC0 filter only) | spot effects | CC0 |
| Sonniss GDC packs | sound design | royalty free, embed lane |
| 100STYLE | stylised mocap | only after a licence check in Phase 3 |

Mocap is retargeted to our procedural rigs in Blender, then baked into the scene. The film uses motion as reference, not imported character models.

## Repo layout additions

```
studio/lib/engines/       base.py, registry.py, one file per adapter
studio/lib/verify/        media, frames, audio, gltf, builds
studio/lib/assets.py      catalog, fetch, lanes, credits
studio/templates/film/    shot scaffold
studio/templates/game-{unity,gdevelop,love,monogame}/
assets/repo/              committed, credited assets
assets/embed/             ignored, recipe and hash only
assets/private/           ignored, owner files
assets/catalog.yaml       provenance registry
docs/engines.md           capability matrix and per engine recipes
docs/making-the-maker.md  behind the scenes, once the film exists
projects/005-unity-room/
projects/006-gdevelop-lantern/
projects/007-love-orbit/
projects/008-monogame-river/
projects/009-unreal-probe/
projects/010-maker-at-work/
```

## The Maker at Work

A 75 second target film, 24 fps, 1920 by 800 (2.40:1), with sound. It starts in a real room, then the room opens into the worlds the work makes possible, then it returns. The portrait is real in the close shots and a sculpted double carries the movement. There is no claim of photoreal likeness. The film is a stylised portrait, and the copy says so.

### Story

A maker sits at a desk at night with a lamp, a sketchbook and a framed portrait. The room quietly comes apart into paper, and the maker steps into the worlds that the work has already built: a lantern desert, a neon orbit, a paper stage, a cosmic library. The lantern from the first world returns in the last. The maker comes back to the desk, and the portrait on the desk is alive for a moment. Title.

The line that holds it together: the work is not an escape from the room. It is what the room becomes.

### Shots

| Shot | Time | Frames | Picture | Technique | Audio |
| --- | --- | --- | --- | --- | --- |
| s01-desk | 0:00 to 0:07 | 168 | Night desk, lamp, sketchbook, framed portrait, dust | Cycles, practical lamp, slow push in, shallow DOF | room tone, low drone, first sub hit |
| s02-portrait | 0:07 to 0:16 | 216 | The portrait breathes and turns a few degrees; light moves across the face | 2.5D layered portrait with depth parallax, real photo plate | voice line 1 |
| s03-open | 0:16 to 0:22 | 144 | Walls peel into paper, desk becomes a platform, camera pulls back | Cycles, cloth and paper sim baked, volumetric haze | music swell, paper flutter |
| s04-desert | 0:22 to 0:34 | 288 | Lantern Keeper desert at dusk, keeper and double walk together | Cycles, reused 004 assets upgraded, dust, lantern light | voice line 2, taiko pulse |
| s05-neon | 0:34 to 0:45 | 264 | Orbit Run neon track, camera chase, double silhouetted against speed streaks | Cycles emissive, motion blur, rim light | half time beat enters |
| s06-paper | 0:45 to 0:55 | 240 | Cream paper stage, floating sheets of the studio work, the double turns a page | Cycles, paper shader, soft studio HDRI | voice line 3, strings |
| s07-cosmos | 0:55 to 1:06 | 264 | Cosmic library, floating books, the lantern becomes a star | Cycles volumes, instanced books, slow orbit | choir, drone peak |
| s08-return | 1:06 to 1:15 | 216 | Back at the desk, portrait alive, lantern glowing, title | 2.5D portrait, warm lamp, slow pull back | voice line 4, final chord |

Frames total 1800. The 600 frame pilot is s01, s02 and s08 (25 seconds). The pilot sets final quality and measures per frame time before the rest is rendered.

### Face rule

The face has to look good and still read as the owner. How each shot achieves that is open: a real photo plate, a carefully enhanced plate, a depth displaced portrait, or a matched double kept in silhouette. Enhancement, upscaling or restoration is allowed when it makes the face look better without changing who it is. Anything that melts, warps or replaces the face is discarded. No shot shows a synthetic front lit face just to prove a technique. Face frames are reviewed at 100 percent against the source portrait, and the final check is a direct comparison.

### Likeness pipeline

The single photo route is split so each shot uses the tool that can actually deliver it.

- **Photo plate (close ups)**: the public chest up portrait, used at native scale or with a reviewed, face preserving upscale, cut into layers, and displaced with a locally generated monocular depth map. Camera moves are limited to a few centimetres and a few degrees so the parallax reads as breathing and a slight turn, not as a popped cardboard cutout. Real skin, real eyes, real hair.
- **Double (movement)**: a sculpted figure built from primitives and metaballs, matched to the portrait's skin tone, hair silhouette and clothing palette. Shown from behind, in three quarter silhouette, in shadow or at distance. Never a front lit close up.
- **Match cuts**: the cut from the double to the photo happens on a turn away, a lantern flare or a light change, so the audience never gets a clean comparison.
- **Guardrail**: no shot promises a photoreal front lit face. The site copy calls the film a stylised portrait built from a real photograph.

Tools: MiDaS for depth (MIT), both local. Real-ESRGAN (BSD-3) is optional and only kept if the reviewed result preserves likeness. If either fails, the fallback is a hand cut parallax from the portrait plus a still photo insert, which still reads well.

### Realism stack

- Cycles with OptiX, 128 samples, adaptive sampling, OpenImageDenoise, persistent data.
- Physical camera, f/2.0 to f/4, focus pulls, motion blur at 180 degrees.
- Poly Haven HDRI plus warm practicals; three point lighting; rim light to separate the double.
- Principled skin with subsurface scattering, fabric sheen, procedural grain and dust.
- Volume fog at low resolution, denoised, limited to two shots at a time.
- Film grain, slight halation, ACES style grade, cream and ink palette with one accent per world.
- No 4K. 1920 by 800 is the delivery size; the widescreen crop saves render time and looks cinematic.

### Score and sound

An original score, built in LMMS with VSCO 2 Community Edition samples, at 72 to 80 BPM.

- Low desert drone: sub sine at 36 Hz, detuned saw pad, breathy choir pad.
- Taiko and frame drum pulse for the desert and the library.
- A five note motif, original, played on low strings and later on a soft bell. Never a quote of the Dune theme.
- Half time beat under the neon shot: kick, snare, closed hats, 78 BPM, no lyrics.
- Sound design: room tone, paper, dust, lantern flame, distant wind, neon hum, book pages, a single sub drop at the title.
- Mix: -14 LUFS integrated, -1 dBTP, score ducked under the voice.

If the beat weakens the film, the neon shot keeps the drone and percussion only. The mix is judged on speakers and headphones before the final render.

### Voice

The owner supplied a 20 second reference. The preferred route is Chatterbox Turbo 350M (MIT code and weights), running locally on the GPU with 2 to 3 GB VRAM, cloning from 5 to 10 seconds of clean reference. It produces 4 short lines, about 50 words total, mixed under the score.

- A/B the clone against the reference. Keep it only if the timbre and cadence read as the owner.
- If quality is not there, try GPT-SoVITS (MIT) with a short fine tune. If that also fails, the film ships with music and text cards, no voice. The design does not depend on the clone.
- Rhubarb Lip Sync (MIT) can drive mouth shapes if a shot ever shows the double speaking. The current cut uses voice over visuals, so lip sync is optional.
- Non commercial or unclear voice models are excluded: XTTS v2 (CPML NC), F5-TTS (CC-BY-NC), Fish Speech (NC-SA). Zonos and Orpheus are too heavy for 4 GB VRAM.

### Length and render budget

Target 75 seconds. Minimum 60 seconds. The pilot decides. Films ship MP4 and WebM only, no GIF; the GIF budget stays for short loops.

- Measure seconds per frame at final settings on the pilot.
- If the full 1800 frames fit in one overnight run, keep 75 seconds.
- If not, cut to 1440 frames (60 seconds) by shortening s04, s05 and s07 by 120 frames each, never by lowering the samples on the portrait shots.
- The queue makes a multi night render safe.

## Showcase and credits

- `010-maker-at-work` gets a film page with the video, poster, shot list, likeness note, score note and voice consent note.
- The gallery gains a Film pill and sorts films first.
- New engine project pages show video, stills, source link and a release download where a build exists.
- `/credits` is a generated page listing every repo lane asset, its licence, source and author, plus engine and tool versions.
- `README.md` gains a film section at the top and an engine matrix.
- `docs/engines.md` explains how each adapter works and what failed on this machine.
- `docs/making-the-maker.md` covers the likeness pipeline, the score, the voice test and the render log.
- Copy stays light mode, cream and ink, no em dashes, reduced motion respected.

## CI

- Pull request and push: install Python and Node, run `pytest`, `studio validate`, `studio assets verify --offline`, typecheck and build the showcase.
- Assets verify runs offline: repo lane files must exist and match their hashes, and embed and private entries must have licence, source and hash fields.
- Deploy on `main`: publish, build, deploy Pages.
- Renders and engine builds stay local. The site is verified locally and on the deployed URL in a real browser.

## Phases and gates

| Phase | Work | Gate |
| --- | --- | --- |
| 0 | Install and probe Unity, GDevelop, LÖVE, MonoGame, Unreal; write capability matrix | `doctor --deep` reports every adapter; failures documented |
| 1 | Studio OS core: adapters, manifest v2, shots, queue, verify, assets, credits; migrate 001 to 004 | tests pass, four existing projects still render, site builds |
| 2 | Engine artifacts 005 to 009, each published or documented as blocked | every engine has an artifact or a measured failure report |
| 3 | Cinematic stack, portrait pipeline, 600 frame pilot, voice test, score sketch | pilot reviewed by the owner, per frame cost measured |
| 4 | Full film, final mix, overnight render, publish, making of | film verified, site live, owner has watched it |
| 5 | Polish, docs, credits, CI, final browser verification | definition of done met |

## Definition of done

1. `pytest`, `studio validate`, `studio assets verify --offline` pass.
2. Every rendered film passes ffprobe spec, loudness and frame checks at the declared size.
3. Every rendered project has a poster and a project page. A blocked engine has a page that states the blocker and the measured reason.
4. The film has been viewed end to end, the face compared against the source portrait, and it reads clearly at desktop and mobile widths.
5. `studio publish` runs and the site builds.
6. The deployed site, film, and every playable build have been opened in a real browser.
7. Credits are generated and accurate, including engine versions and every repo asset.
8. Commits are small, conventional and pushed.

## Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| 11.4 GB RAM with Unity or Unreal | One heavy app at a time, close browsers, 720p probe, document limits |
| 4 GB VRAM in Cycles | 128 samples with denoise, 2.40:1 frame, light scenes, CPU fallback |
| Unreal will not run usefully | Probe only, capability report, adapter reports blocker |
| Unity needs a licence sign in | Owner signs in once; if not, Unity artifact becomes source plus docs |
| GDevelop export is GUI bound | Automate the project file, document the export recipe, attach the build to a release |
| love.js and MonoGame web are unreliable | Ship video and Windows builds, no web promise |
| Voice clone sounds wrong | A/B test, GPT-SoVITS fallback, music only fallback |
| Photoreal likeness is impossible | Hybrid photo plate plus double, guarded camera angles, honest copy |
| Render takes days | Resumable queue, pilot cost measurement, 60 second fallback |
| Asset licence drift | Lane gate in validate, generated credits, banned source list |
| Repo grows too large | Media budgets, releases for builds, raw frames and caches ignored |
| Film MP4 exceeds 20 MB | CRF tune then two pass bitrate cap at 75 seconds |

## Success criteria

- Every engine adapter is probed by one command, and the owner can point at all seven engines in one repo.
- The film runs 60 to 75 seconds at 1080p with original score and a cloned or absent voice. The face reads as the owner, never looks distorted, and is clearly about the owner without overclaiming realism.
- Every engine either has a published artifact or an honest measured blocker in the docs.
- A stranger can clone the repo, run `studio doctor`, and understand exactly what will and will not run on their machine.
- No unlicensed asset, no private file, no raw frame, and no build output beyond the web build exemption enters git.

## Open decisions

- Final length, 60 or 75 seconds, decided by the pilot render.
- Unity WebGL in CI, only if licence activation can be made reproducible. Default is video plus release.
- Unreal kept as an experimental adapter, or moved to docs only, decided by the probe.
- Voice clone kept only if the A/B passes. Music only is an acceptable final film.
- 100STYLE mocap enters only if its licence clears the repo lane.
