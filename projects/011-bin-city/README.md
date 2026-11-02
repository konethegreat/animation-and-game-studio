# BIN CITY

A browser game about a trash collector who levels up as they clean. Five shifts across three districts, a boss at the plant, and a street that always gets dirty again. Built with Godot 4.7.2 and GDScript.

## Ownership

BIN CITY is original work by Kone Tshivhinda at Kone Studio. The game, its code, art, characters, music and sound effects are proprietary and all rights are reserved. Playing the published build is welcome. Copying, redistribution, derivative works, commercial use and AI training are not permitted without written permission. See the repository [LICENSE](../../LICENSE).

Third party components keep their own licences in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

## The shift

- Vacuum loose litter, then sort it into the four depot bins.
- Bag the trash piles before rats drag them back into the street.
- Carry barrels, crates and pallets in a wobbling stack to the skip.
- Clean 90 percent of the district to finish. XP from cleaning and quests moves you through five ranks, from Street Sweeper to Cosmic Custodian, each with a new costume, gear and movement options: double jump, dash, glide and a cleanse pulse.
- Talk to the regulars. Quests, bottle returns at the canal, an arcade cabinet in the strip, and doors that open into the bakery, boathouse, depot and the plant.
- Shift five is the Gulper, a three phase boss fed by sorting chutes.

## The districts

- Dawn Market: the morning rush, stalls, bunting and a very full skip.
- Canal Quarter: washing lines, boats, clogged drains and a bottle machine.
- Neon Arcade: a night strip of signs, steam and Miso's high score.

Every district has its own music, ambience, lighting mood and loading card. The market track is ready at boot; the other districts synthesise their score behind the loading card when you first enter. Phones start in a lower quality tier with a 60 fps cap and thinner particles. Add `?low=1` to force that tier on any device.

## Controls

WASD or left stick to move, Shift or L3 to run, Space or A to jump then double jump, Ctrl or B to dash, Q or Y for the cleanse pulse, hold left mouse or RT to vacuum, E or X to talk, lift, sort and enter doors, right drag or right stick to look. Touch pads appear on phones. F3 toggles a frame time readout, F7 toggles the colour grade.

## How it is built

- `scripts/world.gd`, `scripts/canal_quarter.gd` and `scripts/neon_arcade.gd` build the districts from primitives; `scripts/district.gd` is the shared base and `scripts/interior.gd` builds the enterable rooms.
- `scripts/player.gd` handles camera relative movement, the carry stack, rank costumes and the new movement kit.
- `scripts/game.gd` owns the shift loop, flow multiplier, cleanliness, districts, interiors and the boss hookup.
- `scripts/npc.gd` and `scripts/crowd.gd` run the townsfolk, quests and reactions; `scripts/dialogue.gd` runs the lines.
- `scripts/boss.gd` is the Gulper fight; `scripts/cutscene.gd` runs the cold open, intro and ending.
- `scripts/sound.gd` synthesises every track and effect as PCM16 at 22050 Hz: five music loops, five ambience beds and crossfades between districts, built on demand so a first load stays short.
- `scripts/postfx.gd` grades each mood; `shaders/toon.gdshader` and `shaders/outline.gdshader` give the inked look.
- `tests/_logic.gd`, `tests/_smoke.gd` and `tests/_flow.gd` are headless checks; the flow check covers staged district loading, interior round trips and the boss room. `tests/_shots.gd` captures stills of every district.
- The showcase play page has a fullscreen control with an iOS-safe theatre fallback. On phones the frame grows into a portrait stage and a tap opens fullscreen before play.

There are no imported models, textures or audio files. Everything is primitives, generated images and synthesis. The poster is a still captured from the game's own `?poster=1` mode.

## Reproduce

```bash
./.venv/Scripts/python studio/studio.py build 011-bin-city
./.venv/Scripts/python studio/studio.py verify 011-bin-city
./.venv/Scripts/python -m pytest studio/tests/test_smoke_game.py -v
godot --headless --path projects/011-bin-city -s res://tests/_logic.gd
godot --headless --path projects/011-bin-city -s res://tests/_smoke.gd
godot --headless --path projects/011-bin-city -s res://tests/_flow.gd
```

The web build is playable from `build/web` through any static server.
