"""Shot 01: night desk, lamp, sketchbook, framed portrait, dust.

The chair is empty and pushed back. The camera drifts in from the room to the
framed photograph, so the shot hands straight over to the portrait close up.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import film_common as film


def build(scene, args):
    film.room(scene)
    film.desk()
    lamp = film.lamp((0.50, 0.10, 0.78))
    frame = film.portrait_frame()
    frame["pivot"].rotation_euler = (math.radians(12), 0.0, math.radians(-5))
    film.sketchbook()
    film.mug()
    dust = film.dust(scene, count=36, center=(0.10, 0.10, 1.15), spread=(1.8, 1.1, 1.1), seed=7)
    film.haze(scene, density=0.005)
    film.world(scene, color=(0.010, 0.011, 0.016), strength=0.16)

    film.area_light(
        "WindowCool", (-2.05, -1.10, 2.05), (-0.20, 0.24, 0.98),
        energy=42, size=1.4, color=(0.52, 0.66, 1.0),
    )
    film.area_light(
        "RimWarm", (1.50, 0.96, 1.88), (0.18, 0.56, 1.20),
        energy=26, size=0.85, color=(1.0, 0.60, 0.30),
    )
    film.area_light(
        "Bounce", (0.10, -1.60, 0.35), (0.05, 0.10, 0.85),
        energy=6, size=1.4, color=(1.0, 0.72, 0.46),
    )

    rig = film.camera(
        (-0.85, -2.15, 1.30), (0.02, 0.18, 1.02),
        lens=45, fstop=2.2, focus=frame["photo"],
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (-0.85, -2.15, 1.30))
    film.keyframe(camera, "location", 84, (-0.61, -1.79, 1.20))
    film.keyframe(camera, "location", 168, (-0.45, -1.50, 1.12))
    film.keyframe(target, "location", 1, (0.02, 0.18, 1.02))
    film.keyframe(target, "location", 84, (-0.18, 0.16, 1.02))
    film.keyframe(target, "location", 168, (-0.44, 0.14, 1.02))
    film.ease(camera)
    film.ease(target)

    film.keyframe(dust, "location", 1, (0.10, 0.10, 1.10))
    film.keyframe(dust, "location", 168, (0.15, 0.00, 1.20))
    film.keyframe(dust, "rotation_euler", 1, (0.0, 0.0, 0.0))
    film.keyframe(dust, "rotation_euler", 168, (0.0, 0.0, math.radians(7)))
    film.ease(dust)

    film.pulse(lamp["light"], args.frames_end, base=48.0, amp=2.0, period=96)
    film.fade(lamp["bulb"].data.materials[0], "Emission Strength", [(1, 16.0), (96, 18.5), (168, 17.0)])

    return {"camera": camera, "target": target, "lamp": lamp, "frame": frame, "dust": dust}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
