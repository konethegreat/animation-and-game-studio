from studio.lib import config


def test_root_points_at_repo():
    assert (config.ROOT / "studio").is_dir()


def test_doctor_reports_all_tools():
    rows = config.doctor()
    assert {r["name"] for r in rows} == {"blender", "godot", "ffmpeg"}
    assert all("ok" in r for r in rows)
