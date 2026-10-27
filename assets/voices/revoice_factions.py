#!/usr/bin/env python3
"""Render only non-Human wordless themes; preserve Human and base themed cues.

No speech model is required. Requires NumPy and system libsndfile. Existing
Seraph Guard and the other original non-Synod effects remain byte-identical.
"""
import hashlib
import json
from pathlib import Path
import generate as base
from generate_expansion import ORIGINAL_ROLES, write_safe

OUT = Path(__file__).resolve().parent


def digest(path):
    return hashlib.sha256((OUT / path).read_bytes()).hexdigest()


def main():
    manifest_path = OUT / 'manifest.json'
    entries = json.loads(manifest_path.read_text())
    kinds = json.loads((OUT.parents[1] / 'scripts/roster_data.json').read_text())['unit_kinds']
    before = {entry['path']: digest(entry['path']) for entry in entries}
    preserved = {entry['path']: before[entry['path']] for entry in entries
                 if entry['family'] == 'human' or
                 (entry['family'] != 'synod' and entry['role'] in ORIGINAL_ROLES)}
    write = base.writer()
    changed = {}
    for entry in entries:
        family = entry['family']
        if family == 'human':
            continue
        path = entry['path']
        if path not in preserved:
            sound = base.prepare(base.themed(family, entry['role'], entry['action'],
                                            entry['variant'], kinds.index(entry['role'])))
            write_safe(OUT / path, sound, write)
            entry['seconds'] = round(len(sound) / base.RATE, 3)
            changed[path] = digest(path)
        # Remove obsolete speech-source claims, including the old Synod cast.
        for key in list(entry):
            if key.startswith('voice_') or key == 'pitch_shifts':
                del entry[key]
        entry.update(text=None, **base.theme_metadata(family))
    assert all(digest(path) == value for path, value in preserved.items())
    assert len(preserved) == 276 and len(changed) == 804
    original = json.loads((OUT / 'original_hashes.json').read_text())
    original = {path: digest(path) for path in original}
    revision_path = OUT / 'faction_theme_revision.json'
    previous = json.loads(revision_path.read_text())['previous_hashes'] if revision_path.exists() else {
        path: before[path] for path in changed}
    revision = {'revision': base.THEME_REVISION, 'themes': base.THEMES,
                'preserved_hashes': preserved, 'changed_hashes': changed,
                'previous_hashes': previous,
                'current_nonhuman_hashes': {entry['path']: digest(entry['path'])
                                           for entry in entries if entry['family'] != 'human'}}
    manifest_path.write_text(json.dumps(entries, indent=2) + '\n')
    (OUT / 'expansion_manifest.json').write_text(json.dumps([
        entry for entry in entries if entry['role'] not in ORIGINAL_ROLES], indent=2) + '\n')
    (OUT / 'original_hashes.json').write_text(json.dumps(original, indent=2) + '\n')
    revision_path.write_text(json.dumps(revision, indent=2) + '\n')
    print(f'FACTION_THEMES_READY changed={len(changed)} preserved={len(preserved)} nonhuman=900')


if __name__ == '__main__':
    main()
