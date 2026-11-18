from contextlib import redirect_stderr, redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys
import zipfile
import zlib

import pytest


ROOT = Path(__file__).resolve().parents[2]
URL = "https://github.com/konethegreat/animation-and-game-studio/releases/download/creator-beta-v1/creator-beta.zip"
HAIR = (
    "afro", "bantu", "braids", "coils", "cornrows", "crop", "fade", "locs",
    "puff", "twists", "waves", "beard_full", "beard_goatee", "beard_short",
)
TEXTURES = (
    "skin_mask.png", "skin_layers.png", "skin_marks.png", "skin_art.png",
    "skin_makeup.png", "skin_cloth.png",
)
MEMBERS = sorted(["probe.glb", *TEXTURES, *(f"hair/{name}.bin" for name in HAIR),
                  "LICENSE.txt", "NOTICE.txt"])


def digest(data):
    return hashlib.sha256(data).hexdigest()


def glb(names=("feat_portrait_b",), second_names=()):
    binary = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
    meshes = []
    for target_names in (names, second_names):
        meshes.append({
            "primitives": [{"attributes": {"POSITION": 0},
                            "targets": [{"POSITION": 0} for _ in target_names]}],
            "extras": {"targetNames": list(target_names)},
        })
    doc = {"asset": {"version": "2.0"}, "meshes": meshes,
           "buffers": [{"byteLength": len(binary)}],
           "bufferViews": [{"buffer": 0, "byteOffset": 0, "byteLength": len(binary)}],
           "accessors": [{"bufferView": 0, "componentType": 5126, "count": 3,
                          "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]}]}
    chunk = json.dumps(doc).encode()
    chunk += b" " * (-len(chunk) % 4)
    return (struct.pack("<4sII", b"glTF", 2, 28 + len(chunk) + len(binary))
            + struct.pack("<II", len(chunk), 0x4E4F534A) + chunk
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def hair(key="feat_portrait_b", *, metadata=None):
    if metadata is None:
        metadata = {"mode": 0, "width": 0.012, "taper": 0.5, "shine": 0.3,
                    "capAlpha": 1.0, "capLow": 0.0, "capHigh": 0.0,
                    "follow": {key: [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0]}}
    encoded = json.dumps(metadata).encode()
    positions = struct.pack("<6f", 0, 1, 0, 0, 1.1, 0)
    tangents = bytes([0, 127, 0, 0] * 2)
    attributes = bytes([0, 255, 128, 64, 255, 255, 128, 64])
    arcs = struct.pack("<2f", 0, 0.1)
    return (struct.pack("<II", 1, 2) + b"\x02\0\0\0" + positions + tangents
            + attributes + arcs + struct.pack("<I", len(encoded)) + encoded)


def png():
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data)))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\0\x80\x80\x80\xff"))
            + chunk(b"IEND", b""))


def source_files(tmp_path):
    source = tmp_path / "source"
    (source / "hair").mkdir(parents=True)
    (source / "probe.glb").write_bytes(glb())
    for name in TEXTURES:
        (source / name).write_bytes(png())
    for name in HAIR:
        (source / "hair" / f"{name}.bin").write_bytes(hair())
    return source


def cli(*args):
    from studio.lib import creator_assets

    stdout, stderr = io.StringIO(), io.StringIO()
    with redirect_stdout(stdout), redirect_stderr(stderr):
        result = creator_assets.main(list(map(str, args)))
    return subprocess.CompletedProcess(args, result, stdout.getvalue(), stderr.getvalue())


def package(source, archive, manifest, url=URL):
    return cli("package", source, archive, "--url", url, "--manifest", manifest)


