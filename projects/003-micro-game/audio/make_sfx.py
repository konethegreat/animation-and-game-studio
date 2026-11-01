"""Generate the two arcade sounds with the standard library."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
HERE = Path(__file__).resolve().parent


def write_wav(path: Path, samples: list[float]) -> None:
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767)) for value in samples
        )
        handle.writeframes(frames)


def collect() -> list[float]:
    duration = 0.16
    total = int(RATE * duration)
    samples = []
    for i in range(total):
        t = i / RATE
        freq = 880 + 900 * (t / duration)
        envelope = math.exp(-16 * t)
        samples.append(math.sin(math.tau * freq * t) * envelope * 0.55)
    return samples


def hit() -> list[float]:
    duration = 0.32
    total = int(RATE * duration)
    rng = random.Random(4)
    samples = []
    for i in range(total):
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0) * math.exp(-14 * t) * 0.4
        thump = math.sin(math.tau * (120 - 40 * t) * t) * math.exp(-9 * t) * 0.5
        samples.append(noise + thump)
    return samples


def main() -> None:
    write_wav(HERE / "collect.wav", collect())
    write_wav(HERE / "hit.wav", hit())
    print("wrote collect.wav and hit.wav")


if __name__ == "__main__":
    main()
