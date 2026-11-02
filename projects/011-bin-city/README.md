# BIN CITY

A browser game about a collector cleaning Dawn Market before the shutters open. Built with Godot 4.7.2 and GDScript.

## The shift

- Vacuum loose litter, then sort it into the four depot bins.
- Bag the trash piles before rats drag them back into the street.
- Carry barrels, crates and pallets in a wobbling stack to the skip.
- Clean 90 percent of the district to finish. Rank 2 unlocks at 42 percent and swaps the costume and carry stack.

One run takes about ten minutes. Controls are on the play page: WASD or a stick to move, left mouse or RT to vacuum, E or X to interact, right drag or the right stick to look.

## How it is built

- `scripts/world.gd` builds Dawn Market from primitives: cobbles, awnings, stalls, canal, bridge and skip.
- `scripts/player.gd` handles camera-relative movement, the carry stack and rank costumes.
- `scripts/game.gd` owns the shift loop, flow multiplier, cleanliness and rank transitions.
- `scripts/sound.gd` synthesises the score, vacuum hum and effects as PCM16 at 22050 Hz.
- `scripts/ui.gd` draws the HUD, subtitles and touch pads.
- `tests/_smoke.gd` is a headless check that lifting and unloading a heavy load cleans the street and scores.

There are no imported models, textures or audio files. That keeps the web build inside the 40 MB ceiling. The poster is a still captured from the game's own `?poster=1` mode.

## Reproduce

```bash
./.venv/Scripts/python studio/studio.py build 011-bin-city
./.venv/Scripts/python studio/studio.py build 011-bin-city --target windows
./.venv/Scripts/python studio/studio.py verify 011-bin-city
./.venv/Scripts/python -m pytest studio/tests/test_smoke_game.py -v
```

The web build is playable from `build/web` through any static server. The Windows target writes `build/011-bin-city-windows.zip`.