def test_package_is_deterministic_and_injects_only_runtime_rights(tmp_path):
    source = source_files(tmp_path)
    (source / "private-reference.glb").write_bytes(glb(("ref_private",)))
    (source / "LICENSE.txt").write_text("not the checked-in license")
    (source / "NOTICE.txt").write_text("not the checked-in notice")
    archives = [tmp_path / "first.zip", tmp_path / "second.zip"]
    manifests = [tmp_path / "first.json", tmp_path / "second.json"]
    for archive, manifest in zip(archives, manifests):
        result = package(source, archive, manifest)
        assert result.returncode == 0, result.stderr
        os.utime(source / "probe.glb", (1000000000, 1000000000))
    assert archives[0].read_bytes() == archives[1].read_bytes()
    assert manifests[0].read_bytes() == manifests[1].read_bytes()
    manifest = json.loads(manifests[0].read_text())
    assert set(manifest) == {"version", "url", "sha256", "files"}
    assert manifest["version"] == 1
    assert manifest["url"] == URL
    assert manifest["sha256"] == digest(archives[0].read_bytes())
    assert sorted(manifest["files"]) == MEMBERS
    with zipfile.ZipFile(archives[0]) as archive:
        assert archive.namelist() == MEMBERS
        assert len(archive.namelist()) == 23
        for entry in archive.infolist():
            assert entry.date_time == (1980, 1, 1, 0, 0, 0)
            data = archive.read(entry)
            assert manifest["files"][entry.filename] == {"sha256": digest(data), "size": len(data)}
        for target, original in (("LICENSE.txt", "mhr-LICENSE.txt"),
                                 ("NOTICE.txt", "creator-beta-NOTICE.txt")):
            expected = (ROOT / "assets" / "repo" / original).read_text(encoding="utf-8").encode()
            assert archive.read(target) == expected


@pytest.mark.parametrize("name,data", [
    ("probe.glb", glb(("ref_private",))),
    ("probe.glb", glb(second_names=("ref_hidden",))),
    ("hair/waves.bin", hair("ref_private")),
])
def test_package_rejects_reference_data_before_publication(tmp_path, name, data):
    source = source_files(tmp_path)
    (source / name).write_bytes(data)
    archive, manifest = tmp_path / "bundle.zip", tmp_path / "manifest.json"
    archive.write_bytes(b"existing archive")
    manifest.write_bytes(b"existing manifest")
    result = package(source, archive, manifest)
    assert result.returncode == 1
    assert "ref_" in result.stderr
    assert archive.read_bytes() == b"existing archive"
    assert manifest.read_bytes() == b"existing manifest"


@pytest.mark.parametrize("name", ["probe.glb", "skin_cloth.png", "hair/beard_short.bin"])
def test_package_requires_every_runtime_file(tmp_path, name):
    source = source_files(tmp_path)
    (source / name).unlink()
    archive, manifest = tmp_path / "bundle.zip", tmp_path / "manifest.json"
    result = package(source, archive, manifest)
    assert result.returncode == 1
    assert name.split("/")[-1] in result.stderr
    assert not archive.exists()
    assert not manifest.exists()


@pytest.mark.parametrize("url", [
    "http://github.com/owner/repo/releases/download/v1/assets.zip",
    "https://example.com/assets.zip",
    "https://github.com/owner/repo/releases/latest/download/assets.zip",
    "https://github.com/owner/repo/releases/download/../assets.zip",
    "https://github.com/owner/repo/releases/download/%2e%2e/assets.zip",
    "https://github.com/owner/repo/releases/download/v1/%2fassets.zip",
    "https://github.com/owner/repo/releases/download/v1/assets.zip?token=secret",
    "https://user:password@github.com/owner/repo/releases/download/v1/assets.zip",
    "https://github.com.evil.example/owner/repo/releases/download/v1/assets.zip",
])
def test_package_requires_versioned_https_github_release_url(tmp_path, url):
    source = source_files(tmp_path)
    archive, manifest = tmp_path / "bundle.zip", tmp_path / "manifest.json"
    result = package(source, archive, manifest, url=url)
    assert result.returncode == 1
    assert "URL" in result.stderr
    assert not archive.exists()
    assert not manifest.exists()


@pytest.fixture
def bundle(tmp_path):
    source = source_files(tmp_path)
    archive, manifest = tmp_path / "bundle.zip", tmp_path / "manifest.json"
    result = package(source, archive, manifest)
    assert result.returncode == 0, result.stderr
    return archive, manifest


def restore(bundle, destination):
    archive, manifest = bundle
    return cli("restore", "--archive", archive, "--manifest", manifest,
               "--destination", destination)


def snapshot(directory):
    return {p.relative_to(directory).as_posix(): p.read_bytes()
            for p in directory.rglob("*") if p.is_file()}


