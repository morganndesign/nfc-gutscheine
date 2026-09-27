#!/usr/bin/env python3
"""Synthesises the four GiftCard Waiter sounds to the brief of 11 §6.

Outputs (file names binding, 11 §6.1 / 10 §2.5):
  tool/sounds_src/gcw_<name>_48k24_master.wav   master, 48 kHz / 24-bit mono
  tool/sounds_src/gcw_<name>_48k16.wav          16-bit PCM variant (Android, high Ogg latency)
  tool/sounds_src/loudness_report.txt           LUFS-M max and true peak per file
  ios/Runner/Sounds/gcw_<name>.caf              16-bit linear PCM, 48 kHz mono (alert channel)
  android/app/src/main/res/raw/gcw_<name>.ogg   Ogg Vorbis q6, 48 kHz mono (SoundPool)

Global rules (11 §6.1): onset within the first 1 ms, tail decays to −60 dB
then ≤ 5 ms fade to digital silence, energy 600 Hz – 4 kHz, nothing below
200 Hz, low-pass 10 kHz, loudness as max momentary loudness (LUFS-M,
400 ms window, ITU-R BS.1770 K-weighting) at the per-token target of
11 §2.2, true peak ≤ −1 dBTP.

Requirements: Python 3.10+, numpy, scipy, ffmpeg (with libvorbis) on PATH.
Run from the app root:  python3 tool/synthesize_sounds.py
"""

from __future__ import annotations

import os
import subprocess
import wave

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 48_000
RNG = np.random.default_rng(20260926)   # fixed seed: reproducible noise layer


def db(x: float) -> float:
    return 10 ** (x / 20)


def t_axis(ms: float) -> np.ndarray:
    return np.arange(int(round(ms * SR / 1000))) / SR


def seg_exp(n: int, from_db: float, to_db: float) -> np.ndarray:
    """Exponential (linear-in-dB) segment of n samples."""
    if n <= 0:
        return np.zeros(0)
    return db(1) * 10 ** (np.linspace(from_db, to_db, n, endpoint=False) / 20)


def envelope(total_ms: float, attack_ms: float, decay_ms: float, decay_db: float,
             sustain_until_ms: float | None, release_ms: float,
             release_to_db: float = -60.0) -> np.ndarray:
    """ADSR: linear attack from 0, exponential decay/release (dB-linear)."""
    n = int(round(total_ms * SR / 1000))
    a = int(round(attack_ms * SR / 1000))
    d = int(round(decay_ms * SR / 1000))
    parts = [np.linspace(0, 1, a, endpoint=False), seg_exp(d, 0, decay_db)]
    if sustain_until_ms is not None:
        s = int(round(sustain_until_ms * SR / 1000)) - a - d
        parts.append(np.full(max(s, 0), db(decay_db)))
    r = int(round(release_ms * SR / 1000))
    parts.append(seg_exp(r, decay_db, release_to_db))
    env = np.concatenate(parts)
    out = np.zeros(n)
    out[: min(n, len(env))] = env[:n]
    return out


def fade_tail(x: np.ndarray, ms: float = 5.0) -> np.ndarray:
    """≤ 5 ms linear fade to digital silence at the end (11 §6.1)."""
    n = int(round(ms * SR / 1000))
    y = x.copy()
    y[-n:] *= np.linspace(1, 0, n)
    y[-1] = 0.0
    return y


def band_limit(x: np.ndarray) -> np.ndarray:
    """Nothing below 200 Hz, low-pass at 10 kHz (causal: no pre-ringing)."""
    hp = signal.butter(2, 200, "highpass", fs=SR, output="sos")
    lp = signal.butter(4, 10_000, "lowpass", fs=SR, output="sos")
    return signal.sosfilt(lp, signal.sosfilt(hp, x))


# ------------------------------------------------------------------ sounds

def card_detected() -> np.ndarray:
    """Single soft glass tick, 1.6 kHz, 60 ms (11 §6.2)."""
    t = t_axis(60)
    env = envelope(60, 1, 15, -12, None, 44)
    tone = np.sin(2 * np.pi * 1600 * t) + db(-18) * np.sin(2 * np.pi * 4800 * t)
    # 2.5 ms band-passed (3–6 kHz) noise transient at −24 dB for definition.
    n_noise = int(0.0025 * SR)
    bp = signal.butter(2, [3000, 6000], "bandpass", fs=SR, output="sos")
    noise = signal.sosfilt(bp, RNG.standard_normal(n_noise))
    noise = noise / np.max(np.abs(noise)) * np.linspace(1, 0, n_noise)
    x = tone * env
    x[:n_noise] += db(-24) * noise
    return x


