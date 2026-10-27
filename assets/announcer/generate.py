#!/usr/bin/env python3
"""Render all strategic announcements with one consistent offline speech voice.

Use the same authoring dependencies as ../voices/generate.py. Pass --model-dir
with en_US-ljspeech-high.onnx and its JSON config. Source-model provenance is
recorded in ../voices/CREDITS.txt; no model or TTS tool runs in the game.
"""
import argparse
import importlib.util
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
LINES = {
    "production_started": "Building units.",
    "unit_under_attack": "Unit under attack.",
    "building_under_attack": "Building under attack.",
    "unit_lost": "Unit lost.",
    "building_constructed": "Building constructed.",
    "construction_started": "Construction started.",
    "unit_ready": "Unit ready.",
    "building_lost": "Building lost.",
    "insufficient_essence": "Insufficient essence.",
    "low_power": "Low power.",
    "power_restored": "Power restored.",
    "training_cancelled": "Training cancelled.",
    "cannot_build_here": "Cannot build here.",
    "exit_blocked": "Production exit blocked.",
    "victory": "Victory.",
    "defeat": "Defeat.",
    "draw": "Battle ended in a draw.",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, required=True)
    args = parser.parse_args()
    import onnxruntime as ort
    ort.set_seed(35003)
    spec = importlib.util.spec_from_file_location("voice_authoring", OUT.parent / "voices/generate.py")
    audio = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audio)
    voice = audio.load_voice(args.model_dir, "en_US-ljspeech-high")
    write = audio.writer()
    manifest = []
    for event, text in LINES.items():
        # One model, pace and processing chain for every faction/event. Keep
        # the announcer clear, with less radio coloration than unit responses.
        speech = audio.speak(voice, text, .98)
        signal = .9 * audio.band(speech, 120, 7800) + .1 * speech
        sound = audio.prepare(audio.room(signal, [(.045, .035, True)], .08), speech=True)
        path = OUT / f"{event}.ogg"
        write(path, sound)
        manifest.append({"event": event, "path": path.name, "text": text,
                         "voice": "en_US-ljspeech-high", "seconds": round(len(sound) / audio.RATE, 3)})
        print(event, text, manifest[-1]["seconds"], "seconds", flush=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
