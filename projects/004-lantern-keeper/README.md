# Lantern Keeper

A keeper walks a paper bridge at dusk, stops, lifts a lime lantern, and wakes a sleeping paper city window by window.

- 1920x1080, 24 fps, 144 frames, 6 seconds, 48 EEVEE Next samples.
- A real armature: spine, neck, head, arms and legs with hand-weighted meshes, a pleated coat, a ribbon scarf and a hanging lantern bone.
- One key, a soft fill, a back rim, and a lime point light plus a beam cone inside the lantern.
- The walk is an in-place cycle on the exported rig. The film layers three steps, a stop, a head turn and the lantern lift on top of it, while the camera dollies in and arcs to a three-quarter angle.
- The city, bridge, water and fireflies are built in the same scene, and the windows wake in order as the lantern comes up.
- Exports Walk, Idle and Lift as separate glTF clips for the live Keeper Diorama.

## Reproduce

```bash
../../.venv/Scripts/python ../studio/studio.py render 004-lantern-keeper
../../.venv/Scripts/python ../studio/studio.py export 004-lantern-keeper
../../.venv/Scripts/python ../studio/studio.py publish
```

Key frames for review:

```bash
"C:/Users/Konet/Tools/blender-4.5.10-windows-x64/blender.exe" -b --python scene.py -- --stills 1,60,112,140 --stills-dir qa --samples 24
```

## Notes

- The poster is taken at 5.75 seconds, the lift hold, through `render.poster_time`.
- The GLB stashes three NLA tracks, so the web viewer gets a walk loop, an idle and a one-shot lift from one file.
- The diorama places the exported rig on its own bridge instead of baking the film camera path into the mesh.
