#!/usr/bin/env python3
"""Generate deterministic, original ambient demo tracks for the bundled player.

The compositions and samples are synthesized from math functions only. No
third-party recordings, loops, voices, or copyrighted melodies are embedded.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "entry/src/main/resources/rawfile/audio"
SAMPLE_RATE = 16_000
DURATION_SECONDS = 32


TRACKS = [
    ("morning-train", 108, [57, 61, 64, 66], 7),
    ("rain-cafe", 82, [52, 55, 59, 57], 19),
    ("small-trip", 116, [60, 64, 67, 62], 31),
    ("seaside-letter", 94, [55, 59, 62, 60], 43),
    ("look-at-stars", 72, [50, 54, 57, 59], 59),
]


def frequency(midi_note: int) -> float:
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))


def envelope(time_in_beat: float, beat_seconds: float) -> float:
    return math.exp(-5.8 * time_in_beat / beat_seconds)


def soft_clip(value: float) -> float:
    return math.tanh(value * 1.18) / math.tanh(1.18)


def render_track(path: Path, bpm: int, roots: list[int], seed: int) -> None:
    rng = random.Random(seed)
    beat_seconds = 60.0 / bpm
    frame_count = SAMPLE_RATE * DURATION_SECONDS
    melody = [0, 4, 7, 11, 7, 4, 2, 7]
    phase_noise = [rng.random() * math.tau for _ in range(4)]

    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        frames = bytearray()

        for frame in range(frame_count):
            t = frame / SAMPLE_RATE
            beat = t / beat_seconds
            beat_index = int(beat)
            beat_phase = (beat - beat_index) * beat_seconds
            bar = int(beat / 4)
            root = roots[bar % len(roots)]

            fade_in = min(1.0, t / 1.8)
            fade_out = min(1.0, (DURATION_SECONDS - t) / 2.2)
            master = max(0.0, min(fade_in, fade_out))

            pad = 0.0
            for tone_index, interval in enumerate((0, 4, 7, 12)):
                hz = frequency(root + interval)
                sway = 0.0025 * math.sin(math.tau * 0.07 * t + phase_noise[tone_index])
                pad += math.sin(math.tau * hz * (1.0 + sway) * t + phase_noise[tone_index])
            pad *= 0.055

            bass_hz = frequency(root - 12)
            bass = math.sin(math.tau * bass_hz * t) * 0.105
            bass *= 0.72 + 0.28 * math.sin(math.pi * min(1.0, beat_phase / beat_seconds))

            note = root + 12 + melody[beat_index % len(melody)]
            pluck_hz = frequency(note)
            pluck_env = envelope(beat_phase, beat_seconds)
            pluck = (
                math.sin(math.tau * pluck_hz * t)
                + 0.34 * math.sin(math.tau * pluck_hz * 2.0 * t)
                + 0.12 * math.sin(math.tau * pluck_hz * 3.0 * t)
            ) * pluck_env * 0.12

            half_beat_phase = (t % (beat_seconds / 2.0))
            shimmer = math.sin(math.tau * frequency(root + 31) * t)
            shimmer *= envelope(half_beat_phase, beat_seconds / 2.0) * 0.018

            pulse_phase = t % beat_seconds
            pulse = math.sin(math.tau * 58.0 * t) * math.exp(-18.0 * pulse_phase) * 0.09

            movement = 0.86 + 0.14 * math.sin(math.tau * 0.045 * t + seed)
            center = (pad + bass + pluck + shimmer + pulse) * movement * master
            sample = int(max(-1.0, min(1.0, soft_clip(center))) * 32767)
            frames.extend(struct.pack("<h", sample))

            if len(frames) >= 262_144:
                output.writeframesraw(frames)
                frames.clear()

        if frames:
            output.writeframesraw(frames)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, bpm, roots, seed in TRACKS:
        output_path = OUTPUT / f"{name}.wav"
        render_track(output_path, bpm, roots, seed)
        print(f"generated {output_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
