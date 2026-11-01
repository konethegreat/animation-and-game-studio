"""Judge the cloned takes without guessing: intelligibility and speaker match.

Runs entirely on this machine. faster-whisper transcribes each take so a
mangled line shows up as words that do not match the script, and the
chatterbox voice encoder compares each take with the owner's reference.

    .venv-ml/Scripts/python projects/010-maker-at-work/voice_qa.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

from voice import CACHE, LINES, OUT, REFERENCE_WAV, TEST_TEXT, local_model_dir

QA = REFERENCE_WAV.parent / "voice"


def normalise(text: str) -> list[str]:
    return re.findall(r"[a-z']+", text.lower())


def whisper_model():
    from faster_whisper import WhisperModel

    print("loading whisper small on cpu")
    return WhisperModel("small", device="cpu", compute_type="int8")


def transcribe(model, path: Path) -> str:
    data, _ = load_wav(path)
    segments, _ = model.transcribe(data, language="en", beam_size=5, vad_filter=True)
    return " ".join(segment.text.strip() for segment in segments).strip()


def voice_encoder():
    import torch
    from chatterbox.models.voice_encoder import VoiceEncoder
    from safetensors.torch import load_file

    directory = local_model_dir()
    if directory is None:
        raise SystemExit(f"missing weights in {CACHE}")
    encoder = VoiceEncoder()
    encoder.load_state_dict(load_file(str(directory / "ve.safetensors")))
    return encoder.to(torch.device("cpu")).eval()


VOICE_RATE = 16000


def load_wav(path: Path):
    from scipy.signal import resample_poly

    data, rate = sf.read(str(path), dtype="float32")
    if data.ndim > 1:
        data = data.mean(axis=1)
    if rate != VOICE_RATE:
        data = resample_poly(data, VOICE_RATE, rate).astype("float32")
    return data, VOICE_RATE


def embedding(encoder, path: Path):
    data, rate = load_wav(path)
    return encoder.embeds_from_wavs([data], rate, as_spk=True)


def cosine(a, b) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


def main() -> int:
    takes = sorted(QA.glob("test-*.wav"))
    if not takes:
        raise SystemExit(f"no test takes in {QA}, run voice.py --test first")

    whisper = whisper_model()
    encoder = voice_encoder()

    reference = embedding(encoder, REFERENCE_WAV)
    data, rate = load_wav(REFERENCE_WAV)
    middle = len(data) // 2
    first = encoder.embeds_from_wavs([data[:middle]], rate, as_spk=True)
    second = encoder.embeds_from_wavs([data[middle:]], rate, as_spk=True)
    print(f"\nreference {rate} Hz, {len(data) / rate:.1f}s")
    print(f"self similarity between halves: {cosine(first, second):.3f}")

    expected = normalise(TEST_TEXT)
    print(f"\nscript: {TEST_TEXT}")
    print(f"reference heard as: {transcribe(whisper, REFERENCE_WAV)}\n")

    rows = []
    for take in takes:
        heard = transcribe(whisper, take)
        words = normalise(heard)
        hits = sum(1 for word in expected if word in words)
        rows.append((take.stem, hits / len(expected), cosine(reference, embedding(encoder, take)), heard))

    print(f"{'take':14} {'script':>7} {'voice':>6}  heard")
    for name, script, voice, heard in rows:
        print(f"{name:14} {script:7.2f} {voice:6.3f}  {heard}")

    finals = sorted(OUT.glob("l0*.wav"))
    if finals:
        scripts = {line_id: text for line_id, text, _ in LINES}
        print(f"\n{'line':6} {'script':>7} {'voice':>6}  heard")
        for path in finals:
            expected = normalise(scripts.get(path.stem, ""))
            heard = transcribe(whisper, path)
            words = normalise(heard)
            hits = sum(1 for word in expected if word in words) / max(len(expected), 1)
            print(f"{path.stem:6} {hits:7.2f} {cosine(reference, embedding(encoder, path)):6.3f}  {heard}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
