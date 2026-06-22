#!/usr/bin/env python3
"""Generate BGM candidate 02: C-Fm-Ab-G groove with B-part breaks and ostinato."""

from pathlib import Path
import math
import random
import struct
import wave

SR = 44100
BPM = 140
BEAT = 60 / BPM
STEPS_PER_BEAT = 4
STEP = BEAT / STEPS_PER_BEAT
BARS = 8
STEPS = BARS * 4 * STEPS_PER_BEAT
DURATION = STEPS * STEP
OUT = Path("assets/bgm/memory_bite_loop_02.wav")

NOTE = {
    "C3": 130.81, "Eb3": 155.56, "F3": 174.61, "G3": 196.00, "Ab3": 207.65, "Bb3": 233.08,
    "C4": 261.63, "D4": 293.66, "Eb4": 311.13, "E4": 329.63, "F4": 349.23, "G4": 392.00, "Ab4": 415.30, "Bb4": 466.16,
    "C5": 523.25, "D5": 587.33, "Eb5": 622.25, "E5": 659.25, "F5": 698.46, "G5": 783.99, "Ab5": 830.61, "Bb5": 932.33,
}

# A: restrained ostinato with short lead fragments.
# B: lead-note/offbeat-snare breaks, an eight-note arpeggio, then an ostinato ending.
CHORDS = ["C3", "F3", "Ab3", "G3", "C3", "F3", "Ab3", "G3"]
BASS = ["C3", "F3", "Ab3", "G3", "C3", "F3", "Ab3", "G3"]


def sq(phase: float, duty: float = 0.5) -> float:
    return 1.0 if phase % 1.0 < duty else -1.0


def tri(phase: float) -> float:
    return 4.0 * abs((phase % 1.0) - 0.5) - 1.0


def env(local_t: float, dur: float, attack: float = 0.004, release: float = 0.045) -> float:
    attack_gain = min(1.0, local_t / attack) if attack > 0 else 1.0
    release_gain = min(1.0, max(0.0, (dur - local_t) / release)) if release > 0 else 1.0
    return max(0.0, min(attack_gain, release_gain))


def add_pulse(samples: list[float], start_step: int, note: str, step_len: float, volume: float, duty: float, vibrato_depth: float = 0.003) -> None:
    start = int(start_step * STEP * SR)
    length = int(step_len * STEP * SR)
    freq = NOTE[note]
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        vibrato = 1.0 + vibrato_depth * math.sin(2 * math.pi * 7.0 * t)
        samples[idx] += volume * env(t, length / SR) * sq(t * freq * vibrato, duty)


def add_triangle(samples: list[float], start_step: int, note: str, beats: float, volume: float) -> None:
    start = int(start_step * STEP * SR)
    length = int(beats * BEAT * SR)
    freq = NOTE[note]
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        samples[idx] += volume * env(t, length / SR, 0.003, 0.06) * tri(t * freq)


