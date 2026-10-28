#!/usr/bin/env python3
"""Synthesize Awash's start screen theme as a seamless 16-bit mono WAV loop.

Four channels in the spirit of a handheld sound chip: a lead pulse for the
melody, a thin pulse arpeggio through the chords, a soft bass, and noise for the
surf and a light hi-hat. Everything is written here, so the tune can be edited
and regenerated.

Example:
  python scripts/tools/make_music.py --out assets/audio/music
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from pathlib import Path
from typing import List, Tuple

RATE = 22050
BPM = 96
EIGHTH = 60.0 / BPM / 2
BARS = 8
LENGTH = int(RATE * EIGHTH * 8 * BARS)
PEAK = 0.6

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8,
              "A": 9, "A#": 10, "B": 11}


def hz(note: str) -> float:
    """'A4' -> 440.0."""
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTE_INDEX[name] + 12 * (octave - 4) - 9) / 12)


# Am - F - C - G, twice: a steady, slightly wistful turn for a coast in a storm.
CHORDS: List[List[str]] = [
    ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"],
] * 2
BASS_ROOTS = ["A2", "F2", "C3", "G2"] * 2

# The melody, in (note, eighths); "-" rests. Eight eighths to a bar.
MELODY: List[Tuple[str, int]] = [
    ("E5", 2), ("A4", 2), ("C5", 2), ("B4", 1), ("A4", 1),
    ("F4", 2), ("A4", 2), ("C5", 3), ("-", 1),
    ("E5", 2), ("G5", 2), ("E5", 2), ("D5", 1), ("C5", 1),
    ("D5", 4), ("B4", 2), ("G4", 2),
    ("A4", 2), ("C5", 2), ("E5", 2), ("D5", 1), ("C5", 1),
    ("A4", 2), ("F4", 2), ("A4", 2), ("C5", 2),
    ("G4", 2), ("C5", 2), ("E5", 2), ("G5", 1), ("E5", 1),
    ("D5", 3), ("B4", 1), ("G4", 2), ("-", 2),
]


def pulse(freq: float, duration: float, duty: float, volume: float,
          vibrato: float = 0.0) -> List[float]:
    """A square note with a quick attack and a gentle decay, ending at silence."""
    count = int(RATE * duration)
    out, phase = [], 0.0
    for i in range(count):
        t = i / RATE
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * 5.5 * t)) if t > 0.12 else freq
        phase += f / RATE
        attack = min(1.0, i / (RATE * 0.006))
        release = min(1.0, (count - i) / (RATE * 0.02))
        decay = 0.65 + 0.35 * math.exp(-t * 6)
        out.append((1.0 if phase % 1.0 < duty else -1.0) * volume * attack * release * decay)
    return out


def bass_note(freq: float, duration: float, volume: float) -> List[float]:
    """A soft, rounded bass: a triangle wave, like the chip's wave channel."""
    count = int(RATE * duration)
    out, phase = [], 0.0
    for i in range(count):
        phase += freq / RATE
        tri = 4 * abs((phase % 1.0) - 0.5) - 1
        release = min(1.0, (count - i) / (RATE * 0.02))
        out.append(tri * volume * release * min(1.0, i / (RATE * 0.004)))
    return out


def place(track: List[float], start: int, samples: List[float]) -> None:
    for i, s in enumerate(samples):
        j = start + i
        if j < len(track):
            track[j] += s


def melody_track() -> List[float]:
    track = [0.0] * LENGTH
    cursor = 0
    for note, eighths in MELODY:
        length = int(RATE * EIGHTH * eighths)
        if note != "-":
            place(track, cursor, pulse(hz(note), EIGHTH * eighths * 0.92, 0.25, 0.30, vibrato=0.006))
        cursor += length
    return track


def arpeggio_track() -> List[float]:
    """Chord tones in sixteenths, up and back, quiet and thin."""
    track = [0.0] * LENGTH
    sixteenth = EIGHTH / 2
    for bar, chord in enumerate(CHORDS):
        tones = [hz(n) * 2 for n in chord]
        pattern = tones + [tones[1]]
        for step in range(16):
            start = int(RATE * (bar * EIGHTH * 8 + step * sixteenth))
            place(track, start, pulse(pattern[step % 4], sixteenth * 0.8, 0.125, 0.07))
    return track


def bass_track() -> List[float]:
    """Root, root, fifth, root on the eighths, with a rest to breathe."""
    track = [0.0] * LENGTH
    for bar, root in enumerate(BASS_ROOTS):
        r = hz(root)
        pattern = [r, None, r, r * 1.5, None, r, r * 1.5, r]
        for step, f in enumerate(pattern):
            if f is None:
                continue
            start = int(RATE * (bar * EIGHTH * 8 + step * EIGHTH))
            place(track, start, bass_note(f, EIGHTH * 0.85, 0.28))
    return track


def surf_track(seed: int = 11) -> List[float]:
    """Low-passed noise swelling over two bars and back, like waves; a soft hi-hat on the offbeats."""
    rng = random.Random(seed)
    track = [0.0] * LENGTH
    two_bars = EIGHTH * 16
    level = 0.0
    for i in range(LENGTH):
        t = i / RATE
        # one swell per two bars, so the loop's end meets its start
        swell = 0.5 - 0.5 * math.cos(2 * math.pi * t / two_bars)
        cutoff = 300 + 1500 * swell
        alpha = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
        level += alpha * (rng.uniform(-1.0, 1.0) - level)
        track[i] = level * 0.22 * swell
    for step in range(BARS * 8):
        if step % 2 == 1:
            start = int(RATE * step * EIGHTH)
            hat = [rng.uniform(-1.0, 1.0) * 0.05 * math.exp(-k / (RATE * 0.01))
                   for k in range(int(RATE * 0.03))]
            place(track, start, hat)
    return track


def write(path: Path, samples: List[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    frames = b"".join(struct.pack("<h", int(s / peak * PEAK * 32767)) for s in samples)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(frames)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path("assets/audio/music"))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    tracks = [melody_track(), arpeggio_track(), bass_track(), surf_track()]
    mix = [sum(t[i] for t in tracks) for i in range(LENGTH)]
    write(args.out / "start_theme.wav", mix)
    print(f"start_theme.wav  {LENGTH / RATE:.2f}s, {BARS} bars at {BPM} BPM")


if __name__ == "__main__":
    main()
