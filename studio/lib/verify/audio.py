from __future__ import annotations

from .. import media


def check(project) -> list[str]:
    if not project.audio:
        return []
    mp4 = project.output_path(".mp4")
    if not mp4 or not mp4.exists():
        return [f"audio declared but {project.id} has no mp4"]
    if not media.has_audio(mp4):
        return [f"{mp4.name} has no audio stream"]
    try:
        loudness = media.measure_loudness(mp4)
        integrated = float(loudness.get("input_i", 0))
    except Exception as exc:
        return [f"loudness check failed: {exc}"]
    problems = []
    if abs(integrated + 14.0) > 1.0:
        problems.append(f"integrated loudness {integrated:.1f} LUFS, expected -14")
    return problems
