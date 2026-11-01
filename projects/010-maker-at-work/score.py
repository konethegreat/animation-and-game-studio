"""Build the score for The Maker at Work.

Seventy five seconds of original music, synthesized from scratch: no samples,
no quotes, no borrowed themes. A low D drone and a warm pad sit under a sparse
pulse. The maker's phrase enters with the portrait; each world colours it
again, paper plucks, a neon pulse, wide dunes, a warm grove and a cosmic
resolution, before the film returns home and the phrase closes.

Run with the project venv: .venv/Scripts/python projects/010-maker-at-work/score.py
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

PROJECT = Path(__file__).resolve().parent
ROOT = PROJECT.parents[1]
AUDIO = PROJECT / "audio"
STEMS = ROOT / "media" / "010-maker-at-work" / "_audio"

RATE = 48000
DURATION = 75.0
BEAT = 60.0 / 72.0
SIZE = int(RATE * DURATION)
T = np.arange(SIZE) / RATE
RNG = np.random.default_rng(7)


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69.0) / 12.0)


def note(name: str) -> float:
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    letter, rest = name[0], name[1:]
    semitone = names[letter]
    while rest and rest[0] in "#b":
        semitone += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    return hz(12 * (octave + 1) + semitone)


def bus() -> np.ndarray:
    return np.zeros((SIZE, 2), dtype=np.float64)


def level(data: np.ndarray, target_db: float) -> np.ndarray:
    rms = math.sqrt(float(np.mean(data**2))) if data.size else 0.0
    if rms < 1e-9:
        return data
    return data * 10 ** ((target_db - 20 * math.log10(rms)) / 20)


def add(bus_: np.ndarray, start: float, clip: np.ndarray, gain: float = 1.0) -> None:
    first = int(round(start * RATE))
    if first >= SIZE:
        return
    part = clip[: SIZE - first]
    bus_[first : first + len(part)] += part * gain


def env(length: int, attack: float, release: float, curve: float = 2.0) -> np.ndarray:
    """Attack, hold, release envelope with a soft shoulder on the release."""
    attack_n = max(1, int(attack * RATE))
    release_n = max(1, int(release * RATE))
    attack_n = min(attack_n, length)
    release_n = min(release_n, length - attack_n) if length > attack_n else 0
    hold = np.ones(length)
    hold[:attack_n] = np.linspace(0.0, 1.0, attack_n) ** 0.7
    if release_n:
        fall = np.linspace(0.0, 1.0, release_n) ** curve
        hold[length - release_n :] = 1.0 - fall
    return hold


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, cutoff / (RATE / 2), btype="low", output="sos")
    return signal.sosfilt(sos, x, axis=0)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, cutoff / (RATE / 2), btype="high", output="sos")
    return signal.sosfilt(sos, x, axis=0)


def pan(sample: np.ndarray, amount: float) -> np.ndarray:
    left = math.sqrt(max(0.0, 0.5 - amount / 2))
    right = math.sqrt(max(0.0, 0.5 + amount / 2))
    return np.stack([sample * left, sample * right], axis=1)


def pad_note(frequency: float, start: float, stop: float, gain: float, amount: float) -> np.ndarray:
    length = int((stop - start) * RATE)
    t = np.arange(length) / RATE
    voice = np.zeros(length)
    for detune, weight in ((0.9984, 0.5), (1.0016, 0.5)):
        for partial in range(1, 9):
            voice += (
                weight
                * (1.0 / partial**1.45)
                * np.sin(2 * math.pi * frequency * detune * partial * t + RNG.uniform(0, math.tau))
            )
    voice *= 0.018
    voice = lowpass(voice, 2400.0)
    swing = 1.0 + 0.12 * np.sin(2 * math.pi * (1.0 / 7.3) * t + RNG.uniform(0, math.tau))
    voice *= env(length, 1.8, 2.2) * swing
    return pan(voice, amount) * gain


def chord(notes: list[str], start: float, stop: float, gain: float = 1.0) -> np.ndarray:
    out = bus()
    for index, name in enumerate(notes):
        amount = (index / max(1, len(notes) - 1) - 0.5) * 0.5
        add(out, start, pad_note(note(name), start, stop, gain, amount))
    return out


def drone() -> np.ndarray:
    out = bus()
    for frequency, gain in ((note("D1"), 1.0), (note("D2"), 0.55), (note("A2"), 0.22)):
        t = T[: int((DURATION - 1.0) * RATE)]
        beat = 1.0 + 0.06 * np.sin(2 * math.pi * 0.09 * t)
        tone = np.sin(2 * math.pi * frequency * t) + 0.35 * np.sin(2 * math.pi * frequency * 2.003 * t)
        tone *= beat * (0.03 + 0.97 * env(len(t), 2.5, 3.0))
        out[: len(t)] += pan(tone * gain * 0.12, 0.0)
    return lowpass(out, 220.0)


def kick(gain: float, pitch: float = 52.0) -> np.ndarray:
    length = int(1.1 * RATE)
    t = np.arange(length) / RATE
    sweep = pitch * np.exp(-t * 9.0) + 30.0
    body = np.sin(2 * math.pi * np.cumsum(sweep) / RATE) * np.exp(-t * 4.2)
    thump = RNG.normal(0.0, 1.0, length) * np.exp(-t * 28.0) * 0.35
    hit = lowpass(body + thump, 150.0)
    hit *= env(length, 0.004, 0.5)
    return pan(hit * gain, 0.0)


def hat(gain: float) -> np.ndarray:
    length = int(0.16 * RATE)
    t = np.arange(length) / RATE
    noise = RNG.normal(0.0, 1.0, length) * np.exp(-t * 34.0)
    noise = highpass(noise, 6500.0, order=2)
    return pan(noise * gain, 0.28)


def clap(gain: float) -> np.ndarray:
    length = int(0.30 * RATE)
    t = np.arange(length) / RATE
    noise = RNG.normal(0.0, 1.0, length)
    band = highpass(lowpass(noise, 3200.0), 900.0)
    return pan(band * np.exp(-t * 18.0) * gain, -0.16)


def bass_note(name: str, length: float, gain: float) -> np.ndarray:
    frequency = note(name)
    t = np.arange(int(length * RATE)) / RATE
    tone = (
        np.sin(2 * math.pi * frequency * t) * 0.55
        + np.sin(2 * math.pi * frequency * 2.0 * t) * 0.22
        + np.sin(2 * math.pi * frequency * 3.0 * t) * 0.07
    )
    tone = np.tanh(tone * 1.4)
    tone *= env(len(t), 0.012, length * 0.55, curve=2.0)
    return pan(lowpass(tone, 220.0) * gain, 0.0)


def rhythm() -> np.ndarray:
    out = bus()
    hit = 3.33
    while hit < 25.0:
        gain = 0.26 + 0.42 * math.exp(-((hit - 14.0) ** 2) / 30.0)
        add(out, hit, kick(gain))
        hit += BEAT * 2
    add(out, 16.0, kick(0.72, pitch=44.0))

    t = 26.0
    step = 0
    while t < 35.9:
        if step % 2 == 0:
            add(out, t, kick(0.85))
        else:
            add(out, t, hat(0.10))
        if step % 4 == 2:
            add(out, t, clap(0.24))
        step += 1
        t += BEAT * 0.5
    add(out, 35.0, kick(0.7, pitch=40.0))

    hit = 36.6
    while hit < 45.2:
        add(out, hit, kick(0.34, pitch=46.0))
        hit += BEAT * 4

    hit = 46.4
    while hit < 55.4:
        add(out, hit, kick(0.30, pitch=48.0))
        hit += BEAT * 2

    hit = 56.4
    while hit < 64.6:
        grow = 0.28 + 0.30 * (hit - 56.4) / 8.2
        add(out, hit, kick(grow, pitch=44.0))
        hit += BEAT * 2

    add(out, 66.6, kick(0.85, pitch=40.0))
    add(out, 70.0, kick(0.55, pitch=38.0))
    return out


def bass_line() -> np.ndarray:
    out = bus()
    roots = (("D2", 26.0), ("D2", 29.33), ("Bb1", 32.67))
    for root, start in roots:
        for step in range(8):
            t = start + step * BEAT * 0.5
            if t >= 35.9:
                break
            name = "A1" if step in (3, 7) else root
            add(out, t, bass_note(name, BEAT * 0.44, 0.62))
    for name, start, length in (
        ("D2", 36.6, 2.4), ("Bb1", 39.8, 2.4), ("G1", 43.2, 2.0),
        ("F1", 46.6, 2.6), ("C2", 49.8, 2.4), ("F1", 52.8, 2.2),
        ("D2", 56.4, 2.6), ("Bb1", 60.0, 2.4), ("G1", 63.2, 2.2),
        ("D2", 66.4, 3.6), ("D2", 70.2, 5.0),
    ):
        add(out, start, bass_note(name, length, 0.55))
    return out


def melody_note(name: str, start: float, length: float, gain: float, amount: float = 0.0) -> np.ndarray:
    frequency = note(name)
    t = np.arange(int(length * RATE)) / RATE
    vibrato = 1.0 + 0.0035 * np.sin(2 * math.pi * 4.6 * t + RNG.uniform(0, math.tau))
    tone = np.zeros(len(t))
    for partial, weight in ((1, 1.0), (2, 0.30), (3, 0.12), (4, 0.06), (5, 0.03)):
        tone += weight * np.sin(2 * math.pi * frequency * partial * np.cumsum(vibrato) / RATE)
    tone *= env(len(t), 0.35, 0.9, curve=2.6) * 0.055
    tone = lowpass(tone, 4200.0)
    return pan(tone * gain, amount)


def pluck(name: str, length: float, gain: float, amount: float = 0.0) -> np.ndarray:
    frequency = note(name)
    t = np.arange(int(length * RATE)) / RATE
    tone = np.zeros(len(t))
    for partial in range(1, 9):
        tone += (1.0 / partial**1.25) * np.sin(
            2 * math.pi * frequency * partial * t + RNG.uniform(0, math.tau)
        ) * np.exp(-t * (2.2 + 1.6 * partial))
    tone *= env(len(t), 0.004, 0.12) * 0.09
    tone = lowpass(tone, 5200.0)
    return pan(tone * gain, amount)


def bell(name: str, length: float, gain: float, amount: float = 0.22) -> np.ndarray:
    t = np.arange(int(length * RATE)) / RATE
    tone = np.zeros(len(t))
    for partial, weight, decay in ((1.0, 1.0, 1.3), (2.01, 0.45, 2.1), (2.98, 0.28, 3.0), (4.21, 0.16, 3.6)):
        tone += weight * np.sin(2 * math.pi * note(name) * partial * t) * np.exp(-t * decay)
    tone *= env(len(t), 0.006, 0.1) * 0.16
    return pan(tone * gain, amount)


def leads() -> np.ndarray:
    out = bus()
    phrase = [
        ("A3", 7.6, 1.15), ("D4", 9.0, 1.5), ("F4", 10.8, 1.0), ("E4", 12.0, 1.6),
        ("D4", 13.9, 1.9), ("C4", 15.9, 0.9),
    ]
    for index, (name, start, length) in enumerate(phrase):
        amount = 0.18 if index % 2 == 0 else -0.18
        add(out, start, melody_note(name, start, length, 1.0, amount))

    paper = [
        ("D4", 17.0), ("F4", 17.8), ("A4", 18.6), ("G4", 19.4),
        ("F4", 20.2), ("E4", 21.0), ("D4", 21.8), ("C4", 22.6),
        ("A3", 23.4), ("D4", 24.4),
    ]
    for index, (name, start) in enumerate(paper):
        add(out, start, pluck(name, 2.6, 0.85, 0.24 if index % 2 == 0 else -0.24))

    neon = ("D4", "F4", "A4", "D5", "A4", "F4", "E4", "C4")
    for step in range(20):
        t = 26.0 + step * BEAT
        if t >= 35.9:
            break
        add(out, t, pluck(neon[step % len(neon)], 0.9, 0.55, -0.28 if step % 2 else 0.28))

    dunes = (("D4", 36.8, 2.6), ("F4", 39.6, 2.4), ("E4", 42.2, 2.0), ("A3", 44.4, 2.2))
    for name, start, length in dunes:
        add(out, start, melody_note(name, start, length, 0.85, 0.0))

    grove = (
        ("A3", 46.8, 1.6), ("D4", 48.4, 1.8), ("F4", 50.2, 1.6),
        ("E4", 52.0, 1.8), ("D4", 53.9, 2.0), ("C4", 55.8, 1.0),
    )
    for index, (name, start, length) in enumerate(grove):
        add(out, start, melody_note(name, start, length, 0.9, 0.16 if index % 2 == 0 else -0.16))

    cosmos = (
        ("D5", 56.6, 0.9), ("A5", 58.4, 0.7), ("F5", 60.2, 0.8),
        ("D6", 62.0, 0.65), ("A5", 63.4, 0.6), ("D6", 64.8, 0.55),
    )
    for name, start, gain in cosmos:
        add(out, start, bell(name, 4.5, gain))

    closing = (
        ("A3", 66.6, 1.0), ("D4", 67.8, 1.6), ("F4", 69.4, 1.2),
        ("E4", 70.8, 1.0), ("D4", 72.0, 3.0),
    )
    for index, (name, start, length) in enumerate(closing):
        add(out, start, melody_note(name, start, length, 1.0, 0.0))
    add(out, 73.2, bell("D5", 4.5, 0.8, 0.0))
    return out


def air() -> np.ndarray:
    noise = RNG.normal(0.0, 1.0, (SIZE, 2))
    noise = lowpass(noise, 9000.0, order=1)
    noise = highpass(noise, 380.0, order=2)
    slow = 0.55 + 0.45 * np.sin(2 * math.pi * 0.045 * T)
    noise *= slow[:, None] * 0.02
    return noise


def riser(start: float, stop: float, gain: float) -> np.ndarray:
    length = int((stop - start) * RATE)
    t = np.arange(length) / RATE
    noise = RNG.normal(0.0, 1.0, length)
    dark = lowpass(noise, 500.0)
    bright = highpass(lowpass(noise, 5200.0), 900.0)
    blend = np.linspace(0.0, 1.0, length) ** 2
    tone = dark * (1 - blend) + bright * blend
    tone *= np.linspace(0.0, 1.0, length) ** 2.2 * 0.05
    return pan(tone * gain, RNG.uniform(-0.3, 0.3))


def texture() -> np.ndarray:
    out = bus()
    add(out, 0.0, air())
    for start, stop, gain in (
        (15.4, 16.5, 0.7), (25.2, 26.2, 1.0), (35.2, 36.3, 0.6),
        (45.2, 46.3, 0.7), (54.6, 56.2, 1.0), (64.8, 66.2, 0.8),
    ):
        add(out, start, riser(start, stop, gain))
    for start in (56.8, 57.6, 58.6, 59.8, 61.0, 62.2, 63.6, 65.0):
        add(out, start, pluck(RNG.choice(["D5", "A5", "F6", "D6"]), 1.6, 0.24, RNG.uniform(-0.5, 0.5)))
    return out


def automation(points) -> np.ndarray:
    times = np.array([p[0] for p in points], dtype=np.float64)
    values = np.array([p[1] for p in points], dtype=np.float64)
    curve = np.interp(T, times, values)
    kernel = np.hanning(int(0.8 * RATE))
    kernel /= kernel.sum()
    return signal.fftconvolve(curve, kernel, mode="same")


def reverb() -> tuple[np.ndarray, np.ndarray]:
    length = int(3.4 * RATE)
    t = np.arange(length) / RATE
    decay = np.exp(-t / 1.05)
    ir = []
    for _ in range(2):
        noise = RNG.normal(0.0, 1.0, length) * decay
        noise = lowpass(noise, 5200.0)
        noise[: int(0.018 * RATE)] = 0.0
        ir.append(noise / np.sqrt(np.sum(noise**2)))
    return ir[0], ir[1]


def wet(dry: np.ndarray, ir_left: np.ndarray, ir_right: np.ndarray, amount: float) -> np.ndarray:
    out = np.zeros_like(dry)
    for channel, ir in ((0, ir_left), (1, ir_right)):
        out[:, channel] = signal.fftconvolve(dry[:, channel], ir)[:SIZE]
    return dry + out * amount


def write(name: str, data: np.ndarray, folder: Path, suffix: str = ".wav", subtype: str = "PCM_24") -> None:
    folder.mkdir(parents=True, exist_ok=True)
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    if peak > 1e-9:
        data = data / peak * 0.89
    sf.write(folder / f"{name}{suffix}", data, RATE, subtype=subtype)
    print(f"{name:7s} peak {peak:.3f} -> {folder / (name + suffix)}")


def main() -> int:
    beats = bus()
    add(beats, 0.0, drone(), 1.0)
    add(beats, 0.0, rhythm())
    add(beats, 0.0, bass_line())

    harmony = bus()
    parts = [
        (["D2", "A2", "D3", "F3", "E4"], 0.0, 4.2),
        (["Bb2", "F3", "D3", "A3"], 3.6, 8.2),
        (["G2", "D3", "Bb3", "A3"], 7.6, 12.2),
        (["A2", "E3", "D3", "A3"], 11.6, 16.4),
        (["F2", "C3", "A2", "E3"], 15.8, 20.4),
        (["C3", "G3", "E3", "G4"], 20.0, 23.8),
        (["G2", "D3", "Bb3", "F4"], 23.4, 27.6),
        (["A2", "E3", "C3", "A3"], 27.2, 30.6),
        (["D3", "A3", "F3", "D4"], 30.2, 35.8),
        (["Bb2", "F3", "D3", "A3"], 35.4, 40.2),
        (["G2", "D3", "Bb3", "A3"], 39.8, 44.6),
        (["A2", "E3", "D3", "A3"], 44.2, 48.4),
        (["F2", "C3", "A3", "F3"], 48.0, 52.2),
        (["C3", "G3", "E3", "G4"], 51.8, 56.2),
        (["D4", "A4", "F4", "D5"], 55.8, 60.0),
        (["Bb3", "F4", "D4", "A4"], 59.6, 63.8),
        (["G3", "D4", "Bb4", "A4"], 63.4, 66.6),
        (["D3", "A3", "F3", "D4"], 66.2, 70.2),
        (["D2", "A2", "D3", "F#3", "A3"], 69.8, 75.6),
    ]
    for notes, start, stop in parts:
        add(harmony, start, chord(notes, start, stop, gain=0.9))

    lead = bus()
    add(lead, 0.0, leads())

    texture_bus = bus()
    add(texture_bus, 0.0, texture())

    ir_left, ir_right = reverb()
    harmony_wet = wet(harmony, ir_left, ir_right, 0.5)
    lead_wet = wet(lead, ir_left, ir_right, 0.75)
    texture_wet = wet(texture_bus, ir_left, ir_right, 0.4)

    shape = automation((
        (0.0, 0.78), (6.0, 0.86), (8.0, 0.95), (15.0, 1.0), (18.0, 0.92),
        (24.0, 1.05), (26.5, 1.16), (33.0, 1.10), (36.5, 0.88), (44.0, 0.84),
        (47.0, 0.94), (54.0, 0.98), (57.0, 1.10), (63.0, 1.22), (66.5, 1.0),
        (70.0, 0.92), (73.0, 1.0), (75.0, 0.92),
    ))

    mix = (
        level(beats, -39.0)
        + level(harmony_wet, -27.5)
        + level(lead_wet, -26.5)
        + level(texture_wet, -33.0)
    )
    fade = np.ones(SIZE)
    fade[: int(1.2 * RATE)] = np.linspace(0.0, 1.0, int(1.2 * RATE)) ** 1.4
    tail = np.linspace(1.0, 0.0, int(2.4 * RATE)) ** 1.6
    fade[-len(tail) :] = tail
    mix *= fade[:, None] * shape[:, None]
    mix = highpass(mix, 32.0)
    peak = float(np.max(np.abs(mix)))
    mix = np.tanh(mix / max(peak, 1e-9) * 1.15) / 1.15
    mix *= 0.89 / max(float(np.max(np.abs(mix))), 1e-9)

    write("drone", beats, STEMS)
    write("pad", harmony_wet, STEMS)
    write("pulse", rhythm(), STEMS)
    write("melody", lead_wet, STEMS)
    write("texture", texture_wet, STEMS)
    write("full", mix, AUDIO, suffix=".flac", subtype="PCM_16")

    for index in range(int(DURATION)):
        block = mix[index * RATE : (index + 1) * RATE]
        db = 20 * math.log10(max(float(np.sqrt(np.mean(block**2))), 1e-9))
        print(f"{index:02d}s {db:6.1f} dB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
