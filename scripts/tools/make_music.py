#!/usr/bin/env python3
"""Synthesize Awash's music as seamless 16-bit mono WAV loops.

Four channels in the spirit of a handheld sound chip: a lead pulse for the
melody, a thin pulse arpeggio through the chords, a soft bass, and noise for the
surf, a light hi-hat and, where a song asks, a snare. Each song is plain data
below, so a tune can be edited and regenerated.

Example:
  python scripts/tools/make_music.py --out assets/audio/music
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

RATE = 22050
PEAK = 0.6

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8,
              "A": 9, "A#": 10, "B": 11}


def hz(note: str) -> float:
    """'A4' -> 440.0."""
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTE_INDEX[name] + 12 * (octave - 4) - 9) / 12)


@dataclass
class Song:
    name: str
    bpm: int
    # One chord per bar; the arpeggio plays its tones an octave up.
    chords: List[List[str]]
    # One bass root per bar.
    bass_roots: List[str]
    # (note, eighths); "-" rests. Eight eighths to a bar, and as many bars as chords.
    melody: List[Tuple[str, int]]
    # A noise snare on beats 2 and 4, for drive.
    snare: bool = False

    @property
    def eighth(self) -> float:
        return 60.0 / self.bpm / 2

    @property
    def bars(self) -> int:
        return len(self.chords)

    @property
    def length(self) -> int:
        return int(RATE * self.eighth * 8 * self.bars)


SONGS = [
    # The start screen: Am - F - C - G, twice; a steady, slightly wistful turn for a coast
    # in a storm.
    Song(
        name="start_theme",
        bpm=96,
        chords=[["A3", "C4", "E4"], ["F3", "A3", "C4"], ["C4", "E4", "G4"], ["G3", "B3", "D4"]] * 2,
        bass_roots=["A2", "F2", "C3", "G2"] * 2,
        melody=[
            ("E5", 2), ("A4", 2), ("C5", 2), ("B4", 1), ("A4", 1),
            ("F4", 2), ("A4", 2), ("C5", 3), ("-", 1),
            ("E5", 2), ("G5", 2), ("E5", 2), ("D5", 1), ("C5", 1),
            ("D5", 4), ("B4", 2), ("G4", 2),
            ("A4", 2), ("C5", 2), ("E5", 2), ("D5", 1), ("C5", 1),
            ("A4", 2), ("F4", 2), ("A4", 2), ("C5", 2),
            ("G4", 2), ("C5", 2), ("E5", 2), ("G5", 1), ("E5", 1),
            ("D5", 3), ("B4", 1), ("G4", 2), ("-", 2),
        ],
    ),
    # The Waking Coast: brighter and on the move. An A section along the shore in E minor
    # (Em - C - D - Em, then Em - C - D - B), and a B section that climbs before the B major
    # turn pulls it home (Am - D - G - C, Am - B - Em - Em).
    Song(
        name="waking_coast_theme",
        bpm=120,
        chords=[
            ["E3", "G3", "B3"], ["C3", "E3", "G3"], ["D3", "F#3", "A3"], ["E3", "G3", "B3"],
            ["E3", "G3", "B3"], ["C3", "E3", "G3"], ["D3", "F#3", "A3"], ["B2", "D#3", "F#3"],
            ["A3", "C4", "E4"], ["D3", "F#3", "A3"], ["G3", "B3", "D4"], ["C3", "E3", "G3"],
            ["A3", "C4", "E4"], ["B2", "D#3", "F#3"], ["E3", "G3", "B3"], ["E3", "G3", "B3"],
        ],
        bass_roots=[
            "E2", "C2", "D2", "E2", "E2", "C2", "D2", "B1",
            "A1", "D2", "G2", "C2", "A1", "B1", "E2", "E2",
        ],
        melody=[
            # A: along the shore
            ("B4", 1), ("E5", 1), ("G5", 2), ("F#5", 1), ("E5", 1), ("D5", 1), ("E5", 1),
            ("C5", 2), ("E5", 1), ("G5", 1), ("E5", 2), ("D5", 1), ("C5", 1),
            ("D5", 1), ("F#5", 1), ("A5", 2), ("G5", 1), ("F#5", 1), ("E5", 1), ("D5", 1),
            ("E5", 3), ("B4", 1), ("E5", 2), ("-", 2),
            ("B4", 1), ("E5", 1), ("G5", 2), ("A5", 1), ("G5", 1), ("F#5", 1), ("E5", 1),
            ("G5", 2), ("E5", 1), ("C5", 1), ("E5", 2), ("G5", 2),
            ("F#5", 2), ("A5", 1), ("F#5", 1), ("D5", 2), ("E5", 1), ("F#5", 1),
            ("D#5", 3), ("B4", 1), ("F#5", 2), ("D#5", 2),
            # B: climbing, then home
            ("A5", 2), ("G5", 1), ("E5", 1), ("C5", 2), ("E5", 2),
            ("F#5", 2), ("E5", 1), ("D5", 1), ("A4", 2), ("D5", 2),
            ("G5", 1), ("F#5", 1), ("G5", 1), ("B5", 1), ("D6", 2), ("B5", 2),
            ("C6", 2), ("B5", 1), ("A5", 1), ("G5", 2), ("E5", 2),
            ("A5", 1), ("C6", 1), ("B5", 1), ("A5", 1), ("G5", 2), ("E5", 2),
            ("F#5", 2), ("D#5", 1), ("B4", 1), ("D#5", 2), ("F#5", 2),
            ("G5", 2), ("F#5", 1), ("E5", 1), ("B4", 2), ("E5", 2),
            ("E5", 4), ("-", 4),
        ],
        snare=True,
    ),
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


def melody_track(song: Song) -> List[float]:
    track = [0.0] * song.length
    cursor = 0
    for note, eighths in song.melody:
        length = int(RATE * song.eighth * eighths)
        if note != "-":
            place(track, cursor,
                  pulse(hz(note), song.eighth * eighths * 0.92, 0.25, 0.30, vibrato=0.006))
        cursor += length
    return track


def arpeggio_track(song: Song) -> List[float]:
    """Chord tones in sixteenths, up and back, quiet and thin."""
    track = [0.0] * song.length
    sixteenth = song.eighth / 2
    for bar, chord in enumerate(song.chords):
        tones = [hz(n) * 2 for n in chord]
        pattern = tones + [tones[1]]
        for step in range(16):
            start = int(RATE * (bar * song.eighth * 8 + step * sixteenth))
            place(track, start, pulse(pattern[step % 4], sixteenth * 0.8, 0.125, 0.07))
    return track


def bass_track(song: Song) -> List[float]:
    """Root, root, fifth, root on the eighths, with a rest to breathe."""
    track = [0.0] * song.length
    for bar, root in enumerate(song.bass_roots):
        r = hz(root)
        pattern: List[Optional[float]] = [r, None, r, r * 1.5, None, r, r * 1.5, r]
        for step, f in enumerate(pattern):
            if f is None:
                continue
            start = int(RATE * (bar * song.eighth * 8 + step * song.eighth))
            place(track, start, bass_note(f, song.eighth * 0.85, 0.28))
    return track


def surf_track(song: Song, seed: int = 11) -> List[float]:
    """Low-passed noise swelling over two bars and back, like waves; a soft hi-hat on the offbeats."""
    rng = random.Random(seed)
    track = [0.0] * song.length
    two_bars = song.eighth * 16
    level = 0.0
    for i in range(song.length):
        t = i / RATE
        # one swell per two bars, so the loop's end meets its start
        swell = 0.5 - 0.5 * math.cos(2 * math.pi * t / two_bars)
        cutoff = 300 + 1500 * swell
        alpha = 1.0 - math.exp(-2 * math.pi * cutoff / RATE)
        level += alpha * (rng.uniform(-1.0, 1.0) - level)
        track[i] = level * 0.22 * swell
    for step in range(song.bars * 8):
        if step % 2 == 1:
            start = int(RATE * step * song.eighth)
            hat = [rng.uniform(-1.0, 1.0) * 0.05 * math.exp(-k / (RATE * 0.01))
                   for k in range(int(RATE * 0.03))]
            place(track, start, hat)
    return track


def snare_track(song: Song, seed: int = 23) -> List[float]:
    """A short, bright noise burst on beats 2 and 4 of every bar."""
    rng = random.Random(seed)
    track = [0.0] * song.length
    for bar in range(song.bars):
        for beat in (1, 3):
            start = int(RATE * (bar * song.eighth * 8 + beat * song.eighth * 2))
            hit, level = [], 0.0
            for k in range(int(RATE * 0.09)):
                level += 0.6 * (rng.uniform(-1.0, 1.0) - level)
                hit.append(level * 0.12 * math.exp(-k / (RATE * 0.025)))
            place(track, start, hit)
    return track


def render(song: Song) -> List[float]:
    eighths = sum(e for _, e in song.melody)
    assert eighths == song.bars * 8, f"{song.name}: melody is {eighths} eighths, not {song.bars * 8}"
    assert len(song.bass_roots) == song.bars, f"{song.name}: one bass root per bar"
    tracks = [melody_track(song), arpeggio_track(song), bass_track(song), surf_track(song)]
    if song.snare:
        tracks.append(snare_track(song))
    return [sum(t[i] for t in tracks) for i in range(song.length)]


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
    for song in SONGS:
        write(args.out / f"{song.name}.wav", render(song))
        print(f"{song.name}.wav  {song.length / RATE:.2f}s, {song.bars} bars at {song.bpm} BPM")


if __name__ == "__main__":
    main()
