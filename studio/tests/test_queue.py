from pathlib import Path

import pytest
from PIL import Image

from studio.lib import queue
from studio.lib.manifest import Project, Shot


def make_project(tmp_path: Path) -> Project:
    (tmp_path / "scene.py").write_text("print('a')", encoding="utf-8")
    return Project(
        id="099-queue-test",
        type="3d",
        title="Queue",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(320, 180),
        fps=24,
        frames=2,
        poster_time=1.0,
        outputs=["media/099-queue-test/reel.mp4"],
        kind="film",
        shots=[Shot("main", "scene.py", 2)],
        root=tmp_path,
    )


def test_state_roundtrip(tmp_path):
    path = tmp_path / "state.json"
    state = {"shots": {"main": {"frames": 2}}}
    queue.save_state(path, state)
    assert queue.load_state(path) == state


def test_source_hash_changes_with_file(tmp_path):
    project = make_project(tmp_path)
    shot = project.shots[0]
    first = queue.source_hash(project, shot)
    (tmp_path / "scene.py").write_text("print('b')", encoding="utf-8")
    assert queue.source_hash(project, shot) != first


def test_settings_hash_changes_with_resolution(tmp_path):
    project = make_project(tmp_path)
    shot = project.shots[0]
    assert queue.settings_hash(project, shot, 320, 180, False) != queue.settings_hash(
        project, shot, 160, 90, False
    )


def test_complete_requires_state_and_frames(tmp_path):
    project = make_project(tmp_path)
    shot = project.shots[0]
    out = tmp_path / "frames"
    out.mkdir()
    source = queue.source_hash(project, shot)
    settings = queue.settings_hash(project, shot, 320, 180, False)
    state = {"shots": {"main": {"frames": 2, "source": source, "settings": settings}}}
    assert queue.shot_complete(out, shot, state, source, settings) is False
    for index in (1, 2):
        Image.new("RGB", (2, 2), (40, 40, 40)).save(out / f"frame_{index:04d}.png")
    assert queue.shot_complete(out, shot, state, source, settings) is True
    assert queue.shot_complete(out, shot, state, source + "x", settings) is False


from studio.lib import render


@pytest.fixture(autouse=True)
def skip_verify(monkeypatch):
    monkeypatch.setattr(render.verify, "run", lambda *args, **kwargs: [])


class FakeAdapter:
    name = "blender"

    def __init__(self):
        self.calls = 0

    def prepare(self, project):
        return None

    def render(self, project, shot, out):
        self.calls += 1
        out.mkdir(parents=True, exist_ok=True)
        for index in range(1, shot.frames + 1):
            Image.new("RGB", (2, 2), (index * 20, 40, 80)).save(out / f"frame_{index:04d}.png")
        return shot.frames


def test_render_resumes_and_skips_complete_shots(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    media_dir = tmp_path / "media"
    monkeypatch.setattr(Project, "media_dir", property(lambda self: media_dir))
    fake = FakeAdapter()
    monkeypatch.setattr(render.engines, "get", lambda name: fake)
    monkeypatch.setattr(render.media, "encode_project", lambda *args, **kwargs: {"mp4": tmp_path / "out.mp4"})

    frames = render.run(project)

    assert fake.calls == 1
    assert (frames / "frame_0001.png").exists()
    assert (frames / "frame_0002.png").exists()

    render.run(project)

    assert fake.calls == 1


def test_render_single_shot_invalidates_when_source_changes(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    media_dir = tmp_path / "media"
    monkeypatch.setattr(Project, "media_dir", property(lambda self: media_dir))
    fake = FakeAdapter()
    monkeypatch.setattr(render.engines, "get", lambda name: fake)
    encoded = []
    monkeypatch.setattr(render.media, "encode_project", lambda *args, **kwargs: encoded.append(1))

    render.run(project)
    (tmp_path / "scene.py").write_text("print('changed')", encoding="utf-8")
    render.run(project)

    assert fake.calls == 2


def test_render_partial_shot_does_not_encode(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    project.shots = [Shot("a", "scene.py", 1), Shot("b", "scene.py", 1)]
    project.frames = 2
    media_dir = tmp_path / "media"
    monkeypatch.setattr(Project, "media_dir", property(lambda self: media_dir))
    fake = FakeAdapter()
    monkeypatch.setattr(render.engines, "get", lambda name: fake)
    encoded = []
    monkeypatch.setattr(render.media, "encode_project", lambda *args, **kwargs: encoded.append(1))

    render.run(project, shot_ids=["a"])

    assert fake.calls == 1
    assert encoded == []
