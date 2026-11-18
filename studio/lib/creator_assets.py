"""Package and restore the hash-pinned creator beta runtime and asset notices."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import stat
import struct
import sys
import tempfile
from urllib.parse import unquote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import zipfile


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = ROOT / "assets/creator-beta.json"
DEFAULT_DESTINATION = ROOT / "showcase/public/models/probe"
MAX_BYTES = 200 * 1024 * 1024
TIMEOUT = 30
MEMBERS = tuple(sorted((
    "probe.glb",
    "skin_mask.png", "skin_layers.png", "skin_marks.png", "skin_art.png",
    "skin_makeup.png", "skin_cloth.png",
    "hair/afro.bin", "hair/bantu.bin", "hair/braids.bin", "hair/coils.bin",
    "hair/cornrows.bin", "hair/crop.bin", "hair/fade.bin", "hair/locs.bin",
    "hair/puff.bin", "hair/twists.bin", "hair/waves.bin", "hair/beard_full.bin",
    "hair/beard_goatee.bin", "hair/beard_short.bin", "LICENSE.txt", "NOTICE.txt",
)))
RIGHTS = {
    "LICENSE.txt": ROOT / "assets/repo/mhr-LICENSE.txt",
    "NOTICE.txt": ROOT / "assets/repo/creator-beta-NOTICE.txt",
}


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _json(data: bytes) -> dict:
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    def invalid_constant(value):
        raise ValueError(f"Invalid JSON constant: {value}")

    result = json.loads(data.decode("utf-8"), object_pairs_hook=unique,
                        parse_constant=invalid_constant)
    if not isinstance(result, dict):
        raise ValueError("Expected a JSON object")
    return result


def _release_url(url: str) -> None:
    if not isinstance(url, str) or any(ord(c) < 33 for c in url):
        raise ValueError("Expected a versioned HTTPS GitHub Release URL")
    parts = urlsplit(url)
    path = unquote(parts.path)
    if (parts.scheme != "https" or parts.netloc != "github.com"
            or parts.query or parts.fragment or "\\" in path
            or any(p in {".", ".."} for p in path.split("/"))
            or any(ord(c) < 32 for c in path)
            or not re.fullmatch(r"/[\w.-]+/[\w.-]+/releases/download/[^/]+/[^/]+\.zip", path)):
        raise ValueError("Expected a versioned HTTPS GitHub Release URL")


def _safe_path(path: Path, *, directory: bool = False) -> Path:
    path = path.absolute()
    for item in (*reversed(path.parents), path):
        try:
            info = item.lstat()
        except FileNotFoundError:
            continue
        if (stat.S_ISLNK(info.st_mode)
                or getattr(info, "st_file_attributes", 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT):
            raise ValueError(f"Symlink or reparse point is not allowed: {item}")
        expect_directory = item != path or directory
        if expect_directory and not stat.S_ISDIR(info.st_mode):
            raise ValueError(f"Expected a directory: {item}")
        if not expect_directory and not stat.S_ISREG(info.st_mode):
            raise ValueError(f"Expected a regular file: {item}")
    return path


def _read(path: Path, limit: int = MAX_BYTES) -> bytes:
    path = _safe_path(path)
    with path.open("rb") as handle:
        data = handle.read(limit + 1)
    if len(data) > limit:
        raise ValueError(f"File exceeds size limit: {path}")
    return data


def _rights() -> dict[str, bytes]:
    result = {}
    for name, path in RIGHTS.items():
        data = _read(path, 1024 * 1024).decode("utf-8").replace("\r\n", "\n").encode("utf-8")
        if not data.strip():
            raise ValueError(f"Empty rights file: {path}")
        result[name] = data
    return result


def _glb(data: bytes) -> None:
    if len(data) < 20:
        raise ValueError("probe.glb: truncated GLB header")
    magic, version, length = struct.unpack_from("<4sII", data)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError("probe.glb: invalid GLB header")
    offset, document = 12, None
    while offset < len(data):
        if offset + 8 > len(data):
            raise ValueError("probe.glb: truncated chunk header")
        size, kind = struct.unpack_from("<II", data, offset)
        end = offset + 8 + size
        if size % 4 or end > len(data):
            raise ValueError("probe.glb: invalid chunk length")
        if offset == 12:
            if kind != 0x4E4F534A:
                raise ValueError("probe.glb: first chunk must be JSON")
            document = _json(data[offset + 8:end])
        elif kind != 0x004E4942:
            raise ValueError("probe.glb: unexpected chunk type")
        offset = end
    if document is None or not isinstance(document.get("meshes"), list) or not document["meshes"]:
        raise ValueError("probe.glb: missing meshes")
    for mesh in document["meshes"]:
        if not isinstance(mesh, dict) or not isinstance(mesh.get("extras", {}), dict):
            raise ValueError("probe.glb: malformed mesh extras")
        names = mesh.get("extras", {}).get("targetNames", [])
        if not isinstance(names, list) or any(not isinstance(name, str) for name in names):
            raise ValueError("probe.glb: invalid morph target names")
        for name in names:
            if name.startswith("ref_"):
                raise ValueError(f"probe.glb: forbidden reference morph {name}")
        primitives = mesh.get("primitives")
        if not isinstance(primitives, list) or not primitives:
            raise ValueError("probe.glb: missing mesh primitives")
        for primitive in primitives:
            if not isinstance(primitive, dict):
                raise ValueError("probe.glb: malformed primitive")
            targets = primitive.get("targets", [])
            if not isinstance(targets, list) or len(targets) != len(names):
                raise ValueError("probe.glb: morph targets must have matching names")


def _hair(name: str, data: bytes) -> None:
    if len(data) < 12:
        raise ValueError(f"{name}: truncated hair header")
    strands, points = struct.unpack_from("<II", data)
    counts_end = 8 + strands
    arrays_start = 8 + ((strands + 3) // 4) * 4
    metadata_start = arrays_start + points * 24
    if not strands or not points or metadata_start + 4 > len(data):
        raise ValueError(f"{name}: invalid hair counts or truncated arrays")
    counts = data[8:counts_end]
    if (any(count < 2 for count in counts) or sum(counts) != points
            or any(data[counts_end:arrays_start])):
        raise ValueError(f"{name}: invalid strand counts or padding")
    size = struct.unpack_from("<I", data, metadata_start)[0]
    if not size or metadata_start + 4 + size != len(data):
        raise ValueError(f"{name}: invalid hair metadata length")
    metadata = _json(data[metadata_start + 4:])
    follow = metadata.get("follow")
    if not isinstance(follow, dict):
        raise ValueError(f"{name}: missing hair follow metadata")
    for key in follow:
        if key.startswith("ref_"):
            raise ValueError(f"{name}: forbidden reference follow key {key}")


def _validate(payload: dict[str, bytes]) -> None:
    if set(payload) != set(MEMBERS):
        raise ValueError("Runtime members must match the explicit allowlist")
    if any(not data for data in payload.values()) or sum(map(len, payload.values())) > MAX_BYTES:
        raise ValueError("Runtime payload is empty or exceeds the 200 MiB size limit")
    for name, expected in _rights().items():
        if payload[name] != expected:
            raise ValueError(f"{name}: rights do not match the checked-in source")
    _glb(payload["probe.glb"])
    for name in MEMBERS:
        if name.startswith("hair/"):
            _hair(name, payload[name])


def _manifest(path: Path) -> dict:
    manifest = _json(_read(path, 1024 * 1024))
    if (set(manifest) != {"version", "url", "sha256", "files"}
            or type(manifest["version"]) is not int or manifest["version"] != 1):
        raise ValueError("Expected creator asset manifest version 1")
    _release_url(manifest["url"])
    files = manifest["files"]
    if not isinstance(files, dict) or set(files) != set(MEMBERS):
        raise ValueError("Manifest files must match the explicit allowlist")
    hashes = [manifest["sha256"]]
    total = 0
    for name, entry in files.items():
        if not isinstance(entry, dict) or set(entry) != {"sha256", "size"}:
            raise ValueError(f"{name}: invalid manifest file entry")
        size = entry["size"]
        if type(size) is not int or not 0 < size <= MAX_BYTES:
            raise ValueError(f"{name}: invalid manifest size")
        total += size
        hashes.append(entry["sha256"])
    if total > MAX_BYTES:
        raise ValueError("Manifest payload exceeds the 200 MiB size limit")
    if any(not isinstance(h, str) or not re.fullmatch(r"[a-f0-9]{64}", h) for h in hashes):
        raise ValueError("Manifest requires lowercase SHA-256 hashes")
    return manifest


def _check_hashes(payload: dict[str, bytes], manifest: dict) -> None:
    for name, data in payload.items():
        entry = manifest["files"][name]
        if len(data) != entry["size"] or _sha256(data) != entry["sha256"]:
            raise ValueError(f"{name}: size or SHA-256 mismatch")


class _ReleaseRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parts = urlsplit(newurl)
        if (parts.scheme != "https" or parts.netloc not in {
                "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"}):
            raise ValueError("Release redirect must remain on HTTPS GitHub asset hosts")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _fetch(url: str) -> bytes:
    _release_url(url)
    request = Request(url, headers={"Accept": "application/octet-stream",
                                    "User-Agent": "studio-creator-assets"})
    with build_opener(_ReleaseRedirect()).open(request, timeout=TIMEOUT) as response:
        length = response.headers.get("Content-Length")
        if length is not None and not 0 <= int(length) <= MAX_BYTES:
            raise ValueError("Release archive exceeds the 200 MiB size limit")
        data = response.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES:
            raise ValueError("Release archive exceeds the 200 MiB size limit")
        if length is not None and len(data) != int(length):
            raise ValueError("Truncated release archive")
        return data


def _unpack(data: bytes, manifest: dict) -> dict[str, bytes]:
    if _sha256(data) != manifest["sha256"]:
        raise ValueError("Archive SHA-256 mismatch")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        entries = archive.infolist()
        names = [entry.filename for entry in entries]
        if len(names) != len(set(names)) or set(names) != set(MEMBERS):
            raise ValueError("Archive contains duplicate, missing, or unexpected members")
        for entry in entries:
            kind = stat.S_IFMT(entry.external_attr >> 16)
            if (entry.orig_filename != entry.filename or entry.is_dir()
                    or kind not in {0, stat.S_IFREG} or entry.external_attr & 0x10
                    or entry.flag_bits & 1
                    or entry.compress_type not in {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED}):
                raise ValueError(f"{entry.filename}: archive member is not a regular file")
            if entry.file_size != manifest["files"][entry.filename]["size"]:
                raise ValueError(f"{entry.filename}: archive member size mismatch")
        payload = {entry.filename: archive.read(entry) for entry in entries}
    _check_hashes(payload, manifest)
    _validate(payload)
    return payload


def _write(path: Path, data: bytes) -> None:
    path = _safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".creator-", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(data)
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def package(source: Path, archive: Path, *, url: str,
            manifest: Path = DEFAULT_MANIFEST) -> None:
    _release_url(url)
    source = _safe_path(Path(source), directory=True)
    archive, manifest = _safe_path(Path(archive)), _safe_path(Path(manifest))
    if archive == manifest:
        raise ValueError("Archive and manifest must be different files")
    payload = _rights()
    remaining = MAX_BYTES - sum(map(len, payload.values()))
    for name in MEMBERS:
        if name not in RIGHTS:
            payload[name] = _read(source / name, remaining)
            remaining -= len(payload[name])
    _validate(payload)
    output = io.BytesIO()
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for name in MEMBERS:
            entry = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            bundle.writestr(entry, payload[name], compresslevel=9)
    data = output.getvalue()
    if len(data) > MAX_BYTES:
        raise ValueError("Archive exceeds the 200 MiB size limit")
    description = {
        "version": 1, "url": url, "sha256": _sha256(data),
        "files": {name: {"sha256": _sha256(payload[name]), "size": len(payload[name])}
                  for name in MEMBERS},
    }
    _write(archive, data)
    _write(manifest, (json.dumps(description, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def restore(*, archive: Path | None = None, manifest: Path = DEFAULT_MANIFEST,
            destination: Path = DEFAULT_DESTINATION) -> None:
    description = _manifest(Path(manifest))
    data = _read(Path(archive)) if archive is not None else _fetch(description["url"])
    payload = _unpack(data, description)
    destination = _safe_path(Path(destination), directory=True)
    for name in MEMBERS:
        _safe_path(destination / name)
    for name in MEMBERS:
        _write(destination / name, payload[name])


def verify(directory: Path, *, manifest: Path = DEFAULT_MANIFEST) -> None:
    description = _manifest(Path(manifest))
    directory = _safe_path(Path(directory), directory=True)
    payload = {name: _read(directory / name, description["files"][name]["size"])
               for name in MEMBERS}
    _check_hashes(payload, description)
    _validate(payload)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    pack = commands.add_parser("package", help="Build a deterministic runtime ZIP and manifest")
    pack.add_argument("source", type=Path)
    pack.add_argument("archive", type=Path)
    pack.add_argument("--url", required=True)
    unpack = commands.add_parser("restore", help="Verify every byte and restore runtime assets")
    unpack.add_argument("--archive", type=Path, help="Use a local archive without network access")
    unpack.add_argument("--destination", type=Path, default=DEFAULT_DESTINATION)
    check = commands.add_parser("verify", help="Verify runtime files in an existing directory")
    check.add_argument("directory", type=Path)
    for command in (pack, unpack, check):
        command.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    args = vars(parser.parse_args(argv))
    command = args.pop("command")
    try:
        {"package": package, "restore": restore, "verify": verify}[command](**args)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"creator assets: {error}", file=sys.stderr)
        return 1
    print(f"Creator assets {command}: verified {len(MEMBERS)} runtime files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
