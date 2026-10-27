#!/usr/bin/env python3
"""Render Human dialogue and wordless faction themes, preserving base recordings.

Uses the same credited Piper models as generate.py. The roster and combat
capabilities come from scripts/roster_data.json. All runtime output is compressed
44.1 kHz stereo Ogg; synthesis tools and models stay outside the game package.
"""
import argparse
from concurrent.futures import ProcessPoolExecutor
import hashlib
import json
from pathlib import Path
import numpy as np
import generate as base

OUT = Path(__file__).resolve().parent
ROSTER = OUT.parents[1] / "scripts" / "roster_data.json"
FOLDERS = {"humans": "human", "iron_synod": "synod", "kharuun": "kharuun",
           "heavenly_host": "host", "infernal_legion": "infernal", "veyr": "veyr"}
# Original role codes never become expansion output paths.
ORIGINAL_ROLES = {"worker", "infantry", "tank"}
ROLE_ORDERS = {
    "scout": ("Reconnaissance ready.", "Surveying the next approach.", "Checking the flanks.", "Engaging the exposed target."),
    "skirmisher": ("Screening force ready.", "Changing our firing angle.", "Keeping the flank covered.", "Harass and withdraw."),
    "sniper": ("Precision weapon ready.", "Taking a clear firing position.", "Searching for a priority target.", "One target. One clean shot."),
    "shock": ("Assault weapons ready.", "Closing with the enemy.", "Holding the assault formation.", "Break their front line."),
    "breacher": ("Breach weapons ready.", "Moving toward their defenses.", "Preparing the opening.", "Bring down that structure."),
    "guardian": ("Defensive systems ready.", "Securing the new position.", "Covering the advance.", "Hold the line and return fire."),
    "medic": ("Restoration systems ready.", "Moving to support the formation.", "Our wounded need us.", "Protect the formation."),
    "mechanic": ("Repair systems ready.", "Approaching the repair site.", "Keep our structures operational.", "Protect the repair team."),
    "lancer": ("Armor-piercing weapon ready.", "Seeking a heavy target.", "Keeping the weapon aligned.", "Pierce their armor."),
    "suppressor": ("Area weapons ready.", "Moving to cover their approach.", "Keep their light forces contained.", "Suppress that formation."),
    "artillery": ("Long-range weapon ready.", "Taking a distant firing position.", "Keep our close approaches covered.", "Begin the bombardment."),
    "mortar": ("Bombardment systems ready.", "Setting a new firing position.", "Watching for clustered enemies.", "Saturate the target area."),
    "raider": ("Raiding weapons ready.", "Taking the outer route.", "Searching for an opening.", "Strike their exposed flank."),
    "destroyer": ("Heavy hunter ready.", "Moving to intercept their armor.", "Keep the heavy weapons forward.", "Destroy their armored spearhead."),
    "juggernaut": ("Heavy assault platform ready.", "Advancing through the battle line.", "Our advance needs protection.", "Crush their front line."),
    "disruptor": ("Disruption systems ready.", "Controlling the next approach.", "Prepare to hinder their advance.", "Disrupt the enemy formation."),
    "siege_tank": ("Siege weapons ready.", "Repositioning for siege fire.", "Keep their defenses in range.", "Reduce that strongpoint."),
    "commander": ("Command support ready.", "Reforming at the new position.", "Keep the army coordinated.", "Focus the formation on that target."),
}
FACTION_LINES = {
    "humans": ("Imperial command acknowledged.", "Technology and magic stand together.", "For humanity. Advance.", "Imperial weapons. Open fire."),
}


def dialogue(faction, name, role, action, variant):
    ready, move, purpose, attack = ROLE_ORDERS[role]
    identity, doctrine, advance, strike = FACTION_LINES[faction]
    # Every action includes a named first variant plus two tactical/faction lines;
    # unit identity is also reflected in its persistent vocal pitch and layers.
    scripts = {
        "select": [f"{name}, ready.", ready, f"{name}. {identity}"],
        "move": [f"{name}, moving.", move, f"{purpose} {advance}"],
        "attack": [f"{name}, engaging.", attack, strike],
    }
    return scripts[action][variant - 1]


def colored_voice(speech, family, role, index, action, variant):
    # Small stable unit-specific pitch differences avoid identical crew voices.
    pitch = .94 + (index % 7) * .018
    if role in {"juggernaut", "destroyer", "siege_tank"}:
        pitch -= .07
    speech = base.resize(speech, round(len(speech) / pitch))
    old_role = "tank" if role in {"destroyer", "juggernaut", "artillery", "siege_tank", "mortar"} else "infantry"
    if family == "human":
        return base.human(speech, old_role)
    raise ValueError(family)


def write_safe(path, sound, write):
    # Vorbis reconstruction can overshoot a source peak. Check decoded audio and
    # leave headroom before delivery, without touching the original recordings.
    for attempt in range(4):
        write(path,sound)
        decoded,_ = base.read_audio(path)
        peak = float(np.max(np.abs(decoded)))
        if peak < .99:
            return
        sound = sound * (.94/peak)
    raise RuntimeError(f"Unable to retain decoded headroom: {path}")


