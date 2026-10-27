#!/usr/bin/env python3
"""Offline unit acknowledgments: original dialogue and procedural faction sounds.

Requires NumPy, Piper 1.3.0/ONNX Runtime and system libsndfile. Pass --model-dir
containing en_US-joe-medium.onnx and en_US-ljspeech-high.onnx plus
their JSON configs for Human speech only. Models/tools stay outside the game; only the rendered Oggs are shipped.
See CREDITS.txt for source-model provenance. No runtime TTS or synthesis.
"""
import argparse
import ctypes as ct
import ctypes.util
import json
from pathlib import Path
import numpy as np

RATE = 44100
OUT = Path(__file__).resolve().parent
RNG = np.random.default_rng(35001)
ROLES = ("worker", "infantry", "tank")
SCRIPTS = {
    "human": {
        "worker": {
            "select": ["Prospector standing by.", "For the People's Republic!", "Ready to build our future."],
            "move": ["Moving to the work site.", "Hover systems engaged.", "We'll get it done."],
        },
        "infantry": {
            "select": ["Vanguard ready for war.", "For the People's Republic!", "Weapons ready, Commander."],
            "move": ["Advancing for the Republic.", "Moving out.", "Together. Forward."],
            "attack": ["Target acquired. Weapons free!", "For the People's Republic! Attack!", "Vanguard engaging!"],
        },
        "tank": {
            "select": ["Paladin ready for war.", "Armor and cannon online.", "The Republic's shield is ready."],
            "move": ["Heavy armor advancing.", "Taking the new position.", "For the Republic. Move out."],
            "attack": ["Laser cannon engaging.", "Target locked. Open fire!", "Burn through their armor!"],
        },
    },
}


