import subprocess
from pathlib import Path

import pytest
from PIL import Image

from studio.lib import manifest, media
from studio.lib.manifest import Project, Shot


@pytest.fixture(autouse=True)
def tmp_roots(tmp_path, monkeypatch):
    monkeypatch.setattr(manifest, "ROOT", tmp_path)
    monkeypatch.setattr(media, "ROOT", tmp_path)


def make_project(tmp_path: Path, outputs: list[str], shots: list[Shot] | None = None) -> Project:
    return Project(
        id="099-media-test",
        type="3d",
        title="Media",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(160, 90),
        fps=24,
        frames=4,
        poster_time=0.0,
        outputs=outputs,
        kind="film",
        shots=shots or [Shot("main", "scene.py", 4)],
        root=tmp_path,
    )


def frames(path: Path, count: int) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    for index in range(1, count + 1):
        Image.new("RGB", (160, 90), (index * 20, 40, 80)).save(path / f"frame_{index:04d}.png")
    return path


def test_budget_rejects_oversize(tmp_path, monkeypatch):
    path = tmp_path / "a.gif"
    path.write_bytes(b"x" * 100)
    monkeypatch.setattr(media, "BUDGET_MB", {".gif": 0.00001})
    with pytest.raises(ValueError, match="budget"):
        media.check_budget(path)


def test_parse_fps():
    assert media.parse_fps("24/1") == 24.0
    assert media.parse_fps("30000/1001") == pytest.approx(29.97, abs=0.01)


def test_budget_allows_small(tmp_path):
    path = tmp_path / "a.mp4"
    path.write_bytes(b"x" * 100)
    media.check_budget(path)


def test_unknown_suffix_is_ignored(tmp_path):
    path = tmp_path / "a.xyz"
    path.write_bytes(b"x" * 10_000_000)
    media.check_budget(path)


def test_resolve_poster_prefers_named_poster(tmp_path):
    project = make_project(tmp_path, [
        "media/099-media-test/hero.png",
        "media/099-media-test/poster.jpg",
    ])
    assert media.resolve_poster(project).name == "poster.jpg"


def test_encode_project_writes_declared_outputs(tmp_path):
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/reel.webm",
        "media/099-media-test/poster.jpg",
    ])
    source = frames(tmp_path / "frames", 4)
    outs = media.encode_project(project, source, 160, 90)
    assert outs["mp4"].exists()
    assert outs["webm"].exists()
    assert outs["poster"].exists()
    info = media.probe(outs["mp4"])
    assert (info["width"], info["height"]) == (160, 90)
    assert info["duration"] == pytest.approx(4 / 24, abs=0.15)


def test_encode_project_uses_gif_settings(tmp_path):
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/reel.gif",
    ])
    project.gif_width = 160
    project.gif_fps = 12
    project.gif_colors = 16
    project.gif_dither = "none"
    source = frames(tmp_path / "frames", 4)
    outs = media.encode_project(project, source, 160, 90)
    info = media.probe(outs["gif"])
    assert (info["width"], info["height"]) == (160, 90)


def test_encode_project_muxes_audio(tmp_path):
    audio = tmp_path / "score.wav"
    subprocess.run([
        str(media.find_tool("ffmpeg")), "-y", "-f", "lavfi",
        "-i", "sine=frequency=220:duration=0.2", str(audio),
    ], check=True, capture_output=True)
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/poster.jpg",
    ])
    project.audio = {"score": "score.wav"}
    source = frames(tmp_path / "frames", 4)
    outs = media.encode_project(project, source, 160, 90)
    assert media.has_audio(outs["mp4"]) is True


def test_encode_project_concatenates_shots(tmp_path):
    frames(tmp_path / "frames" / "a", 2)
    frames(tmp_path / "frames" / "b", 2)
    project = make_project(tmp_path, [
        "media/099-media-test/reel.mp4",
        "media/099-media-test/poster.jpg",
    ], shots=[Shot("a", "scene.py", 2), Shot("b", "scene.py", 2)])
    outs = media.encode_project(project, tmp_path / "frames", 160, 90)
    info = media.probe(outs["mp4"])
    assert info["duration"] == pytest.approx(4 / 24, abs=0.2)
