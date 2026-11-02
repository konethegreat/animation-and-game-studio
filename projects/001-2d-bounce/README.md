# Paper City

A paper courier bounces down a card stock street. Every bounce warms the windows he passes, the bunting sways, and the whole city scrolls back to where it began. Drawn entirely with Pillow, one PNG frame at a time.

- 1920x1080, 24 fps, 144 frames, 6 second loop.
- Five bounces per loop; every pose derives from normalized loop time, so frame 0 and frame 1 match.
- Layered parallax: far skyline, mid blocks, front facades, then street props and drifting paper.
- The courier is built from squash and stretch primitives with a procedural scarf, a satchel, and a paper plane crossing the sky.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py render 001-2d-bounce
../../.venv/Scripts/python ../studio/studio.py sheet media/001-2d-bounce/reel.mp4 media/001-2d-bounce/sheet.jpg
```

The first command rebuilds `media/001-2d-bounce/reel.mp4`, `reel.webm`, `reel.gif` and `poster.jpg`. Raw frames live in `media/001-2d-bounce/_frames/` and stay out of git.

## Notes

- `render.py` draws at 2x on an RGB canvas and downsamples for clean edges. The canvas must stay RGB so translucent ink blends instead of overwriting.
- `BENCH`, `LAMPS`, `TREES` and the other prop constants set the sidewalk layout in world units.
- Tweak `BOUNCES` to change the rhythm. Keep every motion periodic so the loop stays seamless.
