from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from studio.lib import manifest
from studio.lib.config import ROOT

TEMPLATES = ROOT / "studio" / "templates"


@pytest.mark.parametrize("kind", ["2d", "3d", "game", "game3d"])
def test_template_scaffolds_to_valid_project(tmp_path: Path, kind: str) -> None:
    dest = tmp_path / f"099-sample-{kind}"
    shutil.copytree(TEMPLATES / kind, dest)
    for path in dest.rglob("*"):
        if path.is_file():
            text = path.read_text(encoding="utf-8")
            path.write_text(
                text.replace("__ID__", dest.name).replace("__TITLE__", "Sample"),
                encoding="utf-8",
            )
    project = manifest.load(dest)
    assert project.id == dest.name
    assert manifest.validate(project) == []
