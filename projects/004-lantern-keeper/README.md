# Lantern Keeper

A small hooded keeper walks three steps across a warm studio, stops, and raises a lime lantern while the camera dollies in and arcs around to a three-quarter view.

- 1280x720, 24 fps, 120 frames, 5 seconds.
- One EEVEE area key, a soft fill, a back rim and a single lime point light inside the lantern.
- The walk is a procedural cycle on parented joints, no armature. Three steps over 60 frames.
- The camera is a Catmull-Rom dolly: it follows the character from a wide shot to a closer angle and sweeps roughly 66 degrees around to the lantern side.
- Exports a looping in-place walk as a GLB for the live viewer.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py render 004-lantern-keeper
../../.venv/Scripts/python ../studio/studio.py export 004-lantern-keeper
../../.venv/Scripts/python ../studio/studio.py publish
```

Key frames for review:

```bash
"C:/Users/Konet/Tools/blender-4.5.10-windows-x64/blender.exe" -b --python scene.py -- --stills 1,60,95,120 --stills-dir qa --samples 24
```

## Notes

- The poster is taken at 4.55 seconds, the lantern-lift hold, through `render.poster_time`.
- The GLB rebuilds the scene in loop mode, so the export is a seamless in-place walk instead of the film timeline.
