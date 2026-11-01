import json
import struct
from pathlib import Path

from PIL import Image

from studio.lib import verify
from studio.lib.manifest import Project, Shot
from studio.lib.verify import frames, gltf


def make_project(tmp_path: Path) -> Project:
    return Project(
        id="099-verify-test",
        type="3d",
        title="Verify",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(64, 36),
        fps=24,
        frames=3,
        poster_time=0.0,
        outputs=["media/099-verify-test/reel.mp4"],
        kind="film",
        shots=[Shot("main", "scene.py", 3)],
        root=tmp_path,
    )


def test_black_frames_are_flagged(tmp_path):
    out = tmp_path / "frames"
    out.mkdir()
    Image.new("RGB", (64, 36), (0, 0, 0)).save(out / "frame_0001.png")
    problems = frames.scan(out, Shot("main", "scene.py", 1))
    assert any("black" in problem for problem in problems)


def test_frozen_run_is_flagged_unless_still(tmp_path):
    out = tmp_path / "frames"
    out.mkdir()
    for index in range(1, 21):
        Image.new("RGB", (64, 36), (40, 40, 40)).save(out / f"frame_{index:04d}.png")
    problems = frames.scan(out, Shot("main", "scene.py", 20))
    assert any("frozen" in problem for problem in problems)
    assert frames.scan(out, Shot("main", "scene.py", 20, still=True)) == []


def test_glb_header_and_animation_count(tmp_path):
    document = {"asset": {"version": "2.0"}, "animations": [{}]}
    payload = json.dumps(document).encode("utf-8")
    while len(payload) % 4:
        payload += b" "
    total = 12 + 8 + len(payload)
    data = struct.pack("<4sII", b"glTF", 2, total)
    data += struct.pack("<II", len(payload), 0x4E4F534A) + payload
    path = tmp_path / "model.glb"
    path.write_bytes(data)
    info = gltf.inspect(path)
    assert info["animations"] == 1
    assert info["version"] == 2


def test_verify_reports_missing_outputs(tmp_path, monkeypatch):
    project = make_project(tmp_path)
    monkeypatch.setattr(Project, "media_dir", property(lambda self: tmp_path / "media"))
    checks = verify.run(project, stage="render")
    assert any(not check.ok and "missing" in check.detail for check in checks)
