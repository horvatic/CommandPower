#!/usr/bin/env python3
"""Render the original 'Iron Horizon' industrial RTS cue (NumPy + libsndfile).

Offline authoring only; the game streams the included Ogg, never synthesizes it.
No samples, recordings, or melodies from existing music are used. Run with
Python 3 + NumPy and the system libsndfile (with Ogg/Vorbis support).
"""
from pathlib import Path
import ctypes as ct
import ctypes.util
import numpy as np

RATE = 44100
BPM = 120
BEAT = 60 / BPM
# A developing suite, with recurring themes rather than a short beat loop.
SECTIONS = [
    ("Signal in the dust", 8, "intro", .25),
    ("Assembly line", 16, "groove", .65),
    ("Forward pressure", 16, "drive", .85),
    ("Iron horizon", 16, "theme", .9),
    ("Fracture", 8, "fracture", .6),
    ("The silent wells", 16, "ambient", .3),
    ("Pursuit circuit", 16, "pursuit", .7),
    ("Reconnection", 8, "build", .65),
    ("Countermarch", 16, "counter", .9),
    ("High orbit", 16, "orbit", .75),
    ("Final advance", 16, "climax", 1.0),
    ("Fallout", 8, "fallout", .5),
    ("Dust and signals", 16, "outro", .2),
]
BARS = sum(section[1] for section in SECTIONS)
LENGTH = BARS * 4 * BEAT
FRAMES = round(LENGTH * RATE)
RNG = np.random.default_rng(35000)
MIX = np.zeros((FRAMES, 2), dtype=np.float32)


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def timebase(seconds):
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def noise(t, low, high):
    """Band-limited original noise, not a sampled instrument."""
    spectrum = np.fft.rfft(RNG.standard_normal(len(t)))
    freq = np.fft.rfftfreq(len(t), 1 / RATE)
    shape = np.minimum(1, (freq / max(low, 1)) ** 2)
    shape *= np.exp(-(freq / high) ** 4)
    result = np.fft.irfft(spectrum * shape, n=len(t))
    return result / max(np.std(result), 1e-6)


def envelope(t, attack, decay, release=0.015):
    return (1 - np.exp(-t / attack)) * np.exp(-t / decay) * np.clip((t[-1] - t) / release, 0, 1)


def place(sound, beat, gain=1.0, pan=0.0):
    # Wrap effect tails across the boundary for a continuous musical loop.
    start = round(beat * BEAT * RATE) % FRAMES
    sound = np.asarray(sound, dtype=np.float32)
    stereo = sound[:, None] * (gain * np.sqrt([(1 - pan) / 2, (1 + pan) / 2]))
    split = min(len(sound), FRAMES - start)
    MIX[start:start + split] += stereo[:split]
    if split < len(sound):
        MIX[:len(sound) - split] += stereo[split:]


def kick():
    t = timebase(.48)
    phase = 2 * np.pi * (46 * t + 95 * .028 * (1 - np.exp(-t / .028)))
    body = np.sin(phase) * np.exp(-t / .12)
    click = noise(t, 1400, 7500) * np.exp(-t / .006) * .12
    return np.tanh(1.8 * (body + click)) * envelope(t, .0006, .45)


def snare():
    t = timebase(.38)
    snap = noise(t, 1200, 10000) * np.exp(-t / .075)
    shell = (.55 * np.sin(2 * np.pi * 181 * t) + .2 * np.sin(2 * np.pi * 327 * t)) * np.exp(-t / .045)
    return np.tanh((snap * .6 + shell) * 1.4) * envelope(t, .0008, .7)


def hat(opened=False):
    t = timebase(.42 if opened else .10)
    metal = noise(t, 6500, 15000)
    for f in (4327, 5861, 7927, 10433):
        metal += np.sin(2 * np.pi * f * t) * .16
    return metal * envelope(t, .0003, .095 if opened else .022)


def clang():
    t = timebase(.75)
    result = np.zeros_like(t)
    for f, decay in ((487, .24), (809, .18), (1291, .15), (2189, .08)):
        result += np.sin(2 * np.pi * f * t) * np.exp(-t / decay) * .24
    return (result + .11 * noise(t, 2000, 9500) * np.exp(-t / .025)) * envelope(t, .0005, 1)


def crash():
    t = timebase(2.0)
    return noise(t, 4500, 14000) * envelope(t, .003, .48) * .4


