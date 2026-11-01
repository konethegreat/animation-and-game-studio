"""Shot 08: back at the desk, the portrait alive, the lantern glowing, title.

The camera starts on the photograph, then pulls back to the whole desk while
the lantern settles and the title lifts in on the wall behind it.
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
    lantern = film.lantern((0.74, -0.26, 0.80))
    dust = film.dust(scene, count=42, center=(0.10, 0.10, 1.15), spread=(1.9, 1.1, 1.1), seed=9)
    film.haze(scene, density=0.006)
    film.world(scene, color=(0.010, 0.011, 0.016), strength=0.16)

    film.area_light(
        "WindowCool", (-2.05, -1.05, 2.05), (-0.20, 0.24, 0.98),
        energy=38, size=1.4, color=(0.52, 0.66, 1.0),
    )
    film.area_light(
        "RimWarm", (1.45, 0.96, 1.86), (0.18, 0.56, 1.20),
        energy=22, size=0.85, color=(1.0, 0.60, 0.30),
    )

    title = film.title_text("The Maker at Work", (-0.04, 1.005, 1.52), size=0.125, strength=0.0)
    title_mat = title.data.materials[0]
    film.keyframe(title, "location", 1, (-0.04, 1.005, 1.485))
    film.keyframe(title, "location", 150, (-0.04, 1.005, 1.505))
    film.keyframe(title, "location", 216, (-0.04, 1.005, 1.525))
    film.ease(title)
    film.fade(title_mat, "Emission Strength", [(1, 0.0), (140, 0.0), (180, 0.9), (216, 1.5)])

    rig = film.camera(
        (-0.38, -1.22, 1.12), (-0.45, 0.14, 1.02),
        lens=38, fstop=2.2, focus=frame["photo"],
    )
    camera, target = rig["camera"], rig["target"]
    film.keyframe(camera, "location", 1, (-0.38, -1.22, 1.12))
    film.keyframe(camera, "location", 108, (-0.02, -1.78, 1.24))
    film.keyframe(camera, "location", 216, (0.55, -2.45, 1.38))
    film.keyframe(target, "location", 1, (-0.45, 0.14, 1.02))
    film.keyframe(target, "location", 108, (-0.22, 0.18, 1.06))
    film.keyframe(target, "location", 216, (0.02, 0.25, 1.12))
    film.ease(camera)
    film.ease(target)

    film.pulse(lamp["light"], args.frames_end, base=30.0, amp=1.8, period=110, phase=0.6)
    film.pulse(lantern["light"], args.frames_end, base=8.0, amp=2.4, period=72, phase=1.4)
    film.fade(lantern["glass"].data.materials[0], "Emission Strength", [(1, 1.6), (60, 2.4), (132, 2.0), (216, 2.8)])

    photo_mat = frame["photo"].data.materials[0]
    film.fade(photo_mat, "Emission Strength", [(1, 0.20), (108, 0.34), (216, 0.28)])
    film.keyframe(frame["pivot"], "rotation_euler", 1, (math.radians(12), 0.0, math.radians(-1.2)))
    film.keyframe(frame["pivot"], "rotation_euler", 216, (math.radians(12), 0.0, math.radians(1.2)))
    film.ease(frame["pivot"])

    film.keyframe(dust, "location", 1, (0.10, 0.10, 1.08))
    film.keyframe(dust, "location", 216, (0.17, -0.02, 1.22))
    film.keyframe(dust, "rotation_euler", 1, (0.0, 0.0, 0.0))
    film.keyframe(dust, "rotation_euler", 216, (0.0, 0.0, math.radians(8)))
    film.ease(dust)

    return {"camera": camera, "target": target, "title": title, "lantern": lantern, "frame": frame}


if __name__ == "__main__":
    film.run_shot(film.parse_args(), build)
