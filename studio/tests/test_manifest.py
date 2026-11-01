from pathlib import Path

from studio.lib import manifest

GOOD = """
id: 009-demo
type: 2d
title: Demo
summary: A demo.
tags: [2d]
engine: python
entry: render.py
render: {resolution: [1280, 720], fps: 24, frames: 48}
outputs: [media/009-demo/demo.mp4]
"""


def write(tmp_path: Path, body: str) -> Path:
    project = tmp_path / "p"
    project.mkdir(exist_ok=True)
    (project / "project.yaml").write_text(body, encoding="utf-8")
    (project / "render.py").write_text("", encoding="utf-8")
    return project


def test_loads_valid_manifest(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.id == "009-demo"
    assert project.fps == 24
    assert project.resolution == (1280, 720)
    assert manifest.validate(project) == []


def test_poster_time_defaults_and_parses(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.poster_time == 1.0
    tuned = GOOD.replace("frames: 48", "frames: 48, poster_time: 4.4")
    project = manifest.load(write(tmp_path, tuned))
    assert project.poster_time == 4.4


def test_rejects_engine_type_mismatch(tmp_path):
    bad = GOOD.replace("engine: python", "engine: blender")
    project = manifest.load(write(tmp_path, bad))
    assert any("engine" in error for error in manifest.validate(project))


def test_rejects_missing_entry(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    project.entry = "missing.py"
    assert any("entry" in error for error in manifest.validate(project))


def test_rejects_bad_id(tmp_path):
    bad = GOOD.replace("009-demo", "demo")
    project = manifest.load(write(tmp_path, bad))
    assert any("id" in error for error in manifest.validate(project))


def test_rejects_output_outside_repo(tmp_path):
    bad = GOOD.replace("media/009-demo/demo.mp4", "../../escape.mp4")
    project = manifest.load(write(tmp_path, bad))
    assert any("escapes" in error for error in manifest.validate(project))