def bass(note, length):
    t = timebase(length)
    f = hz(note)
    signal = np.sin(2 * np.pi * f * t)
    for harmonic in range(2, 10):
        signal += np.sin(2 * np.pi * f * harmonic * t) * .45 / harmonic
    return np.tanh(signal * 1.6) * envelope(t, .004, length * 2, .025)


def chug(note, length, detune):
    """Double-tracked, damped power intervals with a filtered amp-like growl."""
    t = timebase(length + .05)
    result = np.zeros_like(t)
    for offset, weight in ((0, 1), (7, .55), (12, .25)):
        f = hz(note + offset) * detune
        # Damping closes the timbre over each muted strike.
        for harmonic in range(1, 17):
            result += weight * np.sin(2 * np.pi * f * harmonic * t + harmonic * .06) / harmonic * np.exp(-t * harmonic * 1.8)
    result += noise(t, 1500, 6000) * .12 * np.exp(-t / .018)
    result = np.tanh(result * 3)
    spectrum = np.fft.rfft(result)
    freq = np.fft.rfftfreq(len(t), 1 / RATE)
    spectrum *= (1 - np.exp(-(freq / 95) ** 2)) * np.exp(-(freq / 4200) ** 4)
    result = np.fft.irfft(spectrum, n=len(t))
    return result * envelope(t, .002, .22 if length < .2 else .7, .045)


def lead(note, length):
    t = timebase(length + .3)
    f = hz(note)
    signal = np.zeros_like(t)
    for detune in (.997, 1.003):
        phase = 2 * np.pi * f * detune * t + .12 * np.sin(2 * np.pi * 5.1 * t)
        for h in range(1, 8):
            signal += np.sin(h * phase) / h ** 1.7 / 2
    return np.tanh(signal * 1.35) * envelope(t, .022, length * 2.5, .26)


def pad(notes, seconds):
    t = timebase(seconds)
    result = np.zeros_like(t)
    for note in notes:
        for detune in (.998, 1.002):
            phase = 2 * np.pi * hz(note) * detune * t
            result += (np.sin(phase) + .14 * np.sin(phase * 2) + .06 * np.sin(phase * 3)) / len(notes) / 2
    return result * np.sin(np.pi * t / seconds) ** 1.5


def tom(note):
    t = timebase(.65)
    phase = 2 * np.pi * (hz(note) * t + 14 * .04 * (1 - np.exp(-t / .04)))
    return (np.sin(phase) + .17 * noise(t, 400, 4000)) * envelope(t, .001, .13)


def organ(note, length):
    t = timebase(length + .12)
    phase = 2 * np.pi * hz(note) * t
    signal = sum(weight * np.sin(h * phase) for h, weight in ((1, .7), (2, .6), (3, .4), (4, .2), (6, .08)))
    return np.tanh(signal * 1.8) * envelope(t, .006, length * 1.5, .07) * (.85 + .15 * np.sin(2 * np.pi * 5.7 * t))


def brass(note, length):
    t = timebase(length + .18)
    result = np.zeros_like(t)
    for detune in (.995, 1.005):
        for h in range(1, 13):
            result += np.sin(2 * np.pi * hz(note) * detune * h * t) / h * np.exp(-t * h * .65) / 2
    return np.tanh(result * 1.5) * envelope(t, .035, length * 2, .15)


def shimmer(note, length):
    t = timebase(length)
    f = hz(note)
    signal = np.sin(2 * np.pi * f * t + 1.4 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t / .18))
    return signal * envelope(t, .004, .5, .1)


def air(seconds, rising=False):
    t = timebase(seconds)
    sound = noise(t, 450 if rising else 180, 7200 if rising else 2100)
    shape = (t / seconds) ** 2 if rising else np.sin(np.pi * t / seconds) ** 2
    return sound * shape * np.clip((t[-1] - t) / .02, 0, 1) * .15


