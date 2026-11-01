from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from ..config import ROOT
from . import audio, builds, frames, gltf
from . import media as media_checks


@dataclass
class Check:
    name: str
    ok: bool
    detail: str = ""


def run(project, stage: str = "all") -> list[Check]:
    checks: list[Check] = []
    problems = []
    for shot in project.shots:
        out = project.media_dir / "_frames"
        out = out / shot.id if len(project.shots) > 1 else out
        problems.extend(frames.scan(out, shot))
    checks.append(Check("frames", not problems, "; ".join(problems)))
    media_problems = media_checks.check(project, stage)
    checks.append(Check("media", not media_problems, "; ".join(media_problems)))
    if stage == "all":
        audio_problems = audio.check(project)
        checks.append(Check("audio", not audio_problems, "; ".join(audio_problems)))
        asset_problems = []
        for output in project.outputs:
            path = Path(output)
            if path.suffix.lower() == ".glb":
                full = ROOT / output if not path.is_absolute() else path
                try:
                    info = gltf.inspect(full)
                    if info["animations"] == 0:
                        asset_problems.append(f"{path.name} has no animations")
                except Exception as exc:
                    asset_problems.append(str(exc))
        checks.append(Check("gltf", not asset_problems, "; ".join(asset_problems)))
        build_problems = builds.check(project)
        checks.append(Check("builds", not build_problems, "; ".join(build_problems)))
    return checks
