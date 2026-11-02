from studio.lib import publish
from studio.lib.manifest import Project, Shot


def test_entry_uses_declared_media_names(tmp_path, monkeypatch):
    for name in ("maker.mp4", "maker.webm", "poster.jpg"):
        path = tmp_path / name
        path.write_bytes(b"x")
    project = Project(
        id="010-maker",
        type="3d",
        title="Maker",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(1920, 800),
        fps=24,
        frames=24,
        poster_time=0.0,
        outputs=[
            "media/010-maker/maker.mp4",
            "media/010-maker/maker.webm",
            "media/010-maker/poster.jpg",
        ],
        kind="film",
        shots=[Shot("main", "scene.py", 24)],
        root=tmp_path,
    )
    monkeypatch.setattr(publish, "ROOT", tmp_path)
    (tmp_path / "media" / "010-maker").mkdir(parents=True)
    for name in ("maker.mp4", "maker.webm", "poster.jpg"):
        (tmp_path / "media" / "010-maker" / name).write_bytes(b"x")
    monkeypatch.setattr(publish.media, "probe", lambda path: {"duration": 12.0})
    entry = publish.build_entry(project)
    assert entry["kind"] == "film"
    assert entry["mp4"] == "media/010-maker/maker.mp4"
    assert entry["webm"] == "media/010-maker/maker.webm"
    assert "interactive" not in entry


def test_entry_carries_the_lab_choice(tmp_path, monkeypatch):
    (tmp_path / "poster.jpg").write_bytes(b"x")
    (tmp_path / "media" / "001-bounce").mkdir(parents=True)
    (tmp_path / "media" / "001-bounce" / "poster.jpg").write_bytes(b"x")
    project = Project(
        id="001-bounce",
        type="2d",
        title="Paper City",
        summary="",
        tags=[],
        engine="python",
        entry="render.py",
        resolution=(1920, 1080),
        fps=24,
        frames=24,
        poster_time=0.0,
        outputs=["media/001-bounce/poster.jpg"],
        kind="film",
        shots=[Shot("main", "render.py", 24)],
        interactive="bounce",
        root=tmp_path,
    )
    monkeypatch.setattr(publish, "ROOT", tmp_path)
    entry = publish.build_entry(project)
    assert entry["interactive"] == "bounce"
