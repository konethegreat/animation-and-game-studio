# __TITLE__

Replace this with the game loop, controls and what makes it fun.

- 1280x720, 60 fps, GL Compatibility, single-threaded web export.
- The district is built from primitives in `main.gd`. No imported models or textures.
- Collect the coral orbs. The camera follows the player and the pillars block movement.

## Controls

- Move: WASD, arrow keys, or the left stick on a gamepad.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py build __ID__ --target all
python -m http.server -d build/web 8000
```

Open http://localhost:8000 and play. `--target windows` also writes a zip next to the Windows export. Add a poster at `media/__ID__/poster.jpg` before publishing to the showcase.
