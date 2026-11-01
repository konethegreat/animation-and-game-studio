"""Prepare the owner portrait plate for The Maker at Work.

The source photograph is 1000x1334. The film plate is a 2.4:1 crop around the
head and upper chest, upscaled to 2000x834 with Lanczos and a light unsharp
mask. A gentle grade pulls the daylight photograph toward the film's dark
warm look and a soft corner vignette keeps the eye on the face. Nothing is
generated: every pixel comes from the owner's photograph.

The depth map is optional and built by depthmap.py in the ML venv. Without it
s02 renders the plate flat and says so.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

PROJECT = Path(__file__).resolve().parent
ROOT = PROJECT.parents[1]
PRIVATE = ROOT / "assets" / "private"
SOURCE = PRIVATE / "portrait.png"
PLATE = PRIVATE / "portrait_plate.png"
FRAMED = PRIVATE / "portrait_graded.png"
QA = PRIVATE / "qa"
ML_PYTHON = ROOT / ".venv-ml" / "Scripts" / "python.exe"

# Left, top, right, bottom in source pixels. The crop keeps the whole head,
# the shoulders and a little of the shirt, and lands at 2.398:1.
CROP = (0, 140, 1000, 557)
OUT_WIDTH = 2000


def grade(image: Image.Image) -> Image.Image:
    image = ImageEnhance.Brightness(image).enhance(0.94)
    image = ImageEnhance.Contrast(image).enhance(1.05)
    image = ImageEnhance.Color(image).enhance(1.02)
    vignette = Image.radial_gradient("L").resize(image.size, Image.LANCZOS)
    vignette = vignette.filter(ImageFilter.GaussianBlur(image.width / 14))
    vignette = vignette.point(lambda value: round(value * 0.5))
    shaded = ImageEnhance.Brightness(image).enhance(0.68)
    return Image.composite(shaded, image, vignette)


def crop_box(size: tuple[int, int]) -> tuple[int, int, int, int]:
    width, height = size
    left, top, right, bottom = CROP
    if right > width or bottom > height:
        raise SystemExit(f"crop {CROP} does not fit a {width}x{height} portrait")
    return left, top, right, bottom


def prepare() -> Path:
    if not SOURCE.exists():
        raise SystemExit(f"missing source portrait: {SOURCE}")
    with Image.open(SOURCE) as image:
        image = image.convert("RGB")
        box = crop_box(image.size)
        face = image.crop(box)
        framed = grade(image)
        framed = ImageEnhance.Brightness(framed).enhance(0.86)
        framed = ImageEnhance.Color(framed).enhance(0.9)
    framed.save(FRAMED, quality=95)
    print(f"framed print {framed.width}x{framed.height} {FRAMED}")
    scale = OUT_WIDTH / face.width
    height = round(face.height * scale)
    plate = face.resize((OUT_WIDTH, height), Image.LANCZOS)
    plate = plate.filter(ImageFilter.UnsharpMask(radius=1.1, percent=55, threshold=2))
    plate = grade(plate)
    PLATE.parent.mkdir(parents=True, exist_ok=True)
    plate.save(PLATE, quality=95)
    print(f"plate {face.width}x{face.height} -> {plate.width}x{plate.height} {PLATE}")

    QA.mkdir(parents=True, exist_ok=True)
    face_src = image.crop((250, 200, 750, 620))
    face_new = plate.crop((
        round((250 - box[0]) * scale), round((200 - box[1]) * scale),
        round((750 - box[0]) * scale), round((620 - box[1]) * scale),
    ))
    width = face_src.width + face_new.width + 24
    height = max(face_src.height, face_new.height)
    sheet = Image.new("RGB", (width, height), (24, 22, 20))
    sheet.paste(face_src, (0, 0))
    sheet.paste(face_new, (face_src.width + 24, 0))
    sheet.save(QA / "face_compare.png")
    print(f"face compare {QA / 'face_compare.png'}")
    return PLATE


def depth() -> None:
    if not ML_PYTHON.exists():
        raise SystemExit(f"missing ML venv: {ML_PYTHON}; see projects/010-maker-at-work/README.md")
    if not PLATE.exists():
        prepare()
    subprocess.run(
        [str(ML_PYTHON), str(PROJECT / "depthmap.py"), str(PLATE), str(PRIVATE / "portrait_plate_depth.png")],
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--depth", action="store_true", help="also build the depth map")
    args = parser.parse_args()
    prepare()
    if args.depth:
        depth()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
