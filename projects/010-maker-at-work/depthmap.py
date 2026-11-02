"""Build a depth map for the portrait plate with a local monocular model.

Runs in .venv-ml. The model is downloaded once and cached by transformers. The
output is 8-bit inverse depth (brighter is closer), written next to the plate
and used only for a small displacement in s02.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageFilter
from transformers import pipeline

MODELS = ("depth-anything/Depth-Anything-V2-Small-hf", "Intel/dpt-hybrid-midas")


def load():
    device = 0 if torch.cuda.is_available() else -1
    last = None
    for name in MODELS:
        try:
            print(f"loading {name} on {'cuda' if device == 0 else 'cpu'}")
            return pipeline("depth-estimation", model=name, device=device)
        except Exception as exc:  # model download or task mismatch
            last = exc
            print(f"failed {name}: {exc}")
    raise SystemExit(f"no depth model loaded: {last}")


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: depthmap.py <plate.png> <depth.png>")
    source, target = (Path(arg) for arg in sys.argv[1:])
    with Image.open(source) as image:
        image = image.convert("RGB")
        size = image.size
        result = load()(image)
    depth = result["predicted_depth"]
    if isinstance(depth, torch.Tensor):
        depth = depth.detach().float().cpu().numpy()
    depth = np.asarray(depth).squeeze()
    low, high = np.percentile(depth, (1.0, 99.0))
    if high - low < 1e-6:
        raise SystemExit("depth map is flat")
    depth = np.clip((depth - low) / (high - low), 0.0, 1.0)
    grey = Image.fromarray((depth * 255).astype(np.uint8), mode="L").resize(size, Image.LANCZOS)
    # A soft ramp keeps the displaced silhouette from tearing away from the
    # photograph and catching a hard rim light.
    grey = grey.filter(ImageFilter.GaussianBlur(max(size) / 500))
    target.parent.mkdir(parents=True, exist_ok=True)
    grey.save(target)
    print(f"depth {size[0]}x{size[1]} -> {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
