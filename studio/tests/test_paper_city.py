from __future__ import annotations

import importlib.util
from pathlib import Path

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parents[2]
RENDER = ROOT / "projects" / "001-2d-bounce" / "render.py"

spec = importlib.util.spec_from_file_location("paper_city", RENDER)
paper_city = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(paper_city)


@pytest.mark.parametrize("t", [0.0, 0.07, 0.25, 0.5, 0.73, 0.99])
def test_ball_state_is_periodic(t: float) -> None:
    first = paper_city.ball_state(t)
    second = paper_city.ball_state(t + 1.0)
    for key in first:
        assert first[key] == pytest.approx(second[key], abs=1e-9)


def test_ball_lands_and_leaves_the_ground() -> None:
    samples = [paper_city.ball_state(i / 240) for i in range(240)]
    heights = [state["z"] for state in samples]
    assert min(heights) == pytest.approx(0.0, abs=1e-9)
    assert max(heights) > 0.6
    contacts = [state for state in samples if state["contact"] > 0.0]
    assert 0 < len(contacts) < len(samples)


def test_squash_stays_inside_the_paper() -> None:
    for i in range(240):
        state = paper_city.ball_state(i / 240)
        assert 0.60 <= state["squash"] <= 1.10
        assert state["lean"] == pytest.approx(state["lean"])
        assert abs(state["lean"]) <= 8.0


def test_contact_squashes_and_apex_does_not() -> None:
    contact = paper_city.ball_state(0.0)
    assert contact["contact"] > 0.0
    assert contact["squash"] < 0.85

    apex_t = paper_city.find_apex(0.2, 0.4)
    apex = paper_city.ball_state(apex_t)
    assert apex["contact"] == 0.0
    assert 0.95 <= apex["squash"] <= 1.05


def test_frame_renders_at_the_requested_size() -> None:
    frame = paper_city.render_frame(0.31, 320, 180)
    assert frame.size == (320, 180)
    assert frame.mode == "RGB"


def test_loop_seam_matches() -> None:
    first = np.asarray(paper_city.render_frame(0.0, 240, 135), dtype=np.int16)
    last = np.asarray(paper_city.render_frame(1.0, 240, 135), dtype=np.int16)
    assert np.abs(first - last).mean() < 1.0
