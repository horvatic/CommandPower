# AGENTS.md

## Agent rules

- Use subagents whenever practical for independent tasks; provide exact scope/paths, request concise findings, and avoid duplicate work.
- Choose the approach that uses the fewest tokens while completing the request correctly.
- Every agent MUST follow user input. All edits MUST be necessary for the request; no unrelated code/files, gameplay, stats, layouts, or unsolicited refactoring.
- Only GPT agents may change core gameplay, architecture, map layout, or refactor. Other agents may make only requested small changes (e.g. stats, sprite math).
- Preserve conventions/rules; invent only delegated details. Consult `docs/DESIGN.md` before mechanic changes. Record/reuse the initial engine, factions, units, buildings, resources, economy, combat, movement, power, and build/train formulas; change locked choices only with explicit user direction. If the design document is missing, report it and establish the requested design before implementing mechanics.
- `docs/Factions.md`, once created, is the fixed faction catalog: identities, rosters, buildings, strengths, weaknesses, and tech prerequisites. Do not invent or change factions without user direction.
- Start unfamiliar sessions with `./scripts/project-context.sh` for file availability and Git status. If that script is missing, inspect the project files and Git status directly. If source/build files are missing, report that before attempting game changes or builds.
- Minimize tokens: scope `rg` searches, read matching functions/line ranges, batch independent reads, reuse findings/assets, keep output brief. `.rgignore` skips generated files; use `rg --hidden --no-ignore` only when investigating them. Compact often; preserve goals, constraints, decisions, files, checks, next steps; leave a brief handoff if compaction is unavailable.

## Project scope and availability

- **CommandPower** is a PC, simple 2D real-time strategy game: base building, resource gathering, army production, and tactical combat against an opposing commander.
- Setting: **35,000 AD**, in a far future where advanced technology, magic, and other abilities coexist. Humans field both magic users and high-tech tanks and other military units.
- The five factions are **Humans**, **Iron Synod**, **Kharuun Brood**, **Aetherbound**, and **Veyr Dominion**. Their backgrounds, unit rosters, strengths, and weaknesses are recorded in `docs/Factions.md`; preserve that catalog unless the user requests changes.
- The Kharuun Brood are an evolved intelligent plant civilization using biological and plant-based weapons. The Aetherbound comprise two continually warring subfactions: the angelic **Heavenly Host** connected to Heaven and the demonic **Infernal Legion** connected to Hell, both strong in spirit and psychic warfare.
- Galactic control: Humans **30%**, Iron Synod **30%**, Kharuun Brood **20%**, Veyr Dominion **20%**, Aetherbound **0%**. These are setting-level shares, not skirmish starting allocations.
- Every faction is at war with every other faction and seeks control of the entire galaxy. Both Aetherbound subfactions pursue this goal independently and are hostile to each other and all other factions; the angels intend to eradicate existing galactic life and start over under their control.
- Aetherbound enter through portals from Heaven or Hell. Demons seek galactic conquest for demonkind; angels seek to wipe out all galactic life and start over. Souls of deceased humans and other life forms wander Limbo instead of entering Heaven or Hell.
- God has closed the gates of Heaven and Hell and has already carried out a spacefaring version of Noah's Ark to preserve life. The closed gates explain why deceased souls remain in Limbo. Ark details and how Aetherbound portals operate despite the closure remain undefined; preserve both established lore elements.
- The repository includes a playable Godot demo, source, tests, build scripts, the faction catalog, and design document. All five factions are playable, with Heavenly Host and Infernal Legion separately selectable; Humans versus Iron Synod remains the default skirmish.
- Initial demo starting forces, economy, unit/building stats, map dimensions, prerequisites, and formulas are recorded in `docs/DESIGN.md` and `scripts/catalog.gd`. Preserve them unless the user requests changes; do not carry over creature-catching or turn-based RPG systems.

## Performance targets

- Army size is unlimited by gameplay rules: do not impose an artificial unit or population cap. Practical capacity depends on available hardware; do not promise constant performance at arbitrarily large unit counts.
- Maps should be classic Command & Conquer scale. Record exact dimensions in `docs/DESIGN.md` before implementation.
- Target at least **30 FPS** during normal play at the documented map scale. Record reference hardware and benchmark unit/building counts in `docs/DESIGN.md` so the target is measurable; rendering FPS does not define the simulation tick rate.

## Presentation

