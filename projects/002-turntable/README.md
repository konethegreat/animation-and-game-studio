# Turntable

A stylized robot companion, modelled and lit in Blender, turning slowly in a soft studio. Built headless from Python, with no manual modelling.

- 1920x1080, 24 fps, 192 frames, 8 second loop.
- EEVEE Next, area key and fill, lime rim spot, warm grey world.
- Exports a GLB that powers the live viewer on the showcase.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py render 002-turntable
../../.venv/Scripts/python ../studio/studio.py export 002-turntable
../../.venv/Scripts/python ../studio/studio.py sheet media/002-turntable/reel.mp4 media/002-turntable/sheet.jpg
```

The hero still is rendered with `--hero` (see `scene.py`), which hides the floor and writes a transparent PNG.

## Notes

- The turntable root rotates exactly once over the loop while the hover, head, antenna and arms add secondary motion.
- Materials use emissive lime and coral so the robot reads clearly in the real-time viewer.
- `scene.py --check` builds the scene and prints mesh, light, frame and engine counts without rendering.
