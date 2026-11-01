"""Lay the cloned voice over the score with gentle ducking.

The score is the bed; each voice line sits at the moment it belongs to.
Ducking is done with a smoothed envelope, the voice gets a small room so it
belongs in the same space, and the result is written next to the score. If no
voice lines exist the script says so and leaves the score alone.

    .venv/Scripts/python projects/010-maker-at-work/mix.py
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

PROJECT = Path(__file__).resolve().parent
ROOT = PROJECT.parents[1]
AUDIO = PROJECT / "audio"
SCORE = AUDIO / "full.flac"
VOICE = ROOT / "assets" / "private" / "voice"
OUT = AUDIO / "full-mix.flac"

sys.path.insert(0, str(PROJECT))
from voice import LINES  # noqa: E402

RATE = 48000


def load(path: Path) -> np.ndarray:
    data, rate = sf.read(path, always_2d=True)
    data = data.astype(np.float64)
    if rate != RATE:
        data = signal.resample_poly(data, RATE, rate, axis=0)
    if data.shape[1] == 1:
        data = np.repeat(data, 2, axis=1)
    return data


def room(data: np.ndarray) -> np.ndarray:
    length = int(0.9 * RATE)
    t = np.arange(length) / RATE
    rng = np.random.default_rng(31)
    decay = np.exp(-t / 0.28)
    out = data.copy()
    for channel in range(2):
        ir = rng.normal(0.0, 1.0, length) * decay
        ir[: int(0.012 * RATE)] = 0.0
        ir /= np.sqrt(np.sum(ir**2))
        out[:, channel] += signal.fftconvolve(data[:, channel], ir)[: len(data)] * 0.16
    return out


def envelope(size: int, starts: list[float], lengths: list[float], depths: list[float]) -> np.ndarray:
    envelope = np.ones(size)
    for start, length, depth in zip(starts, lengths, depths):
        first = max(0, int((start - 0.25) * RATE))
        last = min(size, int((start + length + 0.45) * RATE))
        if last <= first:
            continue
        envelope[first:last] = np.minimum(envelope[first:last], 1.0 - depth)
    smooth = int(0.12 * RATE)
    kernel = np.hanning(smooth)
    kernel /= kernel.sum()
    return signal.fftconvolve(envelope, kernel, mode="same")


def main() -> int:
    score = load(SCORE)
    size = len(score)
    starts, lengths = [], []
    placed = np.zeros_like(score)
    used = []

    for line_id, _text, start in LINES:
        path = VOICE / f"{line_id}.wav"
        if not path.exists():
            continue
        line = load(path)
        if line.shape[1] == 1:
            line = np.repeat(line, 2, axis=1)
        sos = signal.butter(2, 90 / (RATE / 2), btype="high", output="sos")
        line = signal.sosfilt(sos, line, axis=0)
        presence = signal.sosfilt(
            signal.butter(2, 2000 / (RATE / 2), btype="high", output="sos"), line, axis=0
        )
        line = line + 0.35 * presence
        line = room(line)
        peak = float(np.max(np.abs(line)))
        if peak > 1e-9:
            line *= 0.95 / peak
        first = int(start * RATE)
        if first >= size:
            continue
        take = min(len(line), size - first)
        placed[first : first + take] += line[:take]
        starts.append(start)
        lengths.append(len(line) / RATE)
        used.append((line_id, round(len(line) / RATE, 2)))

    if not used:
        print(f"no voice lines in {VOICE}; the score stays as it is")
        return 0

    ducked = score * envelope(len(score), starts, lengths, [0.66, 0.55, 0.55])[:, None]
    mix = ducked + placed
    peak = float(np.max(np.abs(mix)))
    mix = mix / max(peak, 1e-9) * 0.89
    sf.write(OUT, mix, RATE, subtype="PCM_16")

    print(f"voice lines {used}")
    for line_id, seconds in used:
        start = next(start for lid, _text, start in LINES if lid == line_id)
        print(f"  {line_id} {start:5.2f}s +{seconds:4.2f}s")
    print(f"mix {len(mix) / RATE:.2f}s peak {peak:.2f} -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
