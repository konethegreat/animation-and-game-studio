# __TITLE__

Replace this with the game loop, controls and what makes it fun.

- 960x540, 60 fps, GL Compatibility, single-threaded web export.
- Everything is drawn in `_draw()`. No sprite assets.
- Best score persists in `user://sample.cfg`.

## Controls

- Move: arrow keys or drag with mouse or touch.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py export __ID__
python -m http.server -d build/web 8000
```

Open http://localhost:8000 and play. Add a poster at `media/__ID__/poster.jpg` before publishing to the showcase.
