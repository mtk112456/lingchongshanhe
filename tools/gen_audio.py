"""Generate CC0-safe procedural audio for Qingzhu.

Outputs 16-bit mono WAV into client/assets/audio/{sfx,bgm}.
No external samples, no license issues.
"""
from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
ROOT = Path(__file__).resolve().parents[1]
SFX_DIR = ROOT / "client" / "assets" / "audio" / "sfx"
BGM_DIR = ROOT / "client" / "assets" / "audio" / "bgm"


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.85 / peak if peak > 0.85 else 1.0
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s * scale)) * 32767)
            frames.extend(struct.pack("<h", v))
        w.writeframes(bytes(frames))


def env(t: float, dur: float, attack: float = 0.005, release: float = 0.05) -> float:
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def tone(freq: float, t: float, dur: float, amp: float = 1.0,
         attack: float = 0.005, release: float = 0.05) -> float:
    return amp * env(t, dur, attack, release) * math.sin(2 * math.pi * freq * t)


def noise() -> float:
    return random.uniform(-1, 1)


def lowpass(prev: float, x: float, alpha: float) -> float:
    return prev + alpha * (x - prev)


def make_click() -> list[float]:
    dur = 0.08
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, dur, 0.001, 0.03)
        x = 0.5 * noise() + 0.5 * math.sin(2 * math.pi * 1400 * t)
        lp = lowpass(lp, x, 0.45)
        out.append(lp * e * 0.7)
    return out


def make_draw() -> list[float]:
    dur = 0.18
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, dur, 0.01, 0.08)
        x = noise() * (0.6 + 0.4 * math.sin(2 * math.pi * 7 * t))
        lp = lowpass(lp, x, 0.20)
        out.append(lp * e * 0.8)
    return out


def make_play() -> list[float]:
    dur = 0.24
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, dur, 0.005, 0.12)
        f = 220 + 520 * (t / dur)
        x = 0.7 * noise() + 0.5 * math.sin(2 * math.pi * f * t)
        lp = lowpass(lp, x, 0.30)
        out.append(lp * e * 0.8)
    return out


def make_hit() -> list[float]:
    dur = 0.16
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, dur, 0.001, 0.07)
        body = math.sin(2 * math.pi * (90 - 30 * t) * t)
        crack = noise() * math.exp(-t * 35)
        out.append((0.7 * body + 0.5 * crack) * e)
    return out


def make_arrow() -> list[float]:
    dur = 0.14
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, dur, 0.002, 0.05)
        x = noise() * (0.5 + 0.5 * math.sin(2 * math.pi * 18 * t))
        lp = lowpass(lp, x, 0.55)
        out.append(lp * e * 0.8)
    return out


def make_wall() -> list[float]:
    dur = 0.55
    out, lp = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        e = env(t, dur, 0.005, 0.25)
        rumble = math.sin(2 * math.pi * (55 - 10 * t) * t)
        debris = noise() * math.exp(-t * 6)
        lp = lowpass(lp, debris, 0.15)
        out.append((0.9 * rumble + 0.6 * lp) * e)
    return out


def make_arpeggio(notes: list[float], step: float, dur: float, amp: float = 0.6) -> list[float]:
    out = [0.0] * int(SR * dur)
    for idx, f in enumerate(notes):
        start = int(SR * idx * step)
        length = min(int(SR * 0.6), len(out) - start)
        for i in range(length):
            t = i / SR
            e = env(t, length / SR, 0.01, 0.25)
            out[start + i] += amp * e * math.sin(2 * math.pi * f * t)
    return out


def make_bgm_map(dur: float = 24.0) -> list[float]:
    notes = [146.83, 174.61, 196.00, 220.00, 261.63]  # D3 F3 G3 A3 C4
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        pad = math.sin(2 * math.pi * 73.42 * t) * 0.18
        pad += math.sin(2 * math.pi * 110.00 * t) * 0.10
        for k, f in enumerate(notes):
            lfo = 0.5 + 0.5 * math.sin(2 * math.pi * (0.08 + 0.01 * k) * t + k)
            pad += 0.10 * lfo * math.sin(2 * math.pi * f * t)
        fade = min(1.0, t / 1.5, (dur - t) / 1.5)
        out.append(pad * max(0.0, fade))
    return out


def make_bgm_battle(dur: float = 20.0) -> list[float]:
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        drone = 0.20 * math.sin(2 * math.pi * 73.42 * t)
        pulse = 0.0
        beat = t % 1.0
        if beat < 0.18:
            pulse = 0.55 * math.exp(-beat * 18) * math.sin(2 * math.pi * 65 * beat)
        hi = 0.06 * math.sin(2 * math.pi * 293.66 * t) * (0.5 + 0.5 * math.sin(2 * math.pi * 0.25 * t))
        fade = min(1.0, t / 1.0, (dur - t) / 1.0)
        out.append((drone + pulse + hi) * max(0.0, fade))
    return out


def main() -> None:
    random.seed(7)
    write_wav(SFX_DIR / "click.wav", make_click())
    write_wav(SFX_DIR / "draw.wav", make_draw())
    write_wav(SFX_DIR / "play.wav", make_play())
    write_wav(SFX_DIR / "hit.wav", make_hit())
    write_wav(SFX_DIR / "arrow.wav", make_arrow())
    write_wav(SFX_DIR / "wall.wav", make_wall())
    write_wav(SFX_DIR / "victory.wav", make_arpeggio([293.66, 349.23, 440.00, 523.25], 0.11, 1.0, 0.5))
    write_wav(SFX_DIR / "defeat.wav", make_arpeggio([293.66, 261.63, 220.00, 174.61], 0.13, 1.1, 0.5))
    write_wav(BGM_DIR / "map.wav", make_bgm_map())
    write_wav(BGM_DIR / "battle.wav", make_bgm_battle())
    print("audio generated")


if __name__ == "__main__":
    main()