def test_local_restore_and_verify_preserve_unrelated_files(tmp_path, bundle):
    destination = tmp_path / "models" / "probe"
    destination.mkdir(parents=True)
    (destination / "keep.txt").write_bytes(b"user data")
    (destination / "probe.glb").write_bytes(b"previous version")
    for _ in range(2):
        result = restore(bundle, destination)
        assert result.returncode == 0, result.stderr
        assert (destination / "keep.txt").read_bytes() == b"user data"
        with zipfile.ZipFile(bundle[0]) as archive:
            for name in MEMBERS:
                assert (destination / name).read_bytes() == archive.read(name)
    result = cli("verify", destination, "--manifest", bundle[1])
    assert result.returncode == 0, result.stderr
    (destination / "skin_mask.png").write_bytes(b"tampered")
    result = cli("verify", destination, "--manifest", bundle[1])
    assert result.returncode == 1
    assert "skin_mask.png" in result.stderr


def rewrite_bundle(bundle, transform, *, repin_files=False):
    archive, manifest_path = bundle
    with zipfile.ZipFile(archive) as original:
        entries = [(info, original.read(info)) for info in original.infolist()]
    entries = transform(entries)
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as changed:
        for info, data in entries:
            changed.writestr(info, data)
    archive.write_bytes(output.getvalue())
    manifest = json.loads(manifest_path.read_text())
    manifest["sha256"] = digest(output.getvalue())
    if repin_files:
        manifest["files"] = {
            info.filename: {"sha256": digest(data), "size": len(data)}
            for info, data in entries
        }
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")


@pytest.mark.parametrize("corruption", [
    "archive_hash", "file_hash", "file_size", "payload", "missing", "extra",
    "traversal", "backslash", "absolute", "drive", "duplicate", "directory", "symlink",
    "license", "notice", "reference_mesh", "reference_hair", "bad_version",
    "missing_manifest_file", "extra_manifest_file", "negative_size", "boolean_size",
    "oversized_payload", "duplicate_json_key", "empty_zip",
])
@pytest.mark.parametrize("existing", [False, True])
def test_restore_rejects_untrusted_bundle_before_any_destination_write(
    tmp_path, bundle, corruption, existing,
):
    archive, manifest_path = bundle
    manifest = json.loads(manifest_path.read_text())
    if corruption == "archive_hash":
        archive.write_bytes(archive.read_bytes() + b"tampering")
    elif corruption in {"file_hash", "file_size", "bad_version", "missing_manifest_file",
                        "extra_manifest_file", "negative_size", "boolean_size", "oversized_payload"}:
        if corruption == "file_hash":
            manifest["files"]["skin_marks.png"]["sha256"] = "0" * 64
        elif corruption == "file_size":
            manifest["files"]["skin_marks.png"]["size"] += 1
        elif corruption == "bad_version":
            manifest["version"] = 2
        elif corruption == "missing_manifest_file":
            del manifest["files"]["probe.glb"]
        elif corruption == "extra_manifest_file":
            manifest["files"]["../escape"] = {"sha256": "0" * 64, "size": 1}
        else:
            manifest["files"]["probe.glb"]["size"] = {
                "negative_size": -1, "boolean_size": True,
                "oversized_payload": 200 * 1024 * 1024 + 1,
            }[corruption]
        manifest_path.write_text(json.dumps(manifest))
    elif corruption == "duplicate_json_key":
        manifest_path.write_text('{"version":1,' + json.dumps(manifest)[1:])
    elif corruption in {"license", "notice", "reference_mesh", "reference_hair", "payload"}:
        name, data = {
            "license": ("LICENSE.txt", b"not Apache-2.0"),
            "notice": ("NOTICE.txt", b"omitted upstream credit"),
            "reference_mesh": ("probe.glb", glb(second_names=("ref_private",))),
            "reference_hair": ("hair/waves.bin", hair("ref_private")),
            "payload": ("skin_marks.png", b"x" * manifest["files"]["skin_marks.png"]["size"]),
        }[corruption]
        rewrite_bundle(bundle, lambda entries: [(i, data if i.filename == name else b)
                                               for i, b in entries],
                       repin_files=corruption != "payload")
    elif corruption == "missing":
        rewrite_bundle(bundle, lambda entries: entries[:-1])
    elif corruption == "empty_zip":
        rewrite_bundle(bundle, lambda entries: [])
    else:
        name = {"extra": "private.glb", "traversal": "../escape", "backslash": "hair\\escape",
                "absolute": "/escape", "drive": "C:/escape", "directory": "hair/",
                "symlink": "hair/waves.bin", "duplicate": "probe.glb"}[corruption]
        entry = zipfile.ZipInfo(name)
        if corruption == "symlink":
            entry.create_system = 3
            entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            rewrite_bundle(bundle, lambda entries: [(entry, b"../../escape") if i.filename == name
                                                   else (i, b) for i, b in entries], repin_files=True)
        elif corruption == "duplicate":
            with pytest.warns(UserWarning, match="Duplicate name"):
                rewrite_bundle(bundle, lambda entries: entries + [(entry, b"duplicate")])
        else:
            rewrite_bundle(bundle, lambda entries: entries + [(entry, b"unexpected")])
    destination = tmp_path / "destination"
    if existing:
        (destination / "hair").mkdir(parents=True)
        (destination / "keep.txt").write_bytes(b"keep")
        (destination / "LICENSE.txt").write_bytes(b"existing license")
        (destination / "hair" / "waves.bin").write_bytes(b"existing hair")
    before = snapshot(destination)
    result = restore(bundle, destination)
    assert result.returncode == 1, result.stdout + result.stderr
    assert result.stderr.strip()
    assert snapshot(destination) == before
    assert destination.exists() == existing


