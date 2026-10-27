#!/usr/bin/env python3
"""Original offline laser/construction sounds; NumPy and system libsndfile.

Render from any directory. No recordings or external samples are used. Short
infantry pulses and heavier tank discharges each have three authored variants.
Construction has deployment/assembly and completion/power-up cues. The game
streams these files; synthesis never runs during gameplay.
"""
from pathlib import Path
import ctypes as ct
import ctypes.util
import json
import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent
RNG = np.random.default_rng(35002)


def laser(role, variant):
    heavy = role == "tank"
    seconds = .54 if heavy else .23
    t = np.arange(round(seconds * RATE)) / RATE
    color = (.95, 1.0, 1.065)[variant - 1]
    # Exponential oscillator sweeps make an electrical snap and energy decay,
    # with no explosive gunshot, cartridge, or mechanical cycling component.
    high, low, sweep = (1120, 105, .075) if heavy else (2180, 410, .035)
    phase = 2 * np.pi * color * (low * t + (high - low) * sweep * (1 - np.exp(-t / sweep)))
    envelope = (1 - np.exp(-t / .001)) * np.exp(-t / (.115 if heavy else .047))
    core = np.sin(phase + (.9 if heavy else .45) * np.sin(phase * 1.91) * np.exp(-t / .035))
    core += .3 * np.sin(phase * .503) + .15 * np.sin(phase * 2.37) * np.exp(-t * 22)
    air = RNG.standard_normal(len(t))
    spectrum = np.fft.rfft(air)
    freq = np.fft.rfftfreq(len(t), 1 / RATE)
    spectrum *= (1 - np.exp(-(freq / 1800) ** 4)) * np.exp(-(freq / 11000) ** 4)
    air = np.fft.irfft(spectrum, n=len(t))
    sound = core * envelope + air * .10 * np.exp(-t / .009)
    if heavy:
        sound += np.sin(2 * np.pi * (67 * t + 4 * (1 - np.exp(-t / .045)))) * np.exp(-t / .14) * .48
    sound = np.tanh(sound * 1.5)
    # Small stereo ion reflections add width without a long combat wash.
    result = np.zeros((len(t) + round(.12 * RATE), 2))
    result[:len(t)] = sound[:, None]
    for delay, gain, channel in ((.027, .1, 0), (.043, .08, 1), (.079, .045, 0)):
        start = round(delay * RATE)
        result[start:start + len(t), channel] += sound * gain
    result -= result.mean(axis=0)
    result *= .80 / np.max(np.abs(result))
    attack, release = round(.001 * RATE), round(.035 * RATE)
    result[:attack] *= np.linspace(0, 1, attack)[:, None]
    result[-release:] *= np.linspace(1, 0, release)[:, None]
    # Leave room for the codec's transient pre-echo so playback starts quietly.
    return np.asarray(np.pad(result, ((round(.012 * RATE), 0), (0, 0))), dtype=np.float32)


def construction(complete):
    seconds = .98 if complete else .78
    t = np.arange(round(seconds * RATE)) / RATE
    noise = RNG.standard_normal(len(t))
    frequencies = np.fft.rfftfreq(len(t), 1 / RATE)
    filtered = np.fft.irfft(np.fft.rfft(noise) * np.exp(-(frequencies / 5200) ** 4), n=len(t))
    sound = np.zeros_like(t)
    for index, start in enumerate((.015, .19, .38)):
        local = np.maximum(0, t - start)
        active = t >= start
        envelope = (1 - np.exp(-local / .004)) * np.exp(-local / (.18 if complete else .105)) * active
        fundamental = (330, 495, 660)[index] if complete else (156, 121, 93)[index]
        phase = 2 * np.pi * (fundamental * local + 11 * (1 - np.exp(-local / .07)))
        panel = np.sin(phase) + .34 * np.sin(phase * 2.73) + .17 * np.sin(phase * 4.11)
        sound += (panel * .4 + filtered * .13) * envelope
    # Low servo/welding texture, or a rising electrical hum as systems engage.
    shape = np.sin(np.pi * t / seconds) ** 1.7
    motor = np.sin(2 * np.pi * ((92 if complete else 67) * t + (70 if complete else -18) * t * t))
    sound += motor * shape * .12 + filtered * shape * .035
    sound = np.tanh(sound * 1.3)
    result = np.zeros((len(t) + round(.12 * RATE), 2))
    result[:len(t)] = sound[:, None]
    for delay, gain, channel in ((.033, .13, 0), (.061, .1, 1), (.098, .05, 0)):
        start = round(delay * RATE)
        result[start:start + len(t), channel] += sound * gain
    result -= result.mean(axis=0)
    result *= .74 / max(np.max(np.abs(result)), 1e-6)
    result[:round(.005 * RATE)] *= np.linspace(0, 1, round(.005 * RATE))[:, None]
    result[-round(.04 * RATE):] *= np.linspace(1, 0, round(.04 * RATE))[:, None]
    return np.asarray(np.pad(result, ((round(.012 * RATE), 0), (0, 0))), dtype=np.float32)


class SoundInfo(ct.Structure):
    _fields_ = [("frames", ct.c_int64), ("samplerate", ct.c_int), ("channels", ct.c_int),
                ("format", ct.c_int), ("sections", ct.c_int), ("seekable", ct.c_int)]


def main():
    lib = ct.CDLL(ctypes.util.find_library("sndfile"))
    lib.sf_open.argtypes = [ct.c_char_p, ct.c_int, ct.POINTER(SoundInfo)]
    lib.sf_open.restype = ct.c_void_p
    lib.sf_writef_float.argtypes = [ct.c_void_p, ct.POINTER(ct.c_float), ct.c_int64]
    lib.sf_writef_float.restype = ct.c_int64
    lib.sf_close.argtypes = [ct.c_void_p]
    manifest = []
    for role in ("infantry", "tank", "construction"):
        for variant in (range(1, 3) if role == "construction" else range(1, 4)):
            sound = construction(variant == 2) if role == "construction" else laser(role, variant)
            name = ("construction_complete" if variant == 2 else "construction_start") if role == "construction" else f"laser_{role}_{variant}"
            path = OUT / f"{name}.ogg"
            info = SoundInfo(0, RATE, 2, 0x200060, 0, 0)
            stream = lib.sf_open(str(path).encode(), 0x20, ct.byref(info))
            if not stream:
                raise RuntimeError(f"Cannot create {path}")
            try:
                for start in range(0, len(sound), 4096):
                    block = sound[start:start + 4096]
                    if lib.sf_writef_float(stream, block.ctypes.data_as(ct.POINTER(ct.c_float)), len(block)) != len(block):
                        raise RuntimeError(f"Short write: {path}")
            finally:
                lib.sf_close(stream)
            manifest.append({"path": path.name, "role": role, "variant": variant, "seconds": round(len(sound) / RATE, 3)})
            print(path.name, manifest[-1]["seconds"], "seconds", flush=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