def render():
    drums = {"kick": kick(), "snare": snare(), "hat": hat(), "open": hat(True),
             "clang": clang(), "crash": crash(), "low": tom(43), "mid": tom(48), "high": tom(53)}
    cache = {}

    def voice(kind, note, duration, beat, gain, pan=0):
        note += int(note % 12 not in (0, 2, 4, 6, 7, 9, 11))  # E minor palette
        key = (kind, note, duration)
        if key not in cache:
            cache[key] = {"bass": bass, "lead": lead, "organ": organ,
                          "brass": brass, "shimmer": shimmer}[kind](note, duration)
        place(cache[key], beat, gain, pan)

    def guitar(note, duration, beat, gain):
        note += int(note % 12 not in (0, 2, 4, 6, 7, 9, 11))
        for detune, pan in ((.997, -.75), (1.003, .75)):
            key = ("guitar", note, duration, detune)
            if key not in cache:
                cache[key] = chug(note, duration, detune)
            place(cache[key], beat + (.009 if pan > 0 else 0), gain, pan)

    def hit(kind, beat, gain, pan=0):
        # Tiny timing/velocity changes give each performance a different accent.
        place(drums[kind], beat + RNG.uniform(0, .009), gain * RNG.uniform(.92, 1.04), pan)

    # Riffs span eight bars, with rests, held chords, anticipations and answers.
    riffs = [
        [(0, 0, .18), (.75, 0, .18), (1.5, 3, .3), (2.5, 0, .18), (3.25, 7, .3)],
        [(0, 0, .42), (1.25, 0, .18), (2, 5, .3), (3, 3, .18), (3.5, 2, .18)],
        [(0, 0, .18), (.5, 0, .18), (1.75, 7, .4), (3, 5, .32)],
        [(.25, 3, .3), (1, 2, .3), (2, 0, .7)],
        [(0, 0, .7), (2, 7, .22), (2.75, 0, .18), (3.5, 10, .18)],
        [(0, 0, .18), (.75, 3, .18), (1.5, 5, .4), (2.75, 3, .2)],
        [(0, 0, .18), (.5, 0, .18), (1.5, 7, .5), (3, 2, .28)],
        [(0, 5, .35), (1, 3, .35), (2.25, 2, .18), (3, 0, .3)],
    ]
    counter_riffs = [
        [(0, 0, .6), (1.75, 12, .18), (2.5, 10, .2), (3.25, 7, .24)],
        [(.5, 0, .3), (1.5, 0, .18), (2, 3, .5), (3.5, 5, .18)],
        [(0, 0, .18), (.75, 7, .18), (1.5, 5, .4), (2.75, 3, .4)],
        [(0, 2, .45), (1.5, 0, .8)],
    ]
    # An original eight-bar theme, reprised with a changed ending and countermelody.
    theme = [
        [(0, 7, .65), (1.5, 10, .35), (2.5, 14, .6)],
        [(.5, 12, .85), (2.5, 10, .3), (3.5, 7, .22)],
        [(0, 3, .8), (2, 7, .6)],
        [(.5, 5, .4), (1.75, 2, .45), (3, 0, .3)],
        [(0, 7, .4), (1, 10, .35), (2, 12, .8)],
        [(.5, 14, .55), (2, 15, .65)],
        [(0, 14, .55), (1.5, 10, .5), (3, 7, .3)],
        [(0, 5, .45), (1.5, 2, .4), (2.5, 0, .65)],
    ]
    # Absolute roots/chord qualities keep the lead in E minor across changes.
    harmonies = {
        "intro": [(28, 3), (28, 3), (24, 4), (26, 4)],
        "groove": [(28, 3), (28, 3), (31, 4), (26, 4), (28, 3), (33, 3), (24, 4), (26, 4)],
        "drive": [(28, 3), (28, 3), (26, 4), (28, 3), (24, 4), (26, 4), (28, 3), (23, 3)],
        "theme": [(28, 3), (24, 4), (31, 4), (26, 4), (28, 3), (33, 3), (24, 4), (26, 4)],
        "ambient": [(28, 3), (24, 4), (33, 3), (28, 3), (31, 4), (26, 4), (24, 4), (28, 3)],
        "pursuit": [(28, 3), (26, 4), (24, 4), (23, 3), (28, 3), (31, 4), (33, 3), (26, 4)],
        "counter": [(33, 3), (24, 4), (28, 3), (26, 4), (33, 3), (31, 4), (24, 4), (23, 3)],
        "orbit": [(24, 4), (31, 4), (26, 4), (28, 3), (33, 3), (24, 4), (31, 4), (26, 4)],
    }
    start_bar = 0
    for name, bars, mode, energy in SECTIONS:
        print(f"{start_bar * 2:3d}s  {name} ({bars} bars)", flush=True)
        for local in range(bars):
            beat = (start_bar + local) * 4
            phrase = local % 8
            progression = harmonies.get(mode, harmonies["theme" if mode == "climax" else "intro"])
            root, third = progression[(local // 2) % len(progression)]
            # Unequal orchestration arcs: add/remove parts inside each section.
            strength = energy * (.84 + .16 * local / max(bars - 1, 1))
            if mode == "outro":
                strength *= 1 - .7 * local / (bars - 1)
                root, third = (28, 3) if local >= 8 else (24, 4)
            if mode == "fracture":
                strength *= 1 - .5 * local / bars
            sparse = mode in ("intro", "ambient", "outro")

            if local % 2 == 0:
                notes = [root + 24, root + 24 + third, root + 31, root + 38]
                place(pad(notes, 4.8), beat, .25 if sparse else .14, -.35)
                place(pad([note + 12 for note in notes[1:]], 4.8), beat + .15, .11 if sparse else .05, .45)
                if sparse:
                    place(air(4.6), beat + .2, .17, .2 if phrase == 0 else -.2)

            # Each bass part has a role: sustained underscore, syncopated groove,
            # a driving riff, or an independent counterline under the main theme.
            if sparse:
                bassline = [(0, 0, 1.2)] if local % 2 == 0 else [(2.5, 7, .65)]
                if mode == "intro" and local < 4 or mode == "outro" and local >= 8:
                    bassline = []
            elif mode in ("drive", "climax"):
                bassline = riffs[phrase]
            elif mode == "counter":
                bassline = counter_riffs[phrase % 4]
            elif mode == "pursuit":
                bassline = [(0, 0, .19), (.75, 12, .18), (1.5, 7, .18), (2.25, 0, .4), (3.25, 10 if phrase % 2 else 7, .22)]
            elif mode in ("fallout", "fracture"):
                bassline = [(0, 0, .7), (2.75, 7 if phrase % 2 else 0, .4)]
            else:
                bassline = [[(0, 0, .4), (1.25, 7, .22), (2, 12, .22), (2.75, 0, .4)],
                            [(.25, 0, .3), (1, 0, .18), (2.5, 7, .35), (3.5, 10, .18)],
                            [(0, 0, .65), (2, 3 if third == 3 else 4, .3), (3.25, 7, .3)],
                            [(0, 0, .4), (1.5, 7, .4), (3, -2, .35)]][phrase % 4]
            for offset, interval, duration in bassline:
                voice("bass", root + interval, duration, beat + offset, .24 + .16 * strength)

            if mode in ("drive", "climax", "counter"):
                riff = counter_riffs[phrase % 4] if mode == "counter" else riffs[phrase]
                for offset, interval, duration in riff:
                    # Second statement changes articulation instead of duplicating.
                    hold = duration * (1.35 if local >= 8 and phrase % 2 else 1)
                    guitar(root + interval + 12, hold, beat + offset, .17 * strength)
            elif mode in ("theme", "orbit"):
                guitar(root + 12, .85 if mode == "theme" else 1.35, beat, .15 * strength)
                if phrase not in (3, 7):
                    guitar(root + 19, .25, beat + (2.5 if phrase % 2 else 3), .11 * strength)
            elif mode == "groove" and local >= 8 or mode == "pursuit" and phrase >= 4:
                guitar(root + 12, .22, beat + 1.75, .09)
                guitar(root + 19, .32, beat + 3.25, .075)
            elif mode == "fallout" and local < 4:
                guitar(root + 12, 1.15, beat, .12 * strength)

            # Kits change feel, not just volume: sparse machinery, syncopation,
            # driving rock, broken beats, tom build, and half-time aftermath.
            active = not sparse or mode == "intro" and local >= 6
            if mode == "fracture" and local >= 6:
                active = False
            if active:
                if mode in ("theme", "drive", "climax"):
                    kicks = [[0, .75, 2, 2.5], [0, 1.75, 2.5, 3.5], [0, .5, 2, 3.25], [0, 1.5, 2.75]][phrase % 4]
                    snares = [1, 3]
                elif mode == "pursuit":
                    kicks = [[0, 1.5, 2.75], [.25, 2, 3.5], [0, .75, 2.5], [0, 1.75, 3.25]][phrase % 4]
                    snares = [1, 2.75] if phrase % 2 else [1.25, 3]
                elif mode in ("fallout", "counter", "intro"):
                    kicks = [0, 2.75] if phrase % 2 else [0, 1.5]
                    snares = [2]
                elif mode == "build":
                    kicks, snares = [0, 2], [3] if local < 4 else [1, 3]
                else:
                    kicks = [[0, 1.75, 2.5], [0, .75, 2.75], [.25, 2, 3.5], [0, 1.5, 3.25]][phrase % 4]
                    snares = [1, 3]
                for offset in kicks:
                    hit("kick", beat + offset, .62 if mode != "fallout" else .48)
                for offset in snares:
                    hit("snare", beat + offset, .30 + .12 * strength, -.08)
                if phrase in (2, 5) and mode not in ("intro", "build", "fallout"):
                    hit("snare", beat + 2.5, .10, .1)
                steps = 4 if mode in ("fallout", "intro", "build") else 8
                for step in range(steps):
                    if mode == "fracture" and step % 3 == 1:
                        continue
                    opened = step == steps - 1 and phrase % 2 == 1
                    hit("open" if opened else "hat", beat + step * 4 / steps + (.018 if step % 2 else 0), .055 if step % 2 else .078, .35)
                if phrase in (1, 4, 6) and mode not in ("orbit", "fallout"):
                    hit("clang", beat + (3.25 if phrase % 2 else 1.75), .12, -.45)
                if mode == "build":
                    for offset in ([0, 1.5, 3] if local < 4 else [.5, 1.5, 2.5, 3.25, 3.75]):
                        hit("low" if offset < 2 else "mid", beat + offset, .16 + local * .015, -.25 + offset * .13)
                if local == 0 and mode not in ("intro", "build", "fracture", "fallout"):
                    hit("crash", beat, .32, -.25)
                if phrase == 7 and local != bars - 1 or local == bars - 1 and not sparse:
                    # Alternate four fills; leave breathing room before the hit.
                    fill = [[(2.5, "high"), (3, "mid"), (3.5, "low")],
                            [(3, "snare"), (3.5, "snare"), (3.75, "mid")],
                            [(2.75, "low"), (3.25, "mid"), (3.5, "high")],
                            [(2, "mid"), (2.75, "low"), (3.5, "low")]][(start_bar // 8 + local // 8) % 4]
                    for offset, instrument in fill:
                        hit(instrument, beat + offset, .22 * strength, (offset - 3) * .35)

            if mode in ("theme", "climax"):
                for offset, interval, duration in theme[phrase]:
                    note = 52 + interval
                    if mode == "climax" and local >= 8 and phrase >= 6:
                        note += (0, 3, 5)[int(offset) % 3]
                    voice("lead", note, duration, beat + offset, .12, -.12)
                if mode == "climax" and phrase % 2:
                    voice("brass", root + 31, .3, beat + 1.75, .065, .38)
            elif mode == "orbit":
                # A broad second melody with sustained notes and open space.
                orbit = [[(0, 12, 1.35)], [(1, 10, .6), (2.5, 7, .55)],
                         [(.5, 14, 1.2)], [(2, 12, .75)],
                         [(0, 15, .8), (2, 14, .65)], [(1, 10, 1.1)],
                         [(.5, 7, .8), (2.5, 5, .5)], [(0, 2, .65), (2, 0, .75)]][phrase]
                for offset, interval, duration in orbit:
                    voice("lead", 52 + interval, duration, beat + offset, .10, .1)
            elif mode in ("groove", "counter"):
                for offset in ([1.5, 3.25] if phrase % 2 else [.75, 2.5]):
                    voice("organ", root + 24, .18 if phrase % 3 else .35, beat + offset, .055, -.3)
                    voice("organ", root + 24 + third, .18, beat + offset, .035, .3)
                if mode == "counter" and phrase in (2, 3, 6):
                    voice("brass", root + 19, .42, beat + .5, .08, .1)
                    voice("brass", root + 26, .23, beat + 2.75, .055, -.35)
            elif mode == "pursuit":
                sequence = ([0, 7, 12, 3, 10, 7], [12, 7, 3, 0, 7, 14], [7, 10, 12, 19, 14, 7], [3, 0, 7, 12, 10, 2])[phrase % 4]
                for step, interval in enumerate(sequence):
                    voice("shimmer", root + 36 + interval, .65, beat + step * .625, .053, -.5 if step % 2 else .5)
            elif mode in ("ambient", "intro", "outro"):
                # Isolated answers and long echoes, with no constant arpeggio.
                if phrase in (1, 4, 6) and not (mode == "outro" and local >= 12):
                    interval = (0, 7, 12)[phrase % 3]
                    voice("shimmer", root + 36 + interval, 2.6, beat + 1.5, .075, -.4)
                    voice("shimmer", root + 36 + interval, 2.6, beat + 2.25, .028, .45)
                if mode == "ambient" and local in (4, 7, 11, 14):
                    voice("lead", 59 if local < 8 else 64, 1.2, beat + .5, .055, .1)
            elif mode == "drive" and local >= 8 and phrase in (0, 2, 5):
                voice("brass", root + 24, .45, beat + .5, .075, -.25)
                voice("brass", root + 31, .3, beat + 2.75, .055, .35)

        if mode not in ("outro", "ambient", "fallout"):
            place(air(1.9, True), (start_bar + bars) * 4 - 4, .42 if mode == "build" else .24, .1)
        if mode == "fracture":
            place(air(5.8), (start_bar + bars - 3) * 4, .4, -.3)
        start_bar += bars

    # Preserve musical headroom between the ambient chapters and the full band.
    # Each change ramps over a second, including the outro-to-intro loop seam.
    dynamics = {"intro": .7, "ambient": .65, "outro": .65, "fracture": .85, "fallout": .85}
    cursor = 0
    previous = dynamics["outro"]
    for _, bars, mode, _ in SECTIONS:
        end = cursor + round(bars * 4 * BEAT * RATE)
        gain = dynamics.get(mode, 1.0)
        MIX[cursor:cursor + RATE] *= np.linspace(previous, gain, RATE, dtype=np.float32)[:, None]
        MIX[cursor + RATE:end] *= gain
        previous, cursor = gain, end

    # Short cyclic stereo echoes and room reflections preserve tails on looping.
    dry = MIX.copy()
    for seconds, gain in ((.071, .065), (.137, .045), (.375, .10), (.75, .05)):
        MIX[:] += np.roll(dry[:, ::-1], round(seconds * RATE), axis=0) * gain
    MIX[:] -= MIX.mean(axis=0)
    MIX[:] = np.tanh(MIX * 1.05)
    MIX[:] *= .88 / np.max(np.abs(MIX))


class SoundInfo(ct.Structure):
    _fields_ = [("frames", ct.c_int64), ("samplerate", ct.c_int),
                ("channels", ct.c_int), ("format", ct.c_int),
                ("sections", ct.c_int), ("seekable", ct.c_int)]


def write_ogg(path):
    library = ctypes.util.find_library("sndfile")
    if not library:
        raise RuntimeError("Install libsndfile with Ogg/Vorbis support")
    lib = ct.CDLL(library)
    lib.sf_open.argtypes = [ct.c_char_p, ct.c_int, ct.POINTER(SoundInfo)]
    lib.sf_open.restype = ct.c_void_p
    lib.sf_writef_float.argtypes = [ct.c_void_p, ct.POINTER(ct.c_float), ct.c_int64]
    lib.sf_writef_float.restype = ct.c_int64
    lib.sf_close.argtypes = [ct.c_void_p]
    info = SoundInfo(0, RATE, 2, 0x200060, 0, 0)  # Ogg container + Vorbis codec
    stream = lib.sf_open(str(path).encode(), 0x20, ct.byref(info))
    if not stream:
        raise RuntimeError("Cannot create Vorbis file")
    try:
        # Feed bounded blocks: Vorbis encoders need not accept a whole song in
        # one call (some libsndfile builds overflow their internal work buffer).
        for start in range(0, FRAMES, 4096):
            block = MIX[start:start + 4096]
            written = lib.sf_writef_float(stream, block.ctypes.data_as(ct.POINTER(ct.c_float)), len(block))
            if written != len(block):
                raise RuntimeError(f"Short write at frame {start}: {written}/{len(block)}")
    finally:
        lib.sf_close(stream)


if __name__ == "__main__":
    render()
    output = Path(__file__).resolve().parent / "iron_horizon.ogg"
    write_ogg(output)
    print(f"{output.name}: {LENGTH:.1f}s, {BPM} BPM, stereo {RATE} Hz, {output.stat().st_size:,} bytes")
    print(f"Master peak {np.max(np.abs(MIX)):.3f}, RMS {np.sqrt(np.mean(MIX ** 2)):.3f}")
