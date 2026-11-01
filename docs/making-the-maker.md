# Making The Maker at Work

This is the record of how the pilot was made: the likeness pipeline, the score, the voice test and the render log. Everything here ran on one laptop with a 4 GB RTX 3050, 11.4 GB of RAM and no paid services.

## The likeness pipeline

The rule for the film is simple. The face is the owner's own, and no model is allowed to redraw it. A synthetic face that drifts between frames reads as a different person, and a still that melts under a renderer reads as a mistake. So the pilot treats the photograph as an object in the room.

1. **Source.** `assets/private/portrait.png` is the public portfolio portrait. It stays private on disk and is never committed.
2. **Crop and grade.** `portrait.py` crops to `(0, 140, 1000, 557)` for the 2.4:1 plate and resizes to 2000 px wide with Lanczos. The grade is deliberately small: brightness 0.94, contrast 1.05, colour 1.02, plus a soft radial vignette. The print on the desk gets a second, dimmer pass at brightness 0.86 and colour 0.9 so it sits in a dark room instead of glowing like a screen.
3. **Depth.** `portrait.py --depth` runs Depth Anything V2 Small on CUDA and writes `portrait_plate_depth.png`. The map is blurred by `max(size) / 500` before it is saved. Without that blur the displacement gives a stair stepped bright rim around the head, which is the one artifact that would make the plate look fake.
4. **Plate.** `s02_portrait.py` mounts the graded image on a subdivided plane at least 1.62 m wide, with a 384 by 160 grid and displacement strength 0.016. The camera push is only a few centimetres and there is no lateral sweep, so plate edges never enter frame.
5. **Review.** The plate and the render are checked at 100% against the source crop before any frame is accepted. Chin, hairline and the edge of the glasses are the tells.

The pilot uses only the photograph. Later wide shots may use a sculpted double kept in silhouette or at a distance, but the close shots stay photographic.

Why not a generative portrait? The hardware is 4 GB of VRAM, and every image to image model that fits either changes identity across frames or softens the face. A depth displaced print is deterministic, re renderable and honest about what it is.

## The score

`score.py` writes a 25 second original cue in numpy and soundfile at 48 kHz. Nothing is sampled and no theme is quoted.

- D1, D2 and A2 drone through a 220 Hz lowpass as the floor.
- A slow pad moves through D minor shapes with harmonics falling off as `1 / n^1.45` and a 2400 Hz lowpass.
- A half time pulse at 72 BPM enters under the desk, with one impact at 16 seconds for the return.
- A five partial melody with gentle vibrato starts at 7.6 seconds, under the portrait.
- A D5 bell and a filtered riser land at 21.83 seconds as the title resolves.
- A 0.9 second synthetic room adds space without a reverb library.

Stems are balanced by RMS rather than peak, because the kick was 60 times louder than the drone by peak alone. The master highpasses at 32 Hz, limits with `tanh` and normalizes to 0.89. The result is committed as `audio/pilot.flac` in PCM 16, 3.2 MB.

## The voice test

The owner recorded 20 seconds of speech as a reference and consented to a clone for this film. The reference and every raw take stay in `assets/private/`, which is gitignored. Only the mixed film is published.

Chatterbox 0.1.7 runs on CUDA with the local weights, so no text or audio leaves the machine. Three settings were rendered on the same line and judged three ways:

| Take | Exaggeration | CFG | Script heard | Speaker match | f0 median |
| --- | --- | --- | --- | --- | --- |
| neutral | 0.35 | 0.35 | exact | 0.898 | 92.0 Hz |
| default | 0.50 | 0.50 | exact | 0.861 | 91.5 Hz |
| warm | 0.65 | 0.45 | exact | 0.799 | 112.0 Hz |

The reference sits at 90.9 Hz, and the two halves of the reference match each other at 0.944 on the chatterbox voice encoder. Neutral was chosen: it keeps the register, scores closest to the speaker ceiling and transcribes word for word. `voice_qa.py` repeats the check on the final lines.

| Line | Text | Length | Speaker match |
| --- | --- | --- | --- |
| l01 | This is where the work begins. | 2.5 s | 0.884 |
| l02 | A desk, a lamp, and a little patience. | 3.4 s | 0.891 |
| l03 | Everything I make starts here. | 2.4 s | 0.890 |

`mix.py` highpasses the voice at 90 Hz, adds a short room at 16% and places the lines at 7.4, 11.6 and 18.4 seconds. The score ducks to 55% under each line and returns over 120 ms, so the bed never fights the words. The mix is committed as `audio/pilot-mix.flac` at 25.00 seconds.

## The render

The pilot is 600 frames at 1920 by 800, 24 fps, Cycles at 128 samples with OptiX denoising on the GPU.

| Shot | Frames | Content |
| --- | --- | --- |
| s01-desk | 168 | Night desk, lamp, sketchbook, framed print, slow push |
| s02-portrait | 216 | The print fills the frame, depth parallax, warm light |
| s08-return | 216 | Pull back to the desk, lantern, title |

The first benchmark rendered four s01 frames in 2 minutes 27 seconds, about 37 seconds per frame. The desk shot in the full queue runs closer to 55 seconds per frame because of the dust volume and the lamp bounce. The pilot therefore takes most of a night. The renderer resumes per shot, so an interrupted night costs only the frames in flight.

`studio render` runs each shot as a separate Blender process, writes frames to `media/010-maker-at-work/_frames/`, and refuses to encode if ffprobe sees the wrong resolution, frame rate or duration. `studio cut` assembles the pilot and `studio verify` checks the media, audio and budgets before publish.

## What went wrong

- Hugging Face downloads stalled three times mid file with the GPU idle. Resuming with `curl -C -` directly into the blob cache finished the job, and the checksums were verified against the repository before loading.
- Installing a newer audio QA stack pulled a newer torch and broke the pinned CUDA build. The fix is the pin in `requirements-ml.txt`: torch 2.6.0+cu124 with torchaudio and torchvision at the matching versions.
- PyAV has no Python 3.13 wheel that matches faster-whisper's decoder call. `voice_qa.py` feeds Whisper numpy audio decoded by soundfile, so the decoder is never used.
- The first displacement pass produced a halo around the head. The blurred depth map and the coarser grid removed it.

## Privacy

- `assets/private/` holds the portrait, the depth map, the voice reference, the model cache and the raw takes. Git ignores all of it.
- The published film contains the owner's face and cloned voice with his consent. The project page says so.
- No part of the pipeline uploads audio or images. The only network access is downloading open weights.
