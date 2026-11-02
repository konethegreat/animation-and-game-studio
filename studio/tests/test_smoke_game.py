from __future__ import annotations

import subprocess

import pytest

from studio.lib import config

PROJECT = config.ROOT / "projects" / "011-bin-city"


def test_bin_city_carry_and_unload():
    godot = config.find_tool("godot")
    if not godot:
        pytest.skip("godot not installed")
    result = subprocess.run(
        [str(godot), "--headless", "--path", str(PROJECT), "--script", "res://tests/_smoke.gd"],
        capture_output=True,
        text=True,
        timeout=180,
    )
    output = result.stdout + result.stderr
    assert "failures: 0" in result.stdout, output
