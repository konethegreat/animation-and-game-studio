# __TITLE__

Replace this with what the scene shows and how it is lit.

- 1280x720, 24 fps, 96 frames, 4 second turntable.
- EEVEE Next, one area key, a soft fill and a cream world.
- Exports a GLB next to the video for the live viewer.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py render __ID__
../../.venv/Scripts/python ../studio/studio.py export __ID__
../../.venv/Scripts/python ../studio/studio.py sheet media/__ID__/reel.mp4 media/__ID__/sheet.jpg
```
