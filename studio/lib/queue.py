from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from . import media


def source_hash(project, shot) -> str:
    digest = hashlib.sha256()
    digest.update((project.root / shot.entry).read_bytes())
    digest.update(project.engine.encode("utf-8"))
    digest.update("|".join(project.engine_args).encode("utf-8"))
    return digest.hexdigest()


def settings_hash(project, shot, width: int, height: int, preview: bool) -> str:
    payload = {
        "frames": shot.frames,
        "width": width,
        "height": height,
        "fps": project.fps,
        "preview": preview,
        "device": project.device,
        "samples": project.samples,
    }
    return hashlib.sha256(
        json.dumps(payload, sort_keys=True).encode("utf-8")
    ).hexdigest()


def load_state(path: Path) -> dict:
    if not path.exists():
        return {"shots": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"shots": {}}
    if not isinstance(data, dict) or not isinstance(data.get("shots"), dict):
        return {"shots": {}}
    return data


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2), encoding="utf-8")


def mark_complete(state: dict, shot, source: str, settings: str) -> None:
    state.setdefault("shots", {})[shot.id] = {
        "frames": shot.frames,
        "source": source,
        "settings": settings,
        "updated": datetime.now(timezone.utc).isoformat(),
    }


def shot_complete(out: Path, shot, state: dict, source: str, settings: str) -> bool:
    entry = (state.get("shots") or {}).get(shot.id)
    if not isinstance(entry, dict):
        return False
    if entry.get("frames") != shot.frames:
        return False
    if entry.get("source") != source or entry.get("settings") != settings:
        return False
    files = sorted(out.glob("frame_*.png"))
    return len(files) == shot.frames and all(path.stat().st_size > 0 for path in files)
