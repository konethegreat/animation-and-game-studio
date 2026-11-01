"""Clone the maker's voice for the pilot, locally and only with consent.

The reference clip is the owner's own recording. Chatterbox runs on this
machine; nothing is uploaded. Generated lines stay in the gitignored private
folder until a mix is approved, and the pilot falls back to music and titles
if the clone does not convince.

    .venv-ml/Scripts/python projects/010-maker-at-work/voice.py --test
    .venv-ml/Scripts/python projects/010-maker-at-work/voice.py
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

import numpy as np
import soundfile as sf

PROJECT = Path(__file__).resolve().parent
ROOT = PROJECT.parents[1]
PRIVATE = ROOT / "assets" / "private"
REFERENCE = PRIVATE / "voice-reference.m4a"
REFERENCE_WAV = PRIVATE / "qa" / "voice-reference.wav"
OUT = PRIVATE / "voice"
FFMPEG = Path(r"C:\Users\Konet\Tools\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe")

LINES = (
    ("l01", "This is where the work begins.", 7.4),
    ("l02", "A desk, a lamp, and a little patience.", 11.6),
    ("l03", "Everything I make starts here.", 18.4),
)

TEST_TEXT = "This is where the work begins."
VARIANTS = (
    ("neutral", 0.35, 0.35),
    ("default", 0.50, 0.50),
    ("warm", 0.65, 0.45),
)


def reference() -> Path:
    if REFERENCE_WAV.exists():
        return REFERENCE_WAV
    if not REFERENCE.exists():
        raise SystemExit(f"missing voice reference: {REFERENCE}")
    REFERENCE_WAV.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [str(FFMPEG), "-y", "-i", str(REFERENCE), "-ac", "1", "-ar", "24000", str(REFERENCE_WAV)],
        check=True, capture_output=True,
    )
    print(f"reference -> {REFERENCE_WAV}")
    return REFERENCE_WAV


def model():
    import torch
    from chatterbox.tts import ChatterboxTTS

    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"loading chatterbox on {device}")
    return ChatterboxTTS.from_pretrained(device=device)


def speak(tts, text: str, original: Path, path: Path, exaggeration: float, cfg_weight: float) -> Path:
    wav = tts.generate(
        text,
        audio_prompt_path=str(original),
        exaggeration=exaggeration,
        cfg_weight=cfg_weight,
        temperature=0.8,
    )
    data = wav.squeeze().detach().cpu().numpy()
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, data, tts.sr, subtype="PCM_16")
    return path


def pitch_report(path: Path) -> str:
    import librosa

    wave, rate = sf.read(path, always_2d=True)
    mono = wave.mean(axis=1).astype(np.float32)
    if rate != 24000:
        mono = librosa.resample(mono, orig_sr=rate, target_sr=24000)
        rate = 24000
    f0, voiced, _ = librosa.pyin(
        mono, fmin=60, fmax=350, sr=rate, frame_length=2048, hop_length=256,
    )
    values = f0[voiced & ~np.isnan(f0)]
    if values.size == 0:
        return f"{path.stem}: no voiced frames"
    low, mid, high = np.percentile(values, (10, 50, 90))
    seconds = len(mono) / rate
    return f"{path.stem}: {seconds:4.1f}s  f0 median {mid:5.1f} Hz  range {low:5.1f}-{high:5.1f}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--test", action="store_true", help="render the A/B variants only")
    args = parser.parse_args()

    original = reference()
    tts = model()
    print(pitch_report(original))

    if args.test:
        for name, exaggeration, cfg in VARIANTS:
            path = speak(tts, TEST_TEXT, original, PRIVATE / "qa" / "voice" / f"test-{name}.wav", exaggeration, cfg)
            print(pitch_report(path))
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    for line_id, text, _ in LINES:
        path = speak(tts, text, original, OUT / f"{line_id}.wav", 0.5, 0.5)
        print(pitch_report(path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