- Art direction: old-school **2D isometric RTS**, with a **2:1 diamond projection**, upright units and elevated buildings, readable terrain, distinct silhouettes, and clear team colors. Use `scripts/projection.gd` for rendering and input conversion; simulation coordinates and gameplay balance remain unchanged by projection.
- Visual fidelity should evoke **Command & Conquer: Tiberian Sun**: original pre-rendered industrial artwork, convincing lighting and volume, weathered surfaces, fine machinery detail, and gritty continuous terrain. Avoid flat cartoon shapes, obvious checkerboard ground, and excessive neon trim.
- All art must look convincing without animation. Units must have **no visible legs or feet** and must not require walk/run/crawl or wing-flapping cycles. Use enclosed vehicle chassis, hover platforms, pods, floating plants, legless spirits, or suspended crystals; translation and facing changes are sufficient. Optional effects cannot be necessary for an asset to look complete. Preserve this rule in models, baked sprites, and procedural fallbacks, along with faction identities, unit roles, stats, and ground-navigation rules.
- Mobile units have a cosmetic hover bob defined in `docs/DESIGN.md`. Move only the rendered body/status indicators, with shadows and selection rings anchored to the ground; picking must follow the body offset. Use simulation time so pause/end freezes the effect, and never change movement, collision, targeting, visibility, or radar coordinates to implement it.
- Each faction has its own unit art style and silhouettes, not just a team-color swap: Human industrial armor, Iron Synod organic cybernetics, Kharuun plants, Heavenly Host angels, Infernal Legion demons, and Veyr crystalline geometry. Shared render styles are in `scripts/faction_sprites.gd`; all six selectable sides are playable in the demo.
- Human Prospector art must use a wheel-free, continuous hover hull without wheel-like side pods or tread belts. Vanguard art must show an actual human operator in an open hover vehicle, with visible head/face, upper body, and hands, while concealing legs and feet. Preserve these details in both baked sprites and fallback artwork.
- Runtime sprites use baked atlases in `assets/sprites/`. Original offline 3D models and materials are authored in `scripts/sprite_models_3d.gd`; `scripts/faction_sprites.gd` handles runtime drawing and overlays. After model/material changes, regenerate with `.tools/godot --path . --script res://scripts/bake_sprites.gd` using a graphical renderer, import resources, and rebuild. Keep selection, health, and construction overlays dynamic; do not regenerate body geometry or the static terrain every frame.
- Terrain textures and props are authored by `assets/terrain/generate.py` (Python, NumPy, Pillow), then imported for `scripts/terrain_art.gd`. Regeneration is optional for ordinary builds; the generated original PNG assets are included. Art passes must preserve map geometry, resource positions, fog, and hit/placement rules.
- HUD: a classic Command & Conquer-inspired right-hand sidebar, with radar/minimap near the top, resource and power indicators, and icon-based construction/production controls with visible progress. Keep the battlefield as the main view and show selected-unit information and available commands clearly.
- Preserve this visual direction as features are added; use consistent sprite scale, icon style, and UI typography. Record concrete asset and layout specifications in `docs/DESIGN.md`.

## Battlefield and controls

- A match runs continuously on one battlefield with opposing bases, resource deposits, traversable ground, and obstacles. Use match maps rather than town/wild-area loading zones.
- Support mouse selection of individual units, drag-box selection of multiple units, additive selection with Shift, and visible selection indicators. Only the player's units and buildings accept orders.
- Right-click issues a context order: move to ground, attack an enemy, or gather from a resource deposit with a capable worker. Provide explicit attack-move, stop, and hold-position commands, control groups, and clear command feedback.
- Units navigate around terrain, buildings, and one another. Orders for multiple units should spread destinations so the army does not stack on a single point. Unreachable destinations must fail gracefully.
- Provide camera scrolling, a minimap, and clear boundaries. Keep world commands from passing through HUD controls.
- Camera keys are **WASD** and arrows. Attack-move is **E**, stop is **X**, and hold position is **H**; keep hints and controls consistent and avoid WASD command conflicts.
- Fog of war tracks unexplored, explored, and currently visible terrain. Hidden enemies must not expose current positions or accept new direct attack orders; previously explored terrain remains visible. Apply the same visibility rules to AI decisions.
- Multiplayer and procedural maps are outside the initial scope unless requested; the initial match is single-player against AI.

## Economy, bases, and production

