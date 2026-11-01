import pytest

from studio.lib import media


def test_budget_rejects_oversize(tmp_path, monkeypatch):
    path = tmp_path / "a.gif"
    path.write_bytes(b"x" * 100)
    monkeypatch.setattr(media, "BUDGET_MB", {".gif": 0.00001})
    with pytest.raises(ValueError, match="budget"):
        media.check_budget(path)


def test_parse_fps():
    assert media.parse_fps("24/1") == 24.0
    assert media.parse_fps("30000/1001") == pytest.approx(29.97, abs=0.01)


def test_budget_allows_small(tmp_path):
    path = tmp_path / "a.mp4"
    path.write_bytes(b"x" * 100)
    media.check_budget(path)


def test_unknown_suffix_is_ignored(tmp_path):
    path = tmp_path / "a.xyz"
    path.write_bytes(b"x" * 10_000_000)
    media.check_budget(path)
