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


def test_probe_reports_found_tool(monkeypatch, tmp_path):
    fake = tmp_path / "Unity.exe"
    fake.write_text("", encoding="utf-8")
    monkeypatch.setattr(config, "find_tool", lambda name: fake)
    monkeypatch.setattr(config, "tool_version", lambda name, exe: "6000.3.27f2")
    probe = engines.get("unity").probe()
    assert probe.ok is True
    assert probe.version == "6000.3.27f2"
    assert probe.path == str(fake)