- Every faction, including both Aetherbound subfactions, can use **Limbo spirit energy to produce more units**. The shared currency is **spiritual essence**, which grows around **spiritual wells**, can be harvested, and regrows over simulation time. Do not add automatic income from kills or resurrection.
- Workers harvest essence growth around wells and deliver cargo to an eligible friendly Refinery or Command Center. Credit essence on delivery; harvesting, travel, and regrowth take simulation time. Wells themselves are not harvested. The demo has one currency, not separate ore and spirit reserves.
- After completing construction, the builder resumes harvesting automatically, preserving carried essence and preferring its previous valid visible patch. A full cargo load must be delivered first; manual orders to workers that left the construction job remain respected.
- Spend resources on buildings, units, and upgrades. Show costs and prerequisites before issuing an order; reject unaffordable or invalid orders without deducting resources.
- Building placement requires valid terrain, an unobstructed footprint, and the documented construction prerequisites. Construction takes time, and incomplete structures must follow the documented activation rules.
- Use functional building roles: **Command Center**, **Power Plant**, **Refinery**, **Barracks**, and **Factory**. Record faction-specific names and differences in `docs/Factions.md`; use entity kind for appearance and behavior, not display names.
- Command Centers anchor bases and support worker production; Refineries receive harvested resources; Barracks and Factories produce their documented unit classes. Define power generation, consumption, and low-power effects in `docs/DESIGN.md` before implementation.
- Production uses visible queues and build/train timers. Validate prerequisites and power rules where applicable; do not impose a population cap. Charge each order once; document cancellation refunds and behavior when the producing structure is destroyed.
- Spawn completed units at an available exit and send them toward the structure's rally point; handle blocked exits without overlapping or losing units.
- Keep building names consistent across buttons, headers, tooltips, world labels, and the minimap. Never truncate names so their meaning is lost. Search case-insensitively and inspect the relevant UI after label changes.

## Combat, AI, and match state

- Multiple units fight simultaneously in real time. Record health, damage, armor, attack range, cooldown, movement speed, target restrictions, and any counters in the design documents; do not inherit levels, XP, capture, fusion, party limits, or other RPG rules.
- Use simulation time for movement, harvesting, construction, production, and combat so behavior does not depend on rendering frame rate. Pause freezes the entire simulation.
- Respect targeting range, visibility, cooldowns, and valid target types. Define damage formulas and projectile behavior once and reuse them for player and AI units.
- Matching player and AI unit/building roles must use identical health and damage values, without owner-specific bonuses. Preserve the shared combat rules recorded in `docs/DESIGN.md`.
- AI gathers resources, builds a base, produces units, and attacks/defends using the same costs, prerequisites, timing, and visibility rules as the player. Cheats or difficulty bonuses require explicit design approval.
- Define starting resources, workers, structures, spawn positions, and win/loss conditions in `docs/DESIGN.md`. End a match when the documented condition is met, show Victory/Defeat, and stop further simulation orders.
- Keep selection, orders, economy, production, combat, and match state separate enough to test without the rendered interface; avoid unrelated architectural work.

## Build and run

- Godot 4.5.1 stable/GDScript; Linux x86-64, OpenGL 3.3. Tools: Bash, curl, unzip, zip, rg.
- Close packaged game before rebuilding; edit source, never generated `dist/` files. Run tests after mechanic changes.
- Build and verify with:

```bash
cd /home/shawn/projects/CommandPower
[[ -x .tools/godot ]] || ./scripts/setup-engine.sh
./tests/run.sh
./scripts/build.sh
```

- The build workflow should import resources, export `CommandPower.pck`, bundle `.tools/godot` as `CommandPower` with a launcher, README, and licenses, then create a ZIP. Temporary Godot directories must isolate builds from player saves.
- Intended output: `/home/shawn/projects/CommandPower/dist/CommandPower-linux-x86_64/`; sibling archive `CommandPower-linux-x86_64.zip`. Keep executable, pack, and notices together; no separate engine install needed.
- Intended launchers from the project root: `./run.sh` for source; `./dist/CommandPower-linux-x86_64/play.sh` for the package.
- Test selection/command ownership, resource delivery and spending, placement validity, production/cancellation, blocked exits, movement, combat timing, fog/AI visibility, pause, and victory/defeat when those systems are implemented. Verify package startup with an isolated profile and the documented starting match state.

## Saves and reset

- Do not add persistence unless requested. If implemented, document the save schema and whether it stores settings, progression, or resumable matches. Keep player state separate from test/build data.
- For requested resets, close all game copies and delete the exact requested save directly; NEVER create backup copies, archives, or safety copies. Do not touch another project's saves.
- Intended default directory if saves are implemented: `/home/shawn/.local/share/godot/app_userdata/CommandPower/`. Check `COMMANDPOWER_SAVE_PATH`/`XDG_DATA_HOME` overrides and the implemented filename first. Delete the exact save plus its `.bak` and `.tmp` recovery files; leaving recovery files can restore old progress.
- Verify the requested save and both recovery files are absent; leave logs, shader caches, and unrelated settings intact. Outside-workspace deletion may require `exec_command` with `sandbox_permissions: "require_escalated"`; report denials, never bypass/ignore them.
- Rebuilding must not reset player state. Reset and overwrite actions require an in-game confirmation. Test saves must always use a separate path and must never overwrite player saves.