def timeline(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def resize(sound, frames):
    return np.interp(np.arange(frames) * len(sound) / frames, np.arange(len(sound)), sound)


def band(sound, low, high):
    freq = np.fft.rfftfreq(len(sound), 1 / RATE)
    curve = (1 - np.exp(-(freq / low) ** 4)) * np.exp(-(freq / high) ** 4)
    return np.fft.irfft(np.fft.rfft(sound) * curve, n=len(sound))


def noise(seconds, low, high):
    result = band(RNG.standard_normal(round(seconds * RATE)), low, high)
    return result / max(np.std(result), 1e-6)


def soften(sound, attack=.018, release=.06):
    sound = np.asarray(sound, dtype=np.float64).copy()
    a, r = min(round(attack * RATE), len(sound)), min(round(release * RATE), len(sound))
    sound[:a] *= np.linspace(0, 1, a)
    sound[-r:] *= np.linspace(1, 0, r)
    return sound


def room(sound, delays, tail=.65):
    """Finite, non-wrapping stereo reflections; acknowledgments never loop."""
    if sound.ndim == 1:
        sound = np.column_stack((sound, sound))
    result = np.pad(sound, ((0, round(tail * RATE)), (0, 0)))
    for delay, gain, cross in delays:
        start = round(delay * RATE)
        count = min(len(sound), len(result) - start)
        result[start:start + count] += sound[:count, ::-1] * gain if cross else sound[:count] * gain
    return result


def prepare(sound, speech=False):
    if sound.ndim == 1:
        sound = np.column_stack((sound, sound))
    sound -= sound.mean(axis=0)
    rms = np.sqrt(np.mean(sound ** 2))
    sound *= (.21 if speech else .17) / max(rms, 1e-6)
    sound = np.tanh(sound * 1.1)
    sound *= min(1, .86 / max(np.max(np.abs(sound)), 1e-6))
    # Quiet lead-in and release suppress clicks even if a command replaces a cue.
    for channel in range(2):
        sound[:, channel] = soften(sound[:, channel], .008, .08)
    return np.asarray(np.pad(sound, ((round(.02 * RATE), 0), (0, 0))), dtype=np.float32)


def load_voice(model_dir, model):
    from piper import PiperVoice, PiperConfig
    import onnxruntime as ort
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    path = model_dir / f"{model}.onnx"
    config = PiperConfig.from_dict(json.loads(Path(f"{path}.json").read_text()))
    return PiperVoice(config=config, session=ort.InferenceSession(str(path), sess_options=options, providers=["CPUExecutionProvider"]))


def speak(voice, text, pace=.95, speaker_id=None):
    from piper import SynthesisConfig
    chunks = list(voice.synthesize(text, SynthesisConfig(speaker_id=speaker_id, length_scale=pace, noise_scale=.5, noise_w_scale=.65)))
    mono = np.concatenate([chunk.audio_float_array for chunk in chunks])
    audible = np.flatnonzero(np.abs(mono) > max(np.max(np.abs(mono)) * .012, .001))
    if not len(audible):
        raise RuntimeError(f"Speech was silent: {text}")
    mono = mono[max(0, audible[0] - 400):min(len(mono), audible[-1] + 1400)]
    return soften(resize(mono, round(len(mono) * RATE / voice.config.sample_rate)))


def human(speech, role):
    # Different crew voices, with restrained radio coloration that keeps words clear.
    if role == "tank":
        speech = resize(speech, round(len(speech) / .94))
    signal = .8 * band(speech, 190, 5800) + .2 * speech
    signal = np.tanh(signal * 1.5)
    return room(signal, [(.034, .055, True), (.071, .035, False)], .13)


THEMES = {"synod": "cybernetic resonance", "kharuun": "living grove",
          "host": "celestial choir", "infernal": "abyssal growl",
          "veyr": "crystal resonance"}
THEME_REVISION = "wordless-factions-2026-10-26"


def synod(role, action, variant):
    """Wordless organic machinery: network pulses, alloy knocks and current."""
    depth = ROLES.index(role)
    seconds = 1.15 + depth * .15 + variant * .055
    t = timeline(seconds)
    base = (138, 104, 64)[depth] * (1 + .035 * (variant - 2))
    shape = np.sin(np.pi * t / seconds) ** .9
    hum = sum(np.sin(2 * np.pi * base * ratio * t + .4 * np.sin(t * 13)) / (i + 1)
              for i, ratio in enumerate((1, 1.017, 2.13, 3.91))) * .16
    current = noise(seconds, 350, 4600) * .035 * (1 + np.sin(t * 51))
    signal = (hum + current) * shape
    count = {"select": 3, "move": 4, "attack": 5}[action]
    for index in range(count):
        start = .08 + index * (.14 if action == "attack" else .21)
        local = np.maximum(0, t - start)
        gate = (t >= start) * (1 - np.exp(-local * 200)) * np.exp(-local * 24)
        frequency = base * (3.1 + ((index + variant) % 3) * .72)
        signal += (np.sin(2 * np.pi * (frequency * local + 38 * local ** 2)) * .22
                   + np.sin(2 * np.pi * frequency * 2.71 * local) * .08) * gate
    if action == "attack":
        signal += np.tanh(hum * 4) * np.exp(-t * 4) * (1 - np.exp(-t * 90)) * .32
    return room(soften(signal), [(.043, .16, True), (.097, .09, False), (.181, .04, True)], .3)


def themed(family, role, action, variant, index=0):
    """Keep each faction's sonic vocabulary, with stable unit-specific weight."""
    old_role = role if role in ROLES else ("tank" if role in {
        "destroyer", "juggernaut", "artillery", "siege_tank", "mortar"} else
        "worker" if role in {"medic", "mechanic"} else "infantry")
    # Seed each cue independently so regeneration does not depend on iteration order.
    import hashlib
    global RNG
    seed = int.from_bytes(hashlib.sha256(f"{family}/{role}/{action}/{variant}".encode()).digest()[:8], "little")
    RNG = np.random.default_rng(seed)
    sound = {"synod": synod, "kharuun": kharuun, "host": host,
             "infernal": infernal, "veyr": veyr}[family](old_role, action, variant)
    if role not in ROLES:
        pitch = .90 + index * .009
        sound = np.column_stack([resize(sound[:, channel], round(len(sound) / pitch))
                                 for channel in range(2)])
    return sound


def theme_metadata(family):
    return {"audio_theme": THEMES[family], "synthesis": "procedural",
            "voice_revision": THEME_REVISION}


def kharuun(role, action, variant):
    depth = ROLES.index(role)
    seconds = 1.2 + depth * .17 + variant * .05
    t = timeline(seconds)
    gust = np.sin(np.pi * t / seconds) ** 1.4
    leaves = noise(seconds, 1000, 11000) * (.3 + .7 * np.sin(2 * np.pi * (6 + variant) * t) ** 4)
    wind = noise(seconds, 110, 1500)
    creak = np.zeros_like(t)
    for f in (170 - depth * 32, 233 - depth * 36, 381 - depth * 52):
        phase = 2 * np.pi * (f * t + 2.6 * np.sin(t * (7 + variant)))
        creak += np.sin(phase) * .14 * np.exp(-t * .8)
    movement = (1 + .45 * np.sin(t * 18)) if action == "move" else 1
    sound = (leaves * .13 + wind * .15 + creak * (.7 + .3 * depth)) * gust * movement
    if action == "attack":
        # Branches flex and crack sharply, rather than the selection gust.
        sound += (creak * 1.2 + leaves * .25) * np.exp(-t * 6) * (1 - np.exp(-t * 100))
    return room(soften(sound), [(.073, .12, True), (.157, .05, False)], .25)


def vowel(note, seconds, formants):
    t = timeline(seconds)
    fundamental = 440 * 2 ** ((note - 69) / 12)
    phase = 2 * np.pi * fundamental * t + .16 * np.sin(t * 2 * np.pi * 4.9)
    sound = np.zeros_like(t)
    for harmonic in range(1, min(75, int(7000 / fundamental))):
        frequency = fundamental * harmonic
        weight = .015 / harmonic + sum(amplitude * np.exp(-((frequency - center) / width) ** 2)
                                      for center, width, amplitude in formants) / harmonic ** .45
        sound += weight * np.sin(harmonic * phase)
    return sound


def host(role, action, variant):
    depth = ROLES.index(role)
    seconds = 1.35 + .1 * variant
    t = timeline(seconds)
    base = 52 - depth * 5 + (2 if action == "move" else 0)
    choir = np.zeros_like(t)
    for interval, detune in ((0, -.07), (7, .06), (12, -.04)):
        choir += vowel(base + interval + detune, seconds, [(730, 110, 1), (1220, 160, .6), (2600, 280, .2)]) * .23
    organ = sum(np.sin(2 * np.pi * 440 * 2 ** ((base + interval - 69) / 12) * t) for interval in (0, 7, 12)) * .07
    bell = np.sin(2 * np.pi * (880 + variant * 73) * t + 1.2 * np.sin(2 * np.pi * 1731 * t)) * np.exp(-t * 4) * .045
    signal = (choir + organ) * np.sin(np.pi * t / seconds) ** .8 + bell
    if action == "attack":
        signal = (choir * 1.25 + organ * 1.5) * np.sin(np.pi * t / seconds) ** .45 + bell * 2.1
    return room(soften(signal, .06, .15), [(.117, .28, True), (.239, .19, False), (.397, .12, True), (.617, .07, False)], .85)


def infernal(role, action, variant):
    depth = ROLES.index(role)
    seconds = 1.05 + depth * .13 + variant * .04
    t = timeline(seconds)
    snarl = vowel(31 - depth * 4 + variant, seconds, [(280, 90, 1), (770, 150, .75), (1900, 330, .25)])
    gravel = noise(seconds, 120, 2900) * (.4 + .6 * np.sin(2 * np.pi * 34 * t) ** 2)
    shape = np.sin(np.pi * t / seconds) ** (.65 if action == "select" else 1.1)
    growl = np.tanh((snarl * 1.4 + gravel * .15) * 2) * shape
    breath = noise(seconds, 1000, 6500) * np.sin(np.pi * t / seconds) ** 3 * .07
    if action == "attack":
        growl = np.tanh((snarl * 2.1 + gravel * .3) * 2.5) * shape * (.65 + .35 * np.sin(t * 24) ** 2)
        breath *= 2
    return room(soften(growl + breath, .035, .12), [(.089, .19, True), (.203, .12, False), (.349, .06, True)], .48)


def veyr(role, action, variant):
    depth = ROLES.index(role)
    seconds = 1.55 + depth * .12
    t = timeline(seconds)
    sound = np.zeros_like(t)
    fundamental = [740, 554, 277][depth] * [1, 1.12246, .8909][variant - 1]
    for index, ratio in enumerate((1, 1.505, 2.013, 2.754, 4.109)):
        delay = index * (.075 if action == "move" else .018)
        local = np.maximum(0, t - delay)
        tone = np.sin(2 * np.pi * fundamental * ratio * local + .7 * np.sin(2 * np.pi * fundamental * 1.42 * local) * np.exp(-local * 8))
        sound += tone * np.exp(-local * (2.8 + index * .55)) * (t >= delay) / (index + 1) * .23
    sound += noise(seconds, 180, 1500) * np.sin(np.pi * t / seconds) ** 2 * .018
    if action == "attack":
        phase = 2 * np.pi * (fundamental * 3 * t + fundamental * .12 * (1 - np.exp(-t * 12)))
        sound += np.sin(phase) * np.exp(-t * 7) * .24
    return room(soften(sound, .003, .1), [(.109, .23, True), (.227, .19, False), (.383, .13, True), (.593, .08, False), (.787, .04, True)], .95)


class SoundInfo(ct.Structure):
    _fields_ = [("frames", ct.c_int64), ("samplerate", ct.c_int), ("channels", ct.c_int),
                ("format", ct.c_int), ("sections", ct.c_int), ("seekable", ct.c_int)]


def writer():
    library = ctypes.util.find_library("sndfile")
    if not library:
        raise RuntimeError("Install system libsndfile with Ogg/Vorbis support")
    lib = ct.CDLL(library)
    lib.sf_open.argtypes = [ct.c_char_p, ct.c_int, ct.POINTER(SoundInfo)]
    lib.sf_open.restype = ct.c_void_p
    lib.sf_writef_float.argtypes = [ct.c_void_p, ct.POINTER(ct.c_float), ct.c_int64]
    lib.sf_writef_float.restype = ct.c_int64
    lib.sf_close.argtypes = [ct.c_void_p]

    def write(path, sound):
        info = SoundInfo(0, RATE, 2, 0x200060, 0, 0)
        path.parent.mkdir(parents=True, exist_ok=True)
        stream = lib.sf_open(str(path).encode(), 0x20, ct.byref(info))
        if not stream:
            raise RuntimeError(f"Cannot create {path}")
        try:
            for start in range(0, len(sound), 4096):
                block = sound[start:start + 4096]
                written = lib.sf_writef_float(stream, block.ctypes.data_as(ct.POINTER(ct.c_float)), len(block))
                if written != len(block):
                    raise RuntimeError(f"Short audio write: {path}")
        finally:
            lib.sf_close(stream)
    return write


def read_audio(path):
    lib = ct.CDLL(ctypes.util.find_library("sndfile"))
    lib.sf_open.argtypes = [ct.c_char_p, ct.c_int, ct.POINTER(SoundInfo)]
    lib.sf_open.restype = ct.c_void_p
    lib.sf_readf_float.argtypes = [ct.c_void_p, ct.POINTER(ct.c_float), ct.c_int64]
    lib.sf_readf_float.restype = ct.c_int64
    lib.sf_close.argtypes = [ct.c_void_p]
    info = SoundInfo()
    stream = lib.sf_open(str(path).encode(), 0x10, ct.byref(info))
    if not stream:
        raise RuntimeError(f"Cannot decode {path}")
    try:
        result = np.empty((info.frames, info.channels), dtype=np.float32)
        frames = lib.sf_readf_float(stream, result.ctypes.data_as(ct.POINTER(ct.c_float)), info.frames)
        if frames != info.frames:
            raise RuntimeError(f"Short audio read: {path}")
        return result, info.samplerate
    finally:
        lib.sf_close(stream)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, required=True)
    args = parser.parse_args()
    import onnxruntime as ort
    ort.set_seed(35001)
    print("Loading offline speech models", flush=True)
    voices = [load_voice(args.model_dir, model) for model in ("en_US-joe-medium", "en_US-ljspeech-high")]
    write = writer()
    manifest = []
    effects = THEMES
    for family in ("human", *effects):
        for role in ROLES:
            for action in (("select", "move") if role == "worker" else ("select", "move", "attack")):
                for variant in range(1, 4):
                    text = SCRIPTS[family][role][action][variant - 1] if family in SCRIPTS else None
                    voice_metadata = {}
                    if family == "human":
                        speech = speak(voices[1 if role == "worker" else 0], text, .93 if action in ("move", "attack") else .98)
                        sound = human(speech, role)
                    else:
                        sound = themed(family, role, action, variant)
                        voice_metadata = theme_metadata(family)
                    sound = prepare(sound, speech=family in SCRIPTS)
                    path = OUT / family / f"{role}_{action}_{variant}.ogg"
                    write(path, sound)
                    manifest.append({"path": str(path.relative_to(OUT)), "family": family, "role": role,
                                     "action": action, "variant": variant, "text": text,
                                     "seconds": round(len(sound) / RATE, 3), **voice_metadata})
                print(f"Rendered {family}/{role}_{action}: 3 variants", flush=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Rendered {len(manifest)} stereo clips; {sum(x['seconds'] for x in manifest):.1f}s total", flush=True)


if __name__ == "__main__":
    main()