def bell_note(t: np.ndarray, f0: float, env_db: np.ndarray) -> np.ndarray:
    """Fundamental, 2nd harmonic −12 dB, inharmonic 2.76× partial −24 dB
    decaying twice as fast (envelope in dB doubled)."""
    env = 10 ** (env_db / 20)
    env_fast = 10 ** (2 * env_db / 20)
    return (np.sin(2 * np.pi * f0 * t) * env
            + db(-12) * np.sin(2 * np.pi * 2 * f0 * t) * env
            + db(-24) * np.sin(2 * np.pi * 2.76 * f0 * t) * env_fast)


def success() -> np.ndarray:
    """Two-note rising chime E6 → B6, 280 ms, note 2 at 90 ms, +1 dB (11 §6.2)."""
    total = 280
    out = np.zeros(int(total * SR / 1000))
    # Note 1: E6, A 3 · D 60 to −10 dB · R 50 (ends ≈ 113 ms).
    e1 = envelope(113, 3, 60, -10, None, 50)
    t1 = t_axis(113)
    n1 = bell_note(t1, 1318.51, 20 * np.log10(np.maximum(e1, 1e-6)))
    out[: len(n1)] += n1
    # Note 2: B6 at 90 ms, A 3 · D 80 to −8 dB · R 107 exponential → 280 ms.
    start = int(0.090 * SR)
    e2 = envelope(190, 3, 80, -8, None, 107)
    t2 = t_axis(190)
    n2 = db(1) * bell_note(t2, 1975.53, 20 * np.log10(np.maximum(e2, 1e-6)))
    out[start: start + len(n2)] += n2[: len(out) - start]
    return out


def warning() -> np.ndarray:
    """Single mid tone 660 Hz (+1320 −8 dB, +1980 −16 dB), 150 ms (11 §6.2)."""
    t = t_axis(150)
    env = envelope(150, 5, 40, -6, 100, 50)
    x = (np.sin(2 * np.pi * 660 * t) + db(-8) * np.sin(2 * np.pi * 1320 * t)
         + db(-16) * np.sin(2 * np.pi * 1980 * t))
    return x * env


def error() -> np.ndarray:
    """Two low tones, perceived 330 Hz (missing fundamental), 2 × 90 ms with
    a 60 ms gap, 240 ms (11 §6.2)."""
    def tone() -> np.ndarray:
        t = t_axis(90)
        env = envelope(90, 4, 30, -4, 70, 20)
        env[-int(0.002 * SR):] *= np.linspace(1, 0, int(0.002 * SR))
        x = (db(-6) * np.sin(2 * np.pi * 330 * t) + np.sin(2 * np.pi * 660 * t)
             + db(-4) * np.sin(2 * np.pi * 990 * t) + db(-12) * np.sin(2 * np.pi * 1320 * t))
        return x * env

    out = np.zeros(int(0.240 * SR))
    a = tone()
    out[: len(a)] += a
    out[int(0.150 * SR): int(0.150 * SR) + len(a)] += a
    return out


# ------------------------------------------------------------ measurement

def k_weight(x: np.ndarray) -> np.ndarray:
    """ITU-R BS.1770-4 K-weighting at 48 kHz."""
    b1, a1 = [1.53512485958697, -2.69169618940638, 1.19839281085285], \
        [1.0, -1.69065929318241, 0.73248077421585]
    b2, a2 = [1.0, -2.0, 1.0], [1.0, -1.99004745483398, 0.99007225036621]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x))


