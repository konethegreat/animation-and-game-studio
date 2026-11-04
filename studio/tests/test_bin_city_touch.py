from __future__ import annotations

import subprocess

import pytest

from studio.lib import config

PROJECT = config.ROOT / "projects" / "011-bin-city"


def test_bin_city_touch():
    godot = config.find_tool("godot")
    if not godot:
        pytest.skip("godot not installed")
    result = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(PROJECT),
            "--script",
            "res://tests/_touch.gd",
        ],
        capture_output=True,
        text=True,
        timeout=300,
    )
    output = result.stdout + result.stderr
    assert "failures: 0" in result.stdout, output
