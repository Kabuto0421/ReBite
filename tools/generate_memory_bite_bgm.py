#!/usr/bin/env python3
"""Generate the simple 8-bit BGM loop used by the prototype."""

from pathlib import Path
import math
import random
import struct
import wave

SR = 44100
BPM = 132
BEAT = 60 / BPM
STEPS_PER_BEAT = 4
STEP = BEAT / STEPS_PER_BEAT
BARS = 8
STEPS = BARS * 4 * STEPS_PER_BEAT
DURATION = STEPS * STEP
OUT = Path("assets/bgm/memory_bite_loop.wav")

NOTE = {
    "C3": 130.81, "Eb3": 155.56, "F3": 174.61, "G3": 196.00, "Ab3": 207.65, "Bb3": 233.08,
    "C4": 261.63, "D4": 293.66, "Eb4": 311.13, "F4": 349.23, "G4": 392.00, "Ab4": 415.30, "Bb4": 466.16,
    "C5": 523.25, "D5": 587.33, "Eb5": 622.25, "F5": 698.46, "G5": 783.99,
}

LEAD = [
    "C5", None, "G4", None, "Eb5", None, "D5", None, "C5", None, "Bb4", "G4", "Ab4", None, "G4", None,
    "C5", None, "G4", None, "F5", None, "Eb5", None, "D5", None, "Bb4", None, "C5", None, None, None,
    "G4", None, "C5", None, "D5", None, "Eb5", None, "G5", None, "F5", "Eb5", "D5", None, "C5", None,
    "Bb4", None, "C5", None, "Eb5", None, "D5", None, "C5", None, "G4", None, "C5", None, None, None,
    "C5", None, "G4", None, "Eb5", None, "D5", None, "C5", None, "Bb4", "G4", "Ab4", None, "G4", None,
    "C5", None, "G4", None, "F5", None, "Eb5", None, "D5", None, "Bb4", None, "C5", None, None, None,
    "Eb5", None, "D5", None, "C5", None, "Bb4", None, "Ab4", None, "Bb4", None, "C5", None, "D5", None,
    "Eb5", None, "G5", None, "F5", None, "D5", None, "C5", None, None, None, "C5", None, None, None,
]

CHORDS = ["C4", "Ab3", "Bb3", "G3", "C4", "Ab3", "F3", "G3"]
BASS = ["C3", "Ab3", "Bb3", "G3", "C3", "Ab3", "F3", "G3"]


def sq(phase: float, duty: float = 0.5) -> float:
    return 1.0 if phase % 1.0 < duty else -1.0


def tri(phase: float) -> float:
    return 4.0 * abs((phase % 1.0) - 0.5) - 1.0


def env(local_t: float, dur: float, attack: float = 0.006, release: float = 0.055) -> float:
    attack_gain = min(1.0, local_t / attack) if attack > 0 else 1.0
    release_gain = min(1.0, max(0.0, (dur - local_t) / release)) if release > 0 else 1.0
    return max(0.0, min(attack_gain, release_gain))


def add_pulse(samples: list[float], start_step: int, note: str, step_len: float, volume: float, duty: float) -> None:
    start = int(start_step * STEP * SR)
    length = int(step_len * STEP * SR)
    freq = NOTE[note]
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        vibrato = 1.0 + 0.004 * math.sin(2 * math.pi * 7.0 * t)
        samples[idx] += volume * env(t, length / SR, 0.003, 0.045) * sq(t * freq * vibrato, duty)


def add_triangle(samples: list[float], start_step: int, note: str, beats: float, volume: float) -> None:
    start = int(start_step * STEP * SR)
    length = int(beats * BEAT * SR)
    freq = NOTE[note]
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        samples[idx] += volume * env(t, length / SR, 0.004, 0.07) * tri(t * freq)


def add_noise_drums(samples: list[float]) -> None:
    for step in range(STEPS):
        in_beat = step % 4
        beat = (step // 4) % 4
        bar = step // 16
        if in_beat == 0 and beat in [0, 2]:
            _add_kick(samples, step)
        if in_beat == 0 and beat in [1, 3]:
            _add_snare(samples, step)
        if in_beat in [0, 2] and (bar + beat) % 2 == 0:
            _add_hat(samples, step)


def _add_kick(samples: list[float], step: int) -> None:
    start = int(step * STEP * SR)
    length = int(0.065 * SR)
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        freq = 92 - 44 * (i / max(1, length))
        samples[idx] += 0.16 * env(t, length / SR, 0.001, 0.055) * sq(t * freq)


def _add_snare(samples: list[float], step: int) -> None:
    start = int(step * STEP * SR)
    length = int(0.055 * SR)
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        samples[idx] += 0.075 * env(i / SR, length / SR, 0.001, 0.045) * (random.random() * 2 - 1)


def _add_hat(samples: list[float], step: int) -> None:
    start = int(step * STEP * SR)
    length = int(0.025 * SR)
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        samples[idx] += 0.035 * env(i / SR, length / SR, 0.001, 0.018) * (random.random() * 2 - 1)


def main() -> None:
    random.seed(2323)
    samples = [0.0 for _ in range(int(SR * DURATION))]

    for step, note in enumerate(LEAD):
        if note:
            add_pulse(samples, step, note, 1.75, 0.18, 0.25)

    chord_notes = {
        "C4": ["C4", "Eb4", "G4"], "Ab3": ["Ab3", "C4", "Eb4"], "Bb3": ["Bb3", "D4", "F4"],
        "G3": ["G3", "Bb3", "D4"], "F3": ["F3", "Ab3", "C4"],
    }
    for bar, root in enumerate(CHORDS):
        for beat in range(4):
            for sub in [0, 2]:
                add_pulse(samples, bar * 16 + beat * 4 + sub, chord_notes[root][(beat + sub // 2) % 3], 0.8, 0.075, 0.125)

    for bar, root in enumerate(BASS):
        for beat, note in enumerate([root, root, None, root]):
            if note:
                add_triangle(samples, bar * 16 + beat * 4, note, 0.88, 0.17)

    add_noise_drums(samples)
    _write_wav(samples)


def _write_wav(samples: list[float]) -> None:
    fade = int(0.008 * SR)
    for i in range(fade):
        k = i / fade
        samples[i] *= k
        samples[-1 - i] *= k
    gain = 0.82 / max(0.001, max(abs(x) for x in samples))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print(OUT)


if __name__ == "__main__":
    main()