def lufs_m_max(x: np.ndarray) -> float:
    """Maximum momentary loudness (400 ms window, 1 ms hop, silence-padded)."""
    win = int(0.4 * SR)
    y = k_weight(np.concatenate([np.zeros(win), x, np.zeros(win)])) ** 2
    c = np.concatenate([[0.0], np.cumsum(y)])
    ms = (c[win:] - c[:-win]) / win
    return float(-0.691 + 10 * np.log10(np.max(ms[:: SR // 1000]) + 1e-20))


def true_peak_db(x: np.ndarray) -> float:
    """True peak via 4× oversampling (BS.1770 Annex 2 approach)."""
    up = signal.resample_poly(x, 4, 1)
    return float(20 * np.log10(np.max(np.abs(up)) + 1e-20))


def normalise(x: np.ndarray, target_lufs: float, peak_db: float | None,
              tp_limit: float = -1.0) -> np.ndarray:
    """Scales to the LUFS-M target (a maximum, 11 §2.2), lowered further to
    the brief's peak level where one is given (card detected ≈ −6 dBFS) and
    so that the true peak stays ≤ −1 dBTP."""
    y = x * db(target_lufs - lufs_m_max(x))
    if peak_db is not None:
        sp = 20 * np.log10(np.max(np.abs(y)))
        if sp > peak_db:
            y *= db(peak_db - sp)
    tp = true_peak_db(y)
    if tp > tp_limit - 0.05:
        y *= db(tp_limit - 0.05 - tp)
    return y


# ------------------------------------------------------------------ output

def write_wav(path: str, x: np.ndarray, bits: int) -> None:
    full = os.path.join(ROOT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    scale = 2 ** (bits - 1) - 1
    q = np.clip(np.round(x * scale), -scale - 1, scale).astype(np.int32)
    if bits == 24:
        raw = np.frombuffer(q.astype("<i4").tobytes(), dtype=np.uint8).reshape(-1, 4)[:, :3]
        data = raw.tobytes()
    else:
        data = q.astype("<i2").tobytes()
    with wave.open(full, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(bits // 8)
        w.setframerate(SR)
        w.writeframes(data)


def ffmpeg(src: str, dst: str, codec: list[str]) -> None:
    os.makedirs(os.path.dirname(os.path.join(ROOT, dst)), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(ROOT, src),
                    "-ac", "1", "-ar", str(SR), *codec, "-map_metadata", "-1",
                    os.path.join(ROOT, dst)], check=True)


SOUNDS = {
    # token: (file, synth, LUFS-M max, peak dBFS, length ms) — 11 §2.2, §6.2
    "sound.cardDetected": ("gcw_card_detected", card_detected, -22.0, -6.0, 60),
    "sound.success": ("gcw_success", success, -18.0, None, 280),
    "sound.warning": ("gcw_warning", warning, -20.0, None, 150),
    "sound.error": ("gcw_error", error, -20.0, None, 240),
}


def main() -> None:
    report = ["GiftCard Waiter sound set — loudness report (11 §6.3)",
              "LUFS-M max: ITU-R BS.1770 K-weighting, 400 ms window; true peak: 4x oversampled.",
              ""]
    for token, (name, synth, target, peak, length_ms) in SOUNDS.items():
        x = fade_tail(band_limit(synth()))
        x = fade_tail(normalise(x, target, peak))
        assert len(x) == int(length_ms * SR / 1000), name
        onset = int(np.argmax(np.abs(x) > db(-60) * np.max(np.abs(x))))
        master = f"tool/sounds_src/{name}_48k24_master.wav"
        write_wav(master, x, 24)
        write_wav(f"tool/sounds_src/{name}_48k16.wav", x, 16)
        ffmpeg(master, f"ios/Runner/Sounds/{name}.caf", ["-c:a", "pcm_s16le", "-f", "caf"])
        ffmpeg(master, f"android/app/src/main/res/raw/{name}.ogg",
               ["-c:a", "libvorbis", "-q:a", "6"])
        report.append(f"{token:20s} {name}: {length_ms} ms, LUFS-M max "
                      f"{lufs_m_max(x):6.2f} (target ≤ {target:.0f}), true peak "
                      f"{true_peak_db(x):6.2f} dBTP, sample peak "
                      f"{20 * np.log10(np.max(np.abs(x))):6.2f} dBFS, onset "
                      f"{onset / SR * 1000:.2f} ms")
    text = "\n".join(report) + "\n"
    with open(os.path.join(ROOT, "tool/sounds_src/loudness_report.txt"), "w") as fh:
        fh.write(text)
    print(text)


if __name__ == "__main__":
    main()
