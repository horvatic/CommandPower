#!/usr/bin/env python3
"""After deliberate roster_data.json tuning, sync new overrides and exact docs tables only."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parent.parent
data=json.loads((root/'scripts/roster_data.json').read_text())
p=root/'scripts/catalog.gd';source=p.read_text()
start=source.index('{',source.index('const FACTION_SPECS'))
end=start+1;depth=1;quoted=False;escape=False
while depth:
    ch=source[end]
    if quoted:
        if escape:escape=False
        elif ch=='\\':escape=True
        elif ch=='"':quoted=False
    elif ch=='"':quoted=True
    elif ch=='{':depth+=1
    elif ch=='}':depth-=1
    end+=1
raw=re.sub(r'Vector2\(([^)]*)\)',r'[\1]',source[start:end])
old=json.loads(raw)
for faction,entries in data['factions'].items():
    old.setdefault(faction,{})
    for kind in data['new_unit_kinds']:
        old[faction][kind]=entries['units'][kind]['spec']
    for kind in data['new_building_kinds']:
        old[faction][kind]=entries['buildings'][kind]['spec']
text='{\n'+',\n'.join('\t'+json.dumps(f)+': {\n'+',\n'.join('\t\t'+json.dumps(k)+': '+json.dumps(d,ensure_ascii=False,separators=(', ', ': ')) for k,d in entries.items())+'\n\t}' for f,entries in old.items())+'\n}'
text=re.sub(r'"size": \[([0-9.]+), ([0-9.]+)\]',r'"size": Vector2(\1, \2)',text)
p.write_text(source[:start]+text+source[end:])
def effects(d):
    a=[]
    if d.get('bonuses'):a.append('targets '+', '.join(f'{k}×{v:g}' for k,v in d['bonuses'].items()))
    for k,label in [('pierce','pierce'),('splash','blast'),('min_range','minimum')]:
        if d.get(k):a.append(f'{label} {d[k]:g}')
    if d.get('heal'):a.append(f'{"repair" if d.get("repair") else "heal"} {d["heal"]:g}/s @{d["heal_range"]:g}')
    if d.get('ward'):a.append(f'ward {d["ward"]:g} @{d["ward_range"]:g}')
    if d.get('regen'):a.append(f'regen {d["regen"]:g}/s')
    if d.get('lifesteal'):a.append(f'drain {d["lifesteal"]:g}')
    if d.get('slow',1)<1:a.append(f'slow {d["slow"]:g}/{d["slow_time"]:g}s')
    return '; '.join(a) or '—'
names={'humans':'Humans','iron_synod':'Iron Synod','kharuun':'Kharuun Brood','heavenly_host':'Aetherbound — Heavenly Host','infernal_legion':'Aetherbound — Infernal Legion','veyr':'Veyr Dominion'}
p=root/'docs/DESIGN.md';source=p.read_text()
start=source.index('#### Humans additions')
end=source.index('## Demo economy and production',start)
lines=[]
for faction,entries in data['factions'].items():
    lines.append(f'#### {names[faction]} additions\n\n| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |\n|---|---|---|---|---|---|---|\n')
    for kind in data['new_unit_kinds']:
        e=entries['units'][kind];d=e['spec']
        lines.append(f'| {kind} — {e["name"]} | {d["cost"]} / {d["time"]:g} | {d["hp"]:g} / {d["armor"]:g} | {d["damage"]:g} / {d["cooldown"]:g} | {d["range"]:g} / {d["speed"]:g} / {d["sight"]:g} | {d["class"]} / {d["radius"]:g} | {effects(d)} |\n')
    lines.append('\n| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |\n|---|---|---|---|---|---|---|\n')
    for kind in data['new_building_kinds']:
        e=entries['buildings'][kind];d=e['spec']
        lines.append(f'| {kind} — {e["name"]} | {d["cost"]} / {d["time"]:g} | {d["hp"]:g} / {d["armor"]:g} | {d["size"][0]}×{d["size"][1]} / {d["sight"]:g} | {d["power_supply"]} / {d["power_demand"]} | {d["damage"]:g} / {d["cooldown"]:g} / {d["range"]:g} | {effects(d)} |\n')
    lines.append('\n')
p.write_text(source[:start]+''.join(lines)+source[end:])
print('Synced new JSON override rows and exact expanded DESIGN tables; retained all original stats and other docs.')
