# Orbit Run

A radial orbit runner built with Godot 4.7.2 and GDScript. A paper courier circles a small planet; you drag in and out to change orbit, threading stars, debris and comets.

Play: https://konethegreat.github.io/animation-and-game-studio/#play

## Controls

- Steer orbit: drag toward or away from the planet, or use W / S and the arrow keys
- Start and retry: Space, Enter, click or tap
- Calm mode: C, or the chip in the menu. It slows the orbit and removes flashes.

## Details

- 960x540, GL Compatibility renderer, single-threaded web export so it runs on GitHub Pages without cross-origin headers.
- Everything is drawn in code with `_draw()`. The nebula and the planet are custom canvas shaders. No sprite assets.
- Stars build a combo, near misses fill the surge drive, and milestones restore a shield and repaint the sky.
- The soundtrack and all sound effects are generated as waveforms at load time. There are no audio files.
- Best score and best range persist in `user://orbit.cfg`.

## Reproduce

```bash
python ../../studio/studio.py build 003-micro-game
python -m http.server -d build/web 8000
```

Open http://localhost:8000 and play.
