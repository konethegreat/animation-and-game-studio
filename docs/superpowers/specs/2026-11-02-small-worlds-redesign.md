# Small worlds redesign

Date: 2026-11-02
Status: approved, in progress
Branch: `small-worlds`

## Intent

Four showcase pieces graduate from "engine demo" to "small world you can touch". Each piece ships two things: a polished rendered artefact for the project page, and an in-page interactive lab that lets a visitor play with the same idea. The rendered piece proves craft; the lab proves the work is alive.

The pieces:

1. `001-2d-bounce` becomes **Paper City**, a 2D paper craft film, plus a **Bounce Lab**.
2. `002-turntable` becomes **Companion**, a character piece, plus a **Companion Lab**.
3. `003-micro-game` becomes **Orbit Run**, a radial orbit runner, rebuilt around radial control.
4. `004-lantern-keeper` becomes **The Lantern Keeper**, a rigged humanoid film, plus a **Keeper Diorama**.

## Constraints

- **Isolation.** Work happens in the git worktree `C:/Users/Konet/studio-small-worlds` on branch `small-worlds`, cut from `main`. Do not touch the primary tree, `projects/010-maker-at-work`, or the `bin-city` worktree. No imports from `010-maker-at-work`. The paper vocabulary is re-implemented locally.
- **Budgets.** GIF under 8 MB, MP4/WebM under 20 MB, poster under 500 KB, GLB under 5 MB, tracked web build under 40 MiB.
- **House style.** Light mode, warm cream, ink text, one accent per scene, no em dashes in copy, respect `prefers-reduced-motion` on the site.
- **Pipeline.** Every project stays a normal manifest, render, verify, publish. No hand-edited generated files.

## 001 Paper City and Bounce Lab

**Film.** A small paper courier ball, with a scarf and a satchel, bounces down a cream paper street at golden hour. Two parallax rows of card stock buildings, terracotta awnings, ink windows that light on impact, loose sheets drifting, bunting, trees and a paper sun. The ball squashes, stretches, trails its scarf and kicks up paper dust. The camera tracks alongside at street height. Six second seamless loop, 1920x1080 at 24 fps, rendered with Pillow and numpy at 2x supersampling with a paper grain pass.

**Lab.** A canvas physics toy. Drag and fling the ball, gravity, bounce and stretch sliders, onion skin toggle, slow motion, three awning platforms that can be nudged, a scarf that trails the motion, and "Take a poster" which downloads the current frame as a PNG. Reduced motion starts paused with a play control.

**Tests.** Bounce timing is deterministic, squash never inverts, frame count and loop seam match the manifest.

## 002 Companion and Companion Lab

**Character.** A rounded ovoid body with a wrapped ink visor, articulated arms with an elbow joint, ear pods, a lit chest core, a spring antenna and a paper scarf. A softer, more designed silhouette than the current boxy robot.

**Film.** An eight second piece on a cream cyclorama with a dark disc, soft key, fill, rim and bounce light, dust motes and shallow depth of field. The turntable plays against an idle loop: breathing, blinking, a small wave, antenna follow through. EEVEE Next, 1920x1080 at 24 fps.

**Export.** A GLB under 3 MB, with a named `Idle` animation and named nodes (`head`, `visor`, `chest`, `arm_l`, `arm_r`, `antenna`) so the lab can drive the rig in three.js.

**Lab.** Cursor tracking for the head, three moods (Say hi, Scan, Sleep), spin, reset and photo, orbit and zoom. Reduced motion holds a static, friendly pose.

## 003 Orbit Run

**Game.** A radial orbit runner. The courier orbits a paper planet automatically; the player drags inward and outward to change orbit radius, threading between stars, debris and comets. Collecting stars builds a combo; near misses feed a boost; shields absorb one hit; distance milestones change the sky. A custom shader paints the nebula and the paper planet, and the soundtrack is procedural. Calm mode and reduced motion slow the orbit and remove flashes.

**Build.** Godot web export stays under 40 MiB. The smoke test grows from "scene loads" to orbit state, input, scoring and reset.

## 004 The Lantern Keeper and Keeper Diorama

**Character.** A real humanoid mesh driven by an armature with manual weights: pelvis, spine, neck, head, shoulders, elbows, wrists, hips, knees, ankles, plus coat and scarf bones. The walk uses contact, down, passing and up phases with hip sway, shoulder counter rotation, heel to toe roll, coat and scarf follow through, and a lantern that swings on its own pendulum.

**Film.** The keeper walks a paper bridge over a dark river toward a paper city at dusk. Moon, haze, a volumetric lantern beam, a wave of city lights, embers and moths, and a slow camera crane. Six seconds at 1920x1080 and 24 fps, EEVEE Next with a light Cycles pass option for stills.

**Export.** A GLB under 5 MB with an `Idle` and a `Walk` clip.

**Lab.** A three.js diorama: orbit the scene, scrub or play the walk, a dusk to night slider, "Light the lantern" which raises the beam and wakes the city, fireflies, camera presets and "Take a still".

## Pipeline and site

- Add an optional `interactive` field to the manifest: one of `bounce`, `companion`, `keeper`. Parsed, validated, published into `projects.generated.ts`, with tests.
- Add `showcase/src/labs/` with one module per lab and a shared three.js stage helper for renderer, lights, environment, resize and dispose.
- Project pages grow a "Take the controls" section when `interactive` is set. Home copy, the filter row and the card chip reflect the labs. Project notes and the play page copy are rewritten. Nothing is hard-coded by project id.

## Verification

Per piece: render or export, ffprobe or GLB check, budgets, and a viewed still. Lab: typecheck, build, and a real browser pass at desktop and mobile widths, including reduced motion. Global: `studio validate`, `studio assets verify --offline`, pytest, `pnpm typecheck`, `pnpm build`, `studio publish`, then merge to `main` and verify the live Pages deploy.

## Risks

- **004 GIF.** A denser six second film may exceed the 8 MB GIF cap. Mitigation: keep the cut to six seconds and, if needed, add per-project GIF settings rather than dropping frames from the MP4.
- **002 GLB.** The current export is 4.89 MB. Mitigation: lower segment counts on spheres and tori and target under 3 MB.
- **003 build size.** Two MiB of headroom under the cap. Mitigation: no large fonts or baked textures; procedural audio.
- **Scope.** Four pieces is a lot. Order: 001 first for the fastest feedback loop, then first stills for 002 and 004 before their full renders.
