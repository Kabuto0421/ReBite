from __future__ import annotations

import math
import struct
import subprocess
import wave
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp" / "audio_analysis"
FFMPEG = "/opt/homebrew/bin/ffmpeg"

TRACKS = {
    "title": ROOT / "assets/bgm/rebite_title_bass_clean_ending.wav",
    "boss_intro": ROOT / "assets/bgm/rebite_boar_intro_fanfare.ogg",
    "boss_battle": ROOT / "assets/bgm/boar_boss_pressure_theme.ogg",
}

EQ_BANDS = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
BASS_SCAN = [41, 44, 49, 55, 62, 65, 73, 82, 87, 98, 110, 123, 131, 147, 165, 175, 196, 220, 247]


def convert_to_wav(source: Path, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            FFMPEG,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(source),
            "-ac",
            "1",
            "-ar",
            "44100",
            "-sample_fmt",
            "s16",
            str(out),
        ],
        check=True,
    )


def load_pcm(path: Path) -> tuple[int, list[float]]:
    with wave.open(str(path), "rb") as reader:
        sample_rate = reader.getframerate()
        frames = reader.readframes(reader.getnframes())
    ints = struct.unpack("<%dh" % (len(frames) // 2), frames)
    return sample_rate, [value / 32768.0 for value in ints]


def load_pcm_np(path: Path) -> tuple[int, np.ndarray]:
    sample_rate, samples = load_pcm(path)
    return sample_rate, np.asarray(samples, dtype=np.float64)


def rms(values: list[float]) -> float:
    if not values:
        return 0.0
    return math.sqrt(sum(value * value for value in values) / len(values))


def goertzel_power(samples: list[float], sample_rate: int, frequency: float, start: int, length: int) -> float:
    if length <= 0:
        return 0.0
    normalized = frequency / sample_rate
    coeff = 2.0 * math.cos(2.0 * math.pi * normalized)
    s_prev = 0.0
    s_prev2 = 0.0
    end = min(start + length, len(samples))
    for sample in samples[start:end]:
        s = sample + coeff * s_prev - s_prev2
        s_prev2 = s_prev
        s_prev = s
    return s_prev2 * s_prev2 + s_prev * s_prev - coeff * s_prev * s_prev2


def band_energy(samples: list[float], sample_rate: int, frequencies: list[int], window_size: int = 8192) -> dict[int, float]:
    hop = window_size
    powers = {frequency: [] for frequency in frequencies}
    for start in range(0, max(1, len(samples) - window_size), hop):
        window = samples[start : start + window_size]
        level = rms(window)
        if level < 0.015:
            continue
        for frequency in frequencies:
            powers[frequency].append(goertzel_power(samples, sample_rate, frequency, start, len(window)) / len(window))
    return {frequency: (sum(values) / len(values) if values else 0.0) for frequency, values in powers.items()}


def db(value: float, reference: float) -> float:
    if value <= 0.0 or reference <= 0.0:
        return -120.0
    return 10.0 * math.log10(value / reference)


def analyze_track(name: str, source: Path) -> None:
    wav_path = TMP / f"{name}.wav"
    convert_to_wav(source, wav_path)
    sample_rate, samples_np = load_pcm_np(wav_path)
    samples = samples_np.tolist()
    duration = len(samples) / sample_rate
    low_candidates = band_energy(samples, sample_rate, BASS_SCAN)
    eq_candidates = band_energy(samples, sample_rate, EQ_BANDS[:5])
    fft_peaks, fft_eq = fft_low_frequency_profile(samples_np, sample_rate)
    reference = max(low_candidates.values()) if low_candidates else 1.0
    sorted_low = sorted(low_candidates.items(), key=lambda item: item[1], reverse=True)
    sorted_eq = sorted(eq_candidates.items(), key=lambda item: item[1], reverse=True)

    print(f"\n[{name}] {source.name}")
    print(f"duration={duration:.2f}s sample_rate={sample_rate} rms={rms(samples):.4f}")
    print("bass scan peaks:")
    for frequency, power in sorted_low[:8]:
        print(f"  {frequency:>4} Hz  {db(power, reference):>6.2f} dB rel")
    print("EQ10 low-band energy:")
    eq_ref = max(eq_candidates.values()) if eq_candidates else 1.0
    for frequency, power in sorted_eq:
        print(f"  {frequency:>4} Hz  {db(power, eq_ref):>6.2f} dB rel")
    print("FFT low-frequency peaks:")
    for frequency, relative_db in fft_peaks[:8]:
        print(f"  {frequency:>6.1f} Hz  {relative_db:>6.2f} dB rel")
    print("FFT EQ10 low-band windows:")
    for frequency, relative_db in fft_eq:
        print(f"  {frequency:>4} Hz  {relative_db:>6.2f} dB rel")


def fft_low_frequency_profile(samples: np.ndarray, sample_rate: int) -> tuple[list[tuple[float, float]], list[tuple[int, float]]]:
    window_size = 16384
    hop = window_size // 2
    if len(samples) < window_size:
        window_size = 8192
        hop = window_size // 2
    window = np.hanning(window_size)
    freqs = np.fft.rfftfreq(window_size, 1.0 / sample_rate)
    bass_mask = (freqs >= 35.0) & (freqs <= 240.0)
    spectrum_sum = np.zeros_like(freqs)
    used_windows = 0
    for start in range(0, max(1, len(samples) - window_size), hop):
        chunk = samples[start : start + window_size]
        if len(chunk) < window_size:
            continue
        if float(np.sqrt(np.mean(chunk * chunk))) < 0.015:
            continue
        spectrum = np.abs(np.fft.rfft(chunk * window)) ** 2
        spectrum_sum += spectrum
        used_windows += 1
    if used_windows == 0:
        return [], []
    spectrum_sum /= used_windows
    bass_freqs = freqs[bass_mask]
    bass_power = spectrum_sum[bass_mask]
    peak_indices = find_local_peaks(bass_power)
    peak_indices = sorted(peak_indices, key=lambda idx: bass_power[idx], reverse=True)
    peak_ref = float(np.max(bass_power))
    peaks = [(float(bass_freqs[idx]), db(float(bass_power[idx]), peak_ref)) for idx in peak_indices]

    eq_band_windows: list[tuple[int, float]] = []
    band_values: list[tuple[int, float]] = []
    for band in EQ_BANDS[:5]:
        lower = band / math.sqrt(2.0)
        upper = band * math.sqrt(2.0)
        mask = (freqs >= lower) & (freqs <= upper)
        band_values.append((band, float(np.mean(spectrum_sum[mask])) if np.any(mask) else 0.0))
    band_ref = max(value for _, value in band_values) if band_values else 1.0
    for band, value in band_values:
        eq_band_windows.append((band, db(value, band_ref)))
    return peaks, eq_band_windows


def find_local_peaks(values: np.ndarray) -> list[int]:
    peaks: list[int] = []
    for idx in range(1, len(values) - 1):
        if values[idx] >= values[idx - 1] and values[idx] >= values[idx + 1]:
            peaks.append(idx)
    return peaks


def main() -> None:
    for name, source in TRACKS.items():
        analyze_track(name, source)


if __name__ == "__main__":
    main()
