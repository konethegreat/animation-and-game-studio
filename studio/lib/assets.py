from __future__ import annotations

import hashlib
import json
import urllib.request
from dataclasses import dataclass
from pathlib import Path

import yaml

from .config import ROOT

LANES = {
    "repo": "assets/repo",
    "embed": "assets/embed",
    "private": "assets/private",
}
CATALOG = ROOT / "assets" / "catalog.yaml"
NOTICES = ROOT / "THIRD_PARTY_NOTICES.md"
CREDITS_TS = ROOT / "showcase" / "src" / "credits.generated.ts"


@dataclass(frozen=True)
class Asset:
    id: str
    lane: str
    license: str
    source: str
    path: str
    sha256: str
    credit: str = ""
    download: str = ""


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path | None = None) -> list[Asset]:
    catalog = path or CATALOG
    if not catalog.exists():
        return []
    data = yaml.safe_load(catalog.read_text(encoding="utf-8")) or []
    return [Asset(**entry) for entry in data]


def ids() -> set[str]:
    return {entry.id for entry in load()}


def verify(entries: list[Asset] | None = None, root: Path | None = None, offline: bool = True) -> list[str]:
    root = root or ROOT
    entries = entries if entries is not None else load()
    problems: list[str] = []
    for entry in entries:
        if entry.lane not in LANES:
            problems.append(f"{entry.id}: unknown lane {entry.lane}")
            continue
        if not entry.license or not entry.source or not entry.sha256:
            problems.append(f"{entry.id}: license, source and sha256 are required")
        prefix = LANES[entry.lane]
        if not entry.path.startswith(prefix + "/"):
            problems.append(f"{entry.id}: lane {entry.lane} path must live under {prefix}/")
            continue
        file = root / entry.path
        if not file.exists():
            if entry.lane == "repo":
                problems.append(f"{entry.id}: missing {entry.path}")
            elif not offline:
                problems.append(f"{entry.id}: missing {entry.path}")
            continue
        if sha256_file(file) != entry.sha256:
            problems.append(f"{entry.id}: hash mismatch for {entry.path}")
    return problems


def fetch(entries: list[Asset] | None = None, root: Path | None = None) -> list[str]:
    root = root or ROOT
    entries = entries if entries is not None else load()
    problems: list[str] = []
    for entry in entries:
        if entry.lane == "private":
            problems.append(f"{entry.id}: private assets are never fetched")
            continue
        target = root / entry.path
        if target.exists() and sha256_file(target) == entry.sha256:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        url = entry.download or entry.source
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                target.write_bytes(response.read())
        except Exception as exc:
            problems.append(f"{entry.id}: download failed: {exc}")
            continue
        if sha256_file(target) != entry.sha256:
            target.unlink(missing_ok=True)
            problems.append(f"{entry.id}: downloaded hash mismatch")
    return problems


COMPONENTS = [
    ("Three.js", "three.js authors", "MIT", "https://github.com/mrdoob/three.js"),
    ("Vite", "Vite contributors", "MIT", "https://github.com/vitejs/vite"),
    ("TypeScript", "Microsoft", "Apache-2.0", "https://github.com/microsoft/TypeScript"),
    ("Fontsource", "Fontsource", "MIT", "https://github.com/fontsource/fontsource"),
    ("Manrope", "Mikhail Sharanda", "OFL-1.1", "https://github.com/sharanda/manrope"),
    ("IBM Plex Mono", "IBM", "OFL-1.1", "https://github.com/IBM/plex"),
    ("Godot Engine", "Godot Engine contributors", "MIT", "https://github.com/godotengine/godot"),
    ("Blender", "Blender Foundation", "GPL-2.0-or-later", "https://www.blender.org"),
    ("FFmpeg", "FFmpeg team", "LGPL-2.1-or-later", "https://ffmpeg.org"),
    ("Python", "Python Software Foundation", "PSF-2.0", "https://www.python.org"),
]


def credits_markdown(entries: list[Asset] | None = None) -> str:
    entries = entries if entries is not None else load()
    public = sorted((entry for entry in entries if entry.lane == "repo"), key=lambda item: item.id)
    lines = [
        "# Third party notices",
        "",
        "This repository is original work by Kone Tshivhinda. See LICENSE.",
        "",
        "The assets and components below keep the licences shown and remain the property of "
        "their authors. Those licences do not grant any rights to the original work around them.",
        "",
        "## Assets in the repo lane",
        "",
        "| Asset | Author | License | Source |",
        "| --- | --- | --- | --- |",
    ]
    for entry in public:
        lines.append(
            f"| {entry.id} | {entry.credit or 'Unknown'} | {entry.license} | {entry.source} |"
        )
    lines += [
        "",
        "## Build tools and libraries",
        "",
        "| Component | Author | License | Source |",
        "| --- | --- | --- | --- |",
    ]
    for name, author, license_name, source in COMPONENTS:
        lines.append(f"| {name} | {author} | {license_name} | {source} |")
    return "\n".join(lines) + "\n"


def write_credits(entries: list[Asset] | None = None) -> Path:
    entries = entries if entries is not None else load()
    NOTICES.write_text(credits_markdown(entries), encoding="utf-8")
    public = sorted((entry for entry in entries if entry.lane == "repo"), key=lambda item: item.id)
    payload = json.dumps([
        {"id": entry.id, "author": entry.credit, "license": entry.license, "source": entry.source}
        for entry in public
    ], indent=2)
    CREDITS_TS.parent.mkdir(parents=True, exist_ok=True)
    CREDITS_TS.write_text(
        "// generated by studio assets credits, do not edit\n"
        "export type Credit = { id: string; author: string; license: string; source: string };\n"
        f"export const credits: Credit[] = {payload};\n",
        encoding="utf-8",
    )
    return NOTICES
