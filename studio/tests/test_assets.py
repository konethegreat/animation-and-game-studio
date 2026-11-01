from pathlib import Path

from studio.lib import assets


def make_asset(tmp_path: Path, **overrides) -> assets.Asset:
    repo = tmp_path / "assets" / "repo"
    repo.mkdir(parents=True, exist_ok=True)
    path = repo / "texture.png"
    path.write_bytes(b"hello")
    values = {
        "id": "texture",
        "lane": "repo",
        "license": "CC0-1.0",
        "source": "https://example.com/texture",
        "path": "assets/repo/texture.png",
        "sha256": assets.sha256_file(path),
        "credit": "Example",
    }
    values.update(overrides)
    return assets.Asset(**values)


def test_verify_accepts_a_valid_repo_asset(tmp_path):
    entry = make_asset(tmp_path)
    assert assets.verify([entry], root=tmp_path, offline=True) == []


def test_verify_rejects_wrong_lane_location(tmp_path):
    entry = make_asset(tmp_path, path="assets/embed/texture.png")
    assert any("lane" in problem for problem in assets.verify([entry], root=tmp_path))


def test_verify_rejects_hash_mismatch(tmp_path):
    entry = make_asset(tmp_path, sha256="0" * 64)
    assert any("hash" in problem for problem in assets.verify([entry], root=tmp_path))


def test_offline_verify_skips_missing_embed_files(tmp_path):
    entry = make_asset(
        tmp_path, lane="embed", path="assets/embed/missing.hdr",
        source="https://example.com/a.hdr",
    )
    assert assets.verify([entry], root=tmp_path, offline=True) == []
    assert any("missing" in problem for problem in assets.verify([entry], root=tmp_path, offline=False))


def test_fetch_copies_a_file_url(tmp_path):
    source = tmp_path / "source.png"
    source.write_bytes(b"asset")
    entry = assets.Asset(
        id="remote", lane="repo", license="CC0-1.0",
        source=source.as_uri(), path="assets/repo/remote.png",
        sha256=assets.sha256_file(source), credit="Example",
    )
    assert assets.fetch([entry], root=tmp_path) == []
    assert (tmp_path / "assets/repo/remote.png").read_bytes() == b"asset"


def test_credits_only_list_repo_assets(tmp_path):
    repo = make_asset(tmp_path)
    embed = make_asset(
        tmp_path, id="hidden", lane="embed", path="assets/embed/x.bin",
        source="https://example.com/x",
    )
    text = assets.credits_markdown([repo, embed])
    assert "texture" in text
    assert "hidden" not in text
    assert "CC0-1.0" in text