@pytest.mark.parametrize("name,data", [
    ("probe.glb", b"glTF"),
    ("probe.glb", glb()[:-1]),
    ("probe.glb", b"FAIL" + glb()[4:]),
    ("probe.glb", glb()[:16] + b"BIN\0" + glb()[20:]),
    ("hair/afro.bin", b"\0" * 8),
    ("hair/afro.bin", hair()[:-1]),
    ("hair/afro.bin", struct.pack("<II", 1, 3) + hair()[8:]),
    ("hair/afro.bin", hair(metadata={"follow": ["ref_private"]})),
    ("hair/afro.bin", hair(metadata={})),
    ("skin_mask.png", b""),
])
def test_package_rejects_malformed_runtime(tmp_path, name, data):
    source = source_files(tmp_path)
    (source / name).write_bytes(data)
    archive, manifest = tmp_path / "bundle.zip", tmp_path / "manifest.json"
    result = package(source, archive, manifest)
    assert result.returncode == 1
    assert not archive.exists()
    assert not manifest.exists()


@pytest.mark.parametrize("where", ["root", "ancestor", "hair", "file"])
def test_restore_rejects_existing_symlink_escape(tmp_path, bundle, where):
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep.txt").write_bytes(b"outside")
    destination = tmp_path / "destination"
    destination.mkdir()
    if where == "root":
        destination.rmdir()
        link, target = destination, outside
    elif where == "ancestor":
        destination.rmdir()
        link, target = destination, outside
        destination = destination / "nested"
    elif where == "hair":
        link, target = destination / "hair", outside
    else:
        link, target = destination / "LICENSE.txt", outside / "keep.txt"
    try:
        link.symlink_to(target, target_is_directory=where != "file")
    except OSError as error:
        pytest.skip(f"Symlinks unavailable: {error}")
    before = snapshot(outside)
    result = restore(bundle, destination)
    assert result.returncode == 1
    assert "link" in result.stderr.lower() or "reparse" in result.stderr.lower()
    assert snapshot(outside) == before
    assert link.is_symlink()


def test_restore_preflights_late_directory_conflict(tmp_path, bundle):
    destination = tmp_path / "destination"
    (destination / "skin_marks.png").mkdir(parents=True)
    (destination / "LICENSE.txt").write_bytes(b"existing")
    before = snapshot(destination)
    result = restore(bundle, destination)
    assert result.returncode == 1
    assert snapshot(destination) == before


class Response(io.BytesIO):
    def __init__(self, data, length=None):
        super().__init__(data)
        self.headers = {} if length is None else {"Content-Length": str(length)}


def mock_response(monkeypatch, response):
    from studio.lib import creator_assets

    class Opener:
        def open(self, request, *, timeout):
            assert request.full_url == URL
            assert 0 < timeout <= 60
            return response

    monkeypatch.setattr(creator_assets, "build_opener", lambda *handlers: Opener())


