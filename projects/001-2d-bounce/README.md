# Bounce

A squash and stretch study with a little blob character, a springy antenna and a patient stage. Drawn entirely with Pillow, one PNG frame at a time.

- 1920x1080, 24 fps, 144 frames, 6 second loop.
- Every pose derives from normalized loop time, so frame 0 and frame 1 match.
- Antenna lag, dust rings and cheek highlights are procedural, not hand keyed.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py render 001-2d-bounce
../../.venv/Scripts/python ../studio/studio.py sheet media/001-2d-bounce/reel.mp4 media/001-2d-bounce/sheet.jpg
```

The first command rebuilds `media/001-2d-bounce/reel.mp4`, `reel.webm`, `reel.gif` and `poster.jpg`. Raw frames live in `media/001-2d-bounce/_frames/` and stay out of git.

## Notes

- `render.py` draws at 2x and downsamples for clean edges.
- Fonts fall back to Pillow's default face when Segoe UI is not installed.
- Tweak `SEGMENTS` to change the bounce rhythm. Keep the durations summing to 1.0.
