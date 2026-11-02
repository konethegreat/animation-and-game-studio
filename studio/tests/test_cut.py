import subprocess
from pathlib import Path

import pytest
from PIL import Image

from studio.lib import cut, manifest, media
from studio.lib.manifest import Project, Shot


@pytest.fixture(autouse=True)
def tmp_roots(tmp_path, monkeypatch):
    monkeypatch.setattr(manifest, "ROOT", tmp_path)
    monkeypatch.setattr(media, "ROOT", tmp_path)


def make_project(tmp_path: Path) -> Project:
    return Project(
        id="099-cut-test",
        type="3d",
        title="Cut",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(160, 90),
        fps=24,
        frames=6,
        poster_time=0.0,
        outputs=["media/099-cut-test/reel.mp4"],
        kind="film",
        shots=[
            Shot("a", "scene.py", 2),
            Shot("b", "scene.py", 2),
            Shot("c", "scene.py", 2),
        ],
        root=tmp_path,
    )


def frames(path: Path, count: int, colour: int) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    for index in range(1, count + 1):
        Image.new("RGB", (160, 90), (colour, 40, 80)).save(path / f"frame_{index:04d}.png")
    return path


def test_cut_concatenates_selected_shots(tmp_path):
    project = make_project(tmp_path)
    root = tmp_path / "media" / project.id / "_frames"
    frames(root / "a", 2, 20)
    frames(root / "b", 2, 60)
    frames(root / "c", 2, 100)
    out = tmp_path / "media" / project.id / "pilot.mp4"
    result = cut.cut(project, ["a", "c"], out)
    assert result == out
    info = media.probe(out)
    assert (info["width"], info["height"]) == (160, 90)
    assert info["duration"] == pytest.approx(4 / 24, abs=0.2)


def test_cut_muxes_audio(tmp_path):
    project = make_project(tmp_path)
    root = tmp_path / "media" / project.id / "_frames"
    frames(root / "a", 2, 20)
    audio = tmp_path / "pilot.wav"
    subprocess.run([
        str(media.find_tool("ffmpeg")), "-y", "-f", "lavfi",
        "-i", "sine=frequency=220:duration=0.2", str(audio),
    ], check=True, capture_output=True)
    out = tmp_path / "media" / project.id / "pilot.mp4"
    cut.cut(project, ["a"], out, audio=audio)
    assert media.has_audio(out) is True


def test_cut_rejects_missing_frames(tmp_path):
    project = make_project(tmp_path)
    root = tmp_path / "media" / project.id / "_frames"
    frames(root / "a", 1, 20)
    with pytest.raises(ValueError, match="frame"):
        cut.cut(project, ["a"], tmp_path / "pilot.mp4")


def test_cut_rejects_unknown_shot(tmp_path):
    project = make_project(tmp_path)
    with pytest.raises(ValueError, match="unknown"):
        cut.cut(project, ["zz"], tmp_path / "pilot.mp4")


def test_cli_cut_parses_shot_list(tmp_path, monkeypatch):
    from studio import studio as cli

    project = make_project(tmp_path)
    calls = []
    monkeypatch.setattr(cli.manifest, "find", lambda project_id: project)
    monkeypatch.setattr(
        cli.cut, "cut",
        lambda project, shots, out, audio=None: calls.append((shots, out, audio)),
    )
    code = cli.main([
        "cut", project.id, "--shots", "a, c",
        "--out", str(tmp_path / "pilot.mp4"),
    ])
    assert code == 0
    assert calls[0][0] == ["a", "c"]