def test_https_restore_uses_the_same_validation_as_local_restore(tmp_path, bundle, monkeypatch):
    from studio.lib import creator_assets

    data = bundle[0].read_bytes()
    mock_response(monkeypatch, Response(data, len(data)))
    destination = tmp_path / "remote"
    creator_assets.restore(manifest=bundle[1], destination=destination)
    creator_assets.verify(destination, manifest=bundle[1])
    assert sorted(snapshot(destination)) == MEMBERS


@pytest.mark.parametrize("length", [None, 5, 4])
def test_fetch_bounds_bytes_even_without_a_content_length(monkeypatch, length):
    from studio.lib import creator_assets

    monkeypatch.setattr(creator_assets, "MAX_BYTES", 4)
    mock_response(monkeypatch, Response(b"12345", length))
    with pytest.raises(ValueError, match="size limit"):
        creator_assets._fetch(URL)


def test_fetch_rejects_truncated_response(monkeypatch):
    from studio.lib import creator_assets

    mock_response(monkeypatch, Response(b"short", 20))
    with pytest.raises(ValueError, match="Truncated"):
        creator_assets._fetch(URL)


def test_network_failure_preserves_existing_destination(tmp_path, bundle, monkeypatch):
    from studio.lib import creator_assets

    class FailingOpener:
        def open(self, request, *, timeout):
            raise TimeoutError("network timed out")

    monkeypatch.setattr(creator_assets, "build_opener", lambda *handlers: FailingOpener())
    destination = tmp_path / "destination"
    destination.mkdir()
    (destination / "LICENSE.txt").write_bytes(b"existing")
    before = snapshot(destination)
    with pytest.raises(TimeoutError, match="network timed out"):
        creator_assets.restore(manifest=bundle[1], destination=destination)
    assert snapshot(destination) == before


@pytest.mark.parametrize("url", [
    "http://release-assets.githubusercontent.com/asset.zip",
    "file:///tmp/asset.zip", "https://evil.example/asset.zip",
    "https://github.com@evil.example/asset.zip",
])
def test_release_redirects_cannot_downgrade_or_leave_github(url):
    from urllib.request import Request
    from studio.lib import creator_assets

    with pytest.raises(ValueError, match="HTTPS GitHub"):
        creator_assets._ReleaseRedirect().redirect_request(Request(URL), None, 302, "Found", {}, url)


def test_release_redirect_allows_signed_github_asset():
    from urllib.request import Request
    from studio.lib import creator_assets

    url = "https://release-assets.githubusercontent.com/github-production-release-asset/1/beta.zip?sig=value"
    request = creator_assets._ReleaseRedirect().redirect_request(Request(URL), None, 302, "Found", {}, url)
    assert request.full_url == url


def test_module_command_roundtrip(tmp_path):
    source = source_files(tmp_path)
    archive, manifest = tmp_path / "runtime.zip", tmp_path / "runtime.json"
    destination = tmp_path / "restored"
    commands = [
        ["package", source, archive, "--url", URL, "--manifest", manifest],
        ["restore", "--archive", archive, "--manifest", manifest, "--destination", destination],
        ["verify", destination, "--manifest", manifest],
    ]
    for args in commands:
        result = subprocess.run(
            [sys.executable, "-B", "-m", "studio.lib.creator_assets", *map(str, args)],
            cwd=ROOT, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            capture_output=True, text=True, timeout=30,
        )
        assert result.returncode == 0, result.stderr
    assert sorted(snapshot(destination)) == MEMBERS


@pytest.mark.skipif(sys.platform != "win32", reason="Windows junction protection")
@pytest.mark.parametrize("where", ["root", "ancestor", "hair"])
def test_restore_rejects_windows_junction_escape(tmp_path, bundle, where):
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep.txt").write_bytes(b"outside")
    destination = tmp_path / "destination"
    if where == "hair":
        destination.mkdir()
        link = destination / "hair"
    else:
        link = destination
    if where == "ancestor":
        destination = destination / "nested"
    result = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(outside)],
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, result.stdout + result.stderr
    try:
        before = snapshot(outside)
        result = restore(bundle, destination)
        assert result.returncode == 1
        assert "reparse" in result.stderr.lower()
        assert snapshot(outside) == before
    finally:
        link.rmdir()
