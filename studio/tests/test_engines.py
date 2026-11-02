from studio.lib import config, engines


def test_registry_knows_every_engine():
    assert set(engines.names()) == {
        "python", "blender", "godot", "unity",
        "unreal", "gdevelop", "love", "monogame",
    }


def test_registry_checks_supported_kinds():
    assert engines.supports("godot", "game")
    assert engines.supports("blender", "film")
    assert not engines.supports("love", "film")
    assert not engines.supports("monogame", "film")


def test_probe_reports_missing_tool(monkeypatch):
    monkeypatch.setattr(config, "find_tool", lambda name: None)
    probe = engines.get("unity").probe()
    assert probe.name == "unity"
    assert probe.ok is False
    assert probe.blockers == ("unity not found",)


def test_unity_reports_licence_blocker(monkeypatch, tmp_path):
    fake = tmp_path / "Unity.exe"
    fake.write_text("", encoding="utf-8")
    monkeypatch.setattr(config, "find_tool", lambda name: fake)
    monkeypatch.setattr(config, "tool_version", lambda name, exe: "6000.3.27f2")
    monkeypatch.setattr("studio.lib.engines.base.UNITY_LICENSE_DIRS", (tmp_path / "exists", tmp_path / "legacy"))
    probe = engines.get("unity").probe()
    assert probe.ok is False
    assert "licence" in probe.blockers[0]
    assert probe.version == "6000.3.27f2"


def test_probe_reports_found_tool(monkeypatch, tmp_path):
    fake = tmp_path / "Unity.exe"
    fake.write_text("", encoding="utf-8")
    licenses = tmp_path / "licenses"
    licenses.mkdir()
    (licenses / "UnityEntitlementLicense.xml").write_text("licence", encoding="utf-8")
    monkeypatch.setattr(config, "find_tool", lambda name: fake)
    monkeypatch.setattr(config, "tool_version", lambda name, exe: "6000.3.27f2")
    monkeypatch.setattr("studio.lib.engines.base.UNITY_LICENSE_DIRS", (licenses, tmp_path / "legacy"))
    probe = engines.get("unity").probe()
    assert probe.ok is True
    assert probe.version == "6000.3.27f2"
    assert probe.path == str(fake)


import sys
from pathlib import Path

from studio.lib.manifest import Project, Shot


def make_project(tmp_path: Path) -> Project:
    (tmp_path / "scene.py").write_text("", encoding="utf-8")
    return Project(
        id="099-adapter-test",
        type="3d",
        title="Adapter",
        summary="",
        tags=[],
        engine="blender",
        entry="scene.py",
        resolution=(320, 180),
        fps=24,
        frames=2,
        poster_time=1.0,
        outputs=["media/099-adapter-test/reel.mp4"],
        root=tmp_path,
        kind="film",
        shots=[Shot("main", "scene.py", 2)],
    )


def test_python_command_uses_shot_frames(tmp_path):
    from studio.lib.engines.pillow import PythonAdapter

    project = make_project(tmp_path)
    project.engine = "python"
    shot = Shot("main", "scene.py", 2)
    cmd = PythonAdapter().command(project, shot, tmp_path / "frames")
    assert cmd[0] == sys.executable
    assert "--frames" in cmd
    assert cmd[cmd.index("--frames") + 1] == "2"


def test_blender_command_includes_engine_args(tmp_path, monkeypatch):
    from studio.lib.engines.blender import BlenderAdapter

    project = make_project(tmp_path)
    project.engine_args = ["--engine", "CYCLES"]
    monkeypatch.setattr("studio.lib.engines.blender.config.find_tool", lambda name: Path("C:/blender.exe"))
    cmd = BlenderAdapter().command(project, project.shots[0], tmp_path / "frames")
    assert cmd[0] == str(Path("C:/blender.exe"))
    assert cmd[1:3] == ["-b", "--python"]
    assert cmd[-2:] == ["--engine", "CYCLES"]
    assert cmd[cmd.index("--frames-end") + 1] == "2"


def test_blender_export_command_targets_glb(tmp_path, monkeypatch):
    from studio.lib.engines.blender import BlenderAdapter

    project = make_project(tmp_path)
    monkeypatch.setattr("studio.lib.engines.blender.config.find_tool", lambda name: Path("C:/blender.exe"))
    cmd = BlenderAdapter().command_export(project, tmp_path / "out.glb")
    assert cmd[cmd.index("--export-glb") + 1] == str(tmp_path / "out.glb")


def test_godot_build_delegates_to_export_web(tmp_path, monkeypatch):
    from studio.lib.engines.godot import GodotAdapter

    project = make_project(tmp_path)
    project.engine = "godot"
    project.kind = "game"
    calls = []
    monkeypatch.setattr(
        "studio.lib.engines.godot.godot_tool.export_web",
        lambda root, out: calls.append((root, out)),
    )
    target = GodotAdapter().build(project, tmp_path / "build" / "web")
    assert calls == [(tmp_path, tmp_path / "build" / "web")]
    assert target == tmp_path / "build" / "web"


def test_godot_windows_build_packages_a_zip(tmp_path, monkeypatch):
    from studio.lib.engines.godot import GodotAdapter

    project = make_project(tmp_path)
    project.engine = "godot"
    project.kind = "game"
    calls = []
    monkeypatch.setattr(
        "studio.lib.engines.godot.godot_tool.export_windows",
        lambda root, out, exe: calls.append((root, out, exe)) or tmp_path / "build" / "099-adapter-test-windows.zip",
    )
    target = GodotAdapter().build(project, tmp_path / "build" / "windows", target="windows")
    assert calls == [(tmp_path, tmp_path / "build" / "windows", "099-adapter-test.exe")]
    assert target.name == "099-adapter-test-windows.zip"


def test_godot_rejects_an_unknown_target(tmp_path):
    import pytest

    from studio.lib.engines.godot import GodotAdapter

    project = make_project(tmp_path)
    project.engine = "godot"
    project.kind = "game"
    with pytest.raises(ValueError):
        GodotAdapter().build(project, tmp_path / "build" / "linux", target="linux")


def test_zip_dir_keeps_flat_entries(tmp_path):
    import zipfile

    from studio.lib.godot import zip_dir

    source = tmp_path / "windows"
    source.mkdir()
    (source / "BinCity.exe").write_bytes(b"exe")
    (source / "BinCity.pck").write_bytes(b"pck")
    dest = zip_dir(source, tmp_path / "BinCity-windows.zip")
    with zipfile.ZipFile(dest) as archive:
        assert archive.namelist() == ["BinCity.exe", "BinCity.pck"]


from studio import studio as cli


def test_doctor_deep_prints_adapters(monkeypatch, capsys):
    from studio.lib.engines.base import Probe

    monkeypatch.setattr(cli.config, "doctor", lambda: [
        {"name": "blender", "path": "C:/blender.exe", "version": "4.5.10", "ok": True},
    ])
    monkeypatch.setattr(cli.engines, "probe_all", lambda: [
        Probe("blender", "blender", "C:/blender.exe", "4.5.10", ("film",), True),
        Probe("unity", "unity", "", "", ("film", "game"), False, ("unity not found",)),
    ])
    code = cli.main(["doctor", "--deep"])
    out = capsys.readouterr().out
    assert code == 0
    assert "adapters" in out
    assert "unity" in out
    assert "unity not found" in out
