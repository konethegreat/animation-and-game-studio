from studio.lib import config


def test_root_points_at_repo():
    assert (config.ROOT / "studio").is_dir()


def test_doctor_reports_every_tool_candidate():
    rows = config.doctor()
    assert {r["name"] for r in rows} == set(config.CANDIDATES)
    assert all("ok" in r for r in rows)


def test_version_args_for_non_gnu_tools():
    assert config.VERSION_ARGS["ffmpeg"] == "-version"
    assert config.VERSION_ARGS["unity"] == "-version"
    assert config.VERSION_ARGS["unreal"] == "-version"
    assert config.VERSION_ARGS.get("blender", "--version") == "--version"


def test_gui_tools_skip_version_probe(tmp_path):
    exe = tmp_path / "GDevelop.exe"
    exe.write_text("")
    assert config.tool_version("gdevelop", exe) == ""
    assert config.tool_version("unity_hub", exe) == ""


def test_gpu_name_returns_a_string(monkeypatch):
    monkeypatch.setattr(config.shutil, "which", lambda name: None)
    assert config.gpu_name() == ""