def add_noise_drums(samples: list[float]) -> None:
    for step in range(STEPS):
        in_beat = step % 4
        beat = (step // 4) % 4
        bar = step // 16
        eighth = step // 2
        eighth_in_bar = eighth % 8
        if in_beat == 0 and beat in [0, 2]:
            _add_kick(samples, step, 0.18)
        if in_beat == 0 and beat in [1, 3]:
            _add_snare(samples, step, 0.13)
        if bar in [4, 5] and in_beat == 2 and beat in [0, 1]:
            _add_snare(samples, step, 0.115)
        elif in_beat == 2 and beat in [1, 3] and eighth_in_bar not in [3, 7]:
            _add_snare(samples, step, 0.055)
        if in_beat == 2 and eighth_in_bar not in [3, 7]:
            _add_hat(samples, step, 0.046)
        if in_beat == 0 and beat in [0, 2]:
            _add_hat(samples, step, 0.026)


def _add_kick(samples: list[float], step: int, volume: float) -> None:
    start = int(step * STEP * SR)
    length = int(0.06 * SR)
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        freq = 102 - 52 * (i / max(1, length))
        samples[idx] += volume * env(t, length / SR, 0.001, 0.052) * sq(t * freq)


def _add_snare(samples: list[float], step: int, volume: float) -> None:
    start = int(step * STEP * SR)
    length = int(0.06 * SR)
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        t = i / SR
        body = 0.35 * sq(t * 180, 0.5)
        noise = 0.65 * (random.random() * 2 - 1)
        samples[idx] += volume * env(t, length / SR, 0.001, 0.046) * (body + noise)


def _add_hat(samples: list[float], step: int, volume: float) -> None:
    start = int(step * STEP * SR)
    length = int(0.028 * SR)
    for i in range(length):
        idx = start + i
        if idx >= len(samples):
            break
        samples[idx] += volume * env(i / SR, length / SR, 0.001, 0.018) * (random.random() * 2 - 1)


def main() -> None:
    random.seed(4242)
    samples = [0.0 for _ in range(int(SR * DURATION))]

    add_a_part_lead(samples)
    add_b_part_lead(samples)

    chord_notes = {
        "C3": ["C4", "E4", "G4"], "F3": ["F4", "Ab4", "C5"],
        "Ab3": ["Ab3", "C4", "Eb4"], "G3": ["G3", "Bb3", "D4"],
    }
    for bar, root in enumerate(CHORDS):
        if bar in [4, 5]:
            for eighth_offset in [0, 2, 4, 6]:
                note = chord_notes[root][eighth_offset % 3]
                add_pulse(samples, bar * 16 + eighth_offset * 2, note, 1.1, 0.052, 0.125, 0.0)
        elif bar < 4:
            for eighth_offset in [0, 2, 4, 6]:
                note = chord_notes[root][eighth_offset % 3]
                add_pulse(samples, bar * 16 + eighth_offset * 2, note, 0.82, 0.034, 0.125, 0.0)
        else:
            for eighth_offset in [0, 1, 2, 4, 5, 6]:
                note = chord_notes[root][eighth_offset % 3]
                add_pulse(samples, bar * 16 + eighth_offset * 2, note, 0.9, 0.064, 0.125, 0.0)

    for bar, root in enumerate(BASS):
        pattern = [root, root, root, None, root, root, root, None]
        if bar in [4, 5]:
            pattern = [root, None, root, None, root, None, root, None]
        for eighth_offset, note in enumerate(pattern):
            if note:
                add_triangle(samples, bar * 16 + eighth_offset * 2, note, 0.44, 0.17)

    add_noise_drums(samples)
    write_wav(samples)


def add_a_part_lead(samples: list[float]) -> None:
    ostinato_pairs = {
        "C3": ["C5", "G5"],
        "F3": ["F5", "C5"],
        "Ab3": ["Ab4", "Eb5"],
        "G3": ["G4", "D5"],
    }
    for bar in range(4):
        root = CHORDS[bar]
        pair = ostinato_pairs[root]
        for eighth_offset, note in zip([0, 2, 4, 6], [pair[0], pair[1], pair[0], pair[1]]):
            add_pulse(samples, bar * 16 + eighth_offset * 2, note, 0.9, 0.072, 0.25)

    lead_fragments = [
        (32, "Ab4", 2), (35, "C5", 1), (40, "Eb5", 2),
        (48, "G4", 2), (51, "Bb4", 1), (56, "D5", 2), (60, "G5", 1),
    ]
    for step, note, length in lead_fragments:
        add_pulse(samples, step, note, length * 0.9, 0.17, 0.25)


def add_b_part_lead(samples: list[float]) -> None:
    break_notes = ["C5", "G5"]
    for index, note in enumerate(break_notes):
        add_pulse(samples, 64 + index * 4, note, 1.65, 0.2, 0.25)
        add_pulse(samples, 80 + index * 4, note, 1.65, 0.17, 0.125)

    eight_note_arpeggio = ["Ab4", "C5", "Eb5", "Ab5", "G5", "Eb5", "C5", "Ab4"]
    for index, note in enumerate(eight_note_arpeggio):
        add_pulse(samples, 96 + index * 2, note, 0.85, 0.19, 0.25)

    ostinato = ["G4", "D5", "Bb4", "D5", "G4", "D5", "Bb4", "D5"]
    for index, note in enumerate(ostinato):
        add_pulse(samples, 112 + index * 2, note, 0.85, 0.16, 0.25)


def write_wav(samples: list[float]) -> None:
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
