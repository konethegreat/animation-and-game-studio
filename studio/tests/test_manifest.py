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

V2 = """
id: 010-demo
kind: film
type: 3d
title: Demo film
summary: A demo film.
tags: [film]
engine: blender
entry: film.py
render:
  resolution: [1920, 800]
  fps: 24
  frames: 24
  samples: 128
  device: optix
  engine_args: ["--engine", "CYCLES"]
shots:
  - {id: a, entry: a.py, frames: 12}
  - {id: b, entry: b.py, frames: 12}
audio:
  score: audio/score.wav
assets: [polyhaven-studio-hdri]
outputs:
  - media/010-demo/film.mp4
  - media/010-demo/poster.jpg
"""


def write(tmp_path: Path, body: str, extra: tuple[str, ...] = ()) -> Path:
    project = tmp_path / "p"
    project.mkdir(exist_ok=True)
    (project / "project.yaml").write_text(body, encoding="utf-8")
    (project / "render.py").write_text("", encoding="utf-8")
    for name in extra:
        (project / name).write_text("", encoding="utf-8")
    return project


def test_loads_valid_manifest(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.id == "009-demo"
    assert project.fps == 24
    assert project.resolution == (1280, 720)
    assert project.kind == "film"
    assert project.shots[0].id == "main"
    assert project.shots[0].frames == 48
    assert manifest.validate(project) == []


def test_poster_time_defaults_and_parses(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.poster_time == 1.0
    tuned = GOOD.replace("frames: 48", "frames: 48, poster_time: 4.4")
    project = manifest.load(write(tmp_path, tuned))
    assert project.poster_time == 4.4


def test_interactive_defaults_and_parses(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert project.interactive is None
    tuned = manifest.load(write(tmp_path, GOOD + "\ninteractive: bounce\n"))
    assert tuned.interactive == "bounce"
    assert manifest.validate(tuned) == []


def test_rejects_unknown_interactive(tmp_path):
    project = manifest.load(write(tmp_path, GOOD + "\ninteractive: pinball\n"))
    assert any("interactive" in error for error in manifest.validate(project))


def test_gif_settings_default_and_parse(tmp_path):
    project = manifest.load(write(tmp_path, GOOD))
    assert (project.gif_width, project.gif_fps, project.gif_colors, project.gif_dither) == (
        720, 0, 128, "bayer"
    )
    tuned = manifest.load(write(
        tmp_path,
        GOOD + "\ngif: {width: 600, fps: 20, colors: 112, dither: none}\n",
    ))
    assert (tuned.gif_width, tuned.gif_fps, tuned.gif_colors, tuned.gif_dither) == (
        600, 20, 112, "none"
    )
    assert manifest.validate(tuned) == []


def test_rejects_out_of_range_gif_settings(tmp_path):
    for body in (
        "gif: {width: 40}",
        "gif: {fps: 90}",
        "gif: {colors: 400}",
        "gif: {dither: ordered}",
    ):
        project = manifest.load(write(tmp_path, GOOD + "\n" + body + "\n"))
        assert any("gif" in error for error in manifest.validate(project)), body


def test_v2_loads_shots_audio_and_engine_args(tmp_path):
    project = manifest.load(write(tmp_path, V2, ("film.py", "a.py", "b.py")))
    assert project.kind == "film"
    assert [s.id for s in project.shots] == ["a", "b"]
    assert project.audio == {"score": "audio/score.wav"}
    assert project.assets == ["polyhaven-studio-hdri"]
    assert project.samples == 128
    assert project.device == "optix"
    assert project.engine_args == ["--engine", "CYCLES"]


def test_game_type_defaults_to_game_kind(tmp_path):
    game = GOOD.replace("type: 2d", "type: game").replace("engine: python", "engine: godot")
    project = manifest.load(write(tmp_path, game))
    assert project.kind == "game"
    assert manifest.validate(project) == []


def test_rejects_unknown_engine(tmp_path):
    bad = GOOD.replace("engine: python", "engine: quartz")
    project = manifest.load(write(tmp_path, bad))
    assert any("unknown engine" in error for error in manifest.validate(project))


def test_rejects_kind_the_engine_cannot_run(tmp_path):
    bad = GOOD.replace("engine: python", "engine: love")
    project = manifest.load(write(tmp_path, bad))
    assert any("cannot run" in error for error in manifest.validate(project))


def test_engine_is_no_longer_tied_to_type(tmp_path):
    project = manifest.load(write(tmp_path, GOOD.replace("engine: python", "engine: blender")))
    assert manifest.validate(project) == []


def test_rejects_shot_frame_sum_mismatch(tmp_path):
    bad = V2.replace("frames: 24\n  samples", "frames: 30\n  samples")
    project = manifest.load(write(tmp_path, bad, ("film.py", "a.py", "b.py")))
    assert any("shots total" in error for error in manifest.validate(project))


def test_rejects_missing_shot_entry(tmp_path):
    bad = V2.replace("entry: a.py", "entry: missing.py")
    project = manifest.load(write(tmp_path, bad, ("film.py", "b.py")))
    assert any("missing.py" in error for error in manifest.validate(project))


def test_rejects_audio_outside_project(tmp_path):
    bad = V2.replace("audio/score.wav", "../../escape.wav")
    project = manifest.load(write(tmp_path, bad, ("film.py", "a.py", "b.py")))
    assert any("audio" in error and "escapes" in error for error in manifest.validate(project))


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


def test_rejects_unknown_asset_id(tmp_path):
    project = manifest.load(write(tmp_path, V2, ("film.py", "a.py", "b.py")))
    project.assets = ["not-in-catalog"]
    assert any("not in assets/catalog.yaml" in error for error in manifest.validate(project))