def render_family(task):
    faction, units, model_dir, force = task
    base.RNG = np.random.default_rng(35002 + list(FOLDERS).index(faction))
    family = FOLDERS[faction]
    voices = [base.load_voice(Path(model_dir), model) for model in ("en_US-joe-medium", "en_US-ljspeech-high")] if family == "human" else []
    write = base.writer()
    entries = []
    for index, (role, unit) in enumerate(units.items()):
        if role in ORIGINAL_ROLES:
            continue
        name = unit["name"]
        definition = unit["spec"]
        actions = ("select", "move", "attack") if float(definition.get("damage",0)) > 0 else ("select", "move")
        for action in actions:
            for variant in range(1,4):
                text = dialogue(faction, name, role, action, variant) if family == "human" else None
                voice_metadata = base.theme_metadata(family) if family != "human" else {}
                path = OUT/family/f"{role}_{action}_{variant}.ogg"
                if not path.exists() or force:
                    pace = .90 if action == "attack" else .96
                    if family == "human":
                        speaker = voices[1 if role in {"medic","mechanic"} else 0]
                        sound = colored_voice(base.speak(speaker,text,pace),family,role,index,action,variant)
                    else:
                        sound = base.themed(family,role,action,variant,index)
                    sound = base.prepare(sound, speech=family == "human")
                    write_safe(path,sound,write)
                    seconds = len(sound)/base.RATE
                else:
                    decoded, rate = base.read_audio(path)
                    seconds = len(decoded) / rate
                entries.append({"path":str(path.relative_to(OUT)),"family":family,"faction":faction,
                                "role":role,"unit":name,"action":action,"variant":variant,"text":text,
                                "seconds":round(seconds,3), **voice_metadata})
        print(f"Rendered {family}/{role}: {len(actions)*3} acknowledgment clips",flush=True)
    return entries


def validate():
    entries = json.loads((OUT/"manifest.json").read_text())
    hashes = json.loads((OUT/"original_hashes.json").read_text())
    for path,digest in hashes.items():
        assert hashlib.sha256((OUT/path).read_bytes()).hexdigest() == digest, path
    maximum_peak = 0.0
    maximum_boundary = 0.0
    durations = []
    decoded_hashes = set()
    for entry in entries:
        sound, rate = base.read_audio(OUT/entry["path"])
        assert rate == base.RATE and sound.shape[1] == 2 and np.isfinite(sound).all(), entry["path"]
        peak = float(np.max(np.abs(sound)))
        boundary = float(np.max(np.abs(sound[[0,-1]])))
        assert peak < 1.0 and boundary < .015 and len(sound)/rate > .1, (entry["path"],peak,boundary)
        maximum_peak = max(maximum_peak,peak)
        maximum_boundary = max(maximum_boundary,boundary)
        durations.append(len(sound)/rate)
        if entry["role"] not in ORIGINAL_ROLES:
            digest = hashlib.sha256(sound.tobytes()).hexdigest()
            assert digest not in decoded_hashes, "Duplicate expanded audio: " + entry["path"]
            decoded_hashes.add(digest)
    print(f"VOICE_DECODE_OK clips={len(entries)} original={len(hashes)} unique_expansion={len(decoded_hashes)} seconds={sum(durations):.2f} peak={maximum_peak:.6f} boundary={maximum_boundary:.6f}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir",type=Path)
    parser.add_argument("--validate-only",action="store_true")
    parser.add_argument("--workers",type=int,default=2)
    parser.add_argument("--force",action="store_true")
    args = parser.parse_args()
    if args.validate_only:
        validate()
        return
    if args.model_dir is None:
        parser.error("--model-dir is required for speech rendering")
    roster = json.loads(ROSTER.read_text())
    manifest_path = OUT/"manifest.json"
    original = [x for x in json.loads(manifest_path.read_text()) if x["role"] in ORIGINAL_ROLES]
    hashes = {x["path"]:hashlib.sha256((OUT/x["path"]).read_bytes()).hexdigest() for x in original}
    tasks = [(faction,roster["factions"][faction]["units"],str(args.model_dir),args.force) for faction in FOLDERS]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        expansions = [entry for family in pool.map(render_family,tasks) for entry in family]
    for path,digest in hashes.items():
        if hashlib.sha256((OUT/path).read_bytes()).hexdigest()!=digest:
            raise RuntimeError(f"Original unit audio changed: {path}")
    (OUT/"original_hashes.json").write_text(json.dumps(hashes,indent=2)+"\n")
    (OUT/"expansion_manifest.json").write_text(json.dumps(expansions,indent=2)+"\n")
    manifest_path.write_text(json.dumps(original+expansions,indent=2)+"\n")
    print(f"EXPANSION_VOICES_READY original={len(original)} new={len(expansions)} new_seconds={sum(x['seconds'] for x in expansions):.2f}",flush=True)


if __name__ == "__main__":
    main()
