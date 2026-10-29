#!/usr/bin/env python3
"""Synthesize Awash's chiptune sound effects as 16-bit mono WAV files.

Each effect is built from square waves and noise, like a handheld sound chip, so
the sounds can be tuned here and regenerated rather than edited by hand.

Example:
  python scripts/tools/make_sfx.py --out assets/audio/sfx
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path
from typing import Callable, List

RATE = 22050
PEAK = 0.45


def square(phase: float, duty: float = 0.5) -> float:
    return 1.0 if (phase % 1.0) < duty else -1.0


def sweep(duration: float, start_hz: float, end_hz: float, duty: float = 0.5,
          vibrato_hz: float = 0.0, vibrato_depth: float = 0.0) -> List[float]:
    """A square wave gliding from start_hz to end_hz, fading out."""
    count = int(RATE * duration)
    samples, phase = [], 0.0
    for i in range(count):
        t = i / count
        hz = start_hz + (end_hz - start_hz) * t
        if vibrato_hz:
            hz *= 1.0 + vibrato_depth * math.sin(2 * math.pi * vibrato_hz * i / RATE)
        phase += hz / RATE
        samples.append(square(phase, duty) * (1.0 - t) ** 1.5)
    return samples


def noise(duration: float, start_cut: float, end_cut: float, seed: int) -> List[float]:
    """White noise through a one-pole low-pass whose cutoff glides, fading out."""
    rng = random.Random(seed)
    count = int(RATE * duration)
    samples, level = [], 0.0
    for i in range(count):
        t = i / count
        cut = start_cut + (end_cut - start_cut) * t
        alpha = 1.0 - math.exp(-2 * math.pi * cut / RATE)
        level += alpha * (rng.uniform(-1.0, 1.0) - level)
        samples.append(level * 2.5 * (1.0 - t) ** 2)
    return samples


def notes(pitches: List[float], each: float, duty: float = 0.25) -> List[float]:
    out: List[float] = []
    for i, hz in enumerate(pitches):
        fade = 1.0 - i / (len(pitches) + 1)
        out += [s * fade for s in sweep(each, hz, hz * 0.97, duty)]
    return out


def growl(duration: float, start_hz: float, end_hz: float, tremolo_hz: float) -> List[float]:
    """A thin square that rises in pitch and swells, throbbing, then cuts off: a build-up."""
    count = int(RATE * duration)
    samples, phase = [], 0.0
    for i in range(count):
        t = i / count
        phase += (start_hz + (end_hz - start_hz) * t) / RATE
        throb = 0.55 + 0.45 * math.sin(2 * math.pi * tremolo_hz * i / RATE)
        swell = 0.35 + 0.65 * t
        samples.append(square(phase, 0.125) * throb * swell)
    return samples


def bubbles(count: int, each: float, low_hz: float, high_hz: float, seed: int) -> List[float]:
    """Short rising blips at falling, jittered pitches: something sinking out of sight."""
    rng = random.Random(seed)
    out: List[float] = []
    for i in range(count):
        base = high_hz - (high_hz - low_hz) * i / max(count - 1, 1)
        hz = base * rng.uniform(0.9, 1.1)
        fade = 1.0 - i / (count + 1)
        out += [s * fade for s in sweep(each, hz, hz * 1.6, duty=0.25)]
        out += [0.0] * int(RATE * each * 0.4)
    return out


def crackle(duration: float, pops_per_second: float, seed: int) -> List[float]:
    """Static that builds: short bright pops, sparse at first and thicker toward the end."""
    rng = random.Random(seed)
    count = int(RATE * duration)
    samples = [0.0] * count
    i = 0
    while i < count:
        t = i / count
        pop = noise(rng.uniform(0.006, 0.014), 9000, 3000, seed=rng.randrange(1 << 16))
        for k, s in enumerate(pop):
            if i + k < count:
                samples[i + k] += s * (0.35 + 0.65 * t)
        i += int(RATE / (pops_per_second * (0.4 + 1.6 * t)) * rng.uniform(0.5, 1.5))
    return samples


def mix(*tracks: List[float]) -> List[float]:
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


EFFECTS: dict[str, Callable[[], List[float]]] = {
    # A rising blip off the ground.
    "player_jump": lambda: sweep(0.14, 280, 760, duty=0.25),
    # A soft, low thump on landing.
    "player_land": lambda: mix(noise(0.07, 900, 200, seed=1), sweep(0.05, 120, 70)),
    # A whoosh as the sword comes round.
    "player_swing": lambda: noise(0.13, 5000, 600, seed=2),
    # A crunch as the sword lands on something.
    "player_hit": lambda: mix(sweep(0.09, 220, 90, duty=0.125), noise(0.06, 6000, 1500, seed=3)),
    # A falling warble when the Player is struck.
    "player_hurt": lambda: sweep(0.26, 620, 150, duty=0.5, vibrato_hz=28, vibrato_depth=0.08),
    # A falling run of notes when the Player's Health runs out.
    "player_defeat": lambda: notes([523, 440, 349, 262, 196], 0.11),
    # The Scavenger's wind-up: a gurgling growl that rises over the whole wind-up, so the
    # lunge can be heard coming.
    "scavenger_windup": lambda: growl(0.45, 95, 190, tremolo_hz=22),
    # Its spear thrust: a sharp, bright "shing".
    "scavenger_lunge": lambda: mix(noise(0.09, 8000, 2500, seed=4), sweep(0.06, 900, 1400, duty=0.125)),
    # Struck: a wet croak with a splash.
    "scavenger_hurt": lambda: mix(
        sweep(0.2, 320, 110, duty=0.25, vibrato_hz=38, vibrato_depth=0.15),
        noise(0.1, 3000, 500, seed=5),
    ),
    # Defeated: it burbles and sinks back into the pool.
    "scavenger_defeat": lambda: mix(bubbles(6, 0.05, 180, 520, seed=6), noise(0.3, 1800, 200, seed=7)),
    # The Storm Wisp gathering its charge: static that thickens over the whole crackle, so the
    # arc can be heard coming.
    "storm_wisp_crackle": lambda: crackle(0.7, 18, seed=8),
    # Its arc: a sharp electric snap.
    "storm_wisp_zap": lambda: mix(noise(0.18, 12000, 4000, seed=9), sweep(0.16, 1800, 600, duty=0.125)),
    # Struck: a sputtering fizz.
    "storm_wisp_hurt": lambda: mix(
        sweep(0.18, 900, 300, duty=0.125, vibrato_hz=45, vibrato_depth=0.2),
        noise(0.12, 7000, 1500, seed=10),
    ),
    # Defeated: it hisses away on the wind.
    "storm_wisp_defeat": lambda: mix(noise(0.5, 6000, 300, seed=11), sweep(0.3, 700, 180, duty=0.25)),
    # The Wraith manifesting: a high wail that rises and swells over the whole manifest, so the
    # lash can be heard coming.
    "wraith_wail": lambda: growl(0.5, 330, 620, tremolo_hz=7),
    # Its lash: a cold whoosh of claw through air.
    "wraith_lash": lambda: mix(noise(0.2, 2500, 7000, seed=12), sweep(0.14, 500, 900, duty=0.25)),
    # Struck on its anchor: a crack of stone.
    "wraith_hurt": lambda: mix(noise(0.08, 9000, 1500, seed=13), sweep(0.12, 300, 110, duty=0.125)),
    # Defeated: it sighs away into the water.
    "wraith_defeat": lambda: mix(
        sweep(0.6, 440, 110, duty=0.5, vibrato_hz=6, vibrato_depth=0.05),
        bubbles(5, 0.06, 160, 420, seed=14),
    ),
    # Menus: a soft tick as the focus moves, and a rising chime when the game starts.
    "ui_move": lambda: sweep(0.04, 880, 820, duty=0.25),
    "ui_start": lambda: notes([392, 523, 659, 784], 0.07, duty=0.5),
}


def write(path: Path, samples: List[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s / peak * PEAK)) * 32767)) for s in samples
    )
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path("assets/audio/sfx"))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, make in EFFECTS.items():
        samples = make()
        write(args.out / f"{name}.wav", samples)
        print(f"{name}.wav  {len(samples) / RATE:.2f}s")


if __name__ == "__main__":
    main()
