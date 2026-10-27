# CommandPower design

## Status and established direction

This document records the approved setting and the initial playable demo defaults. The Godot demo implements configurable one-versus-one AI skirmishes with all five factions; the Aetherbound have two separately selectable, mutually hostile subfactions. Agent workflow and build requirements remain in `../AGENTS.md`; faction backgrounds and full unit concepts are cataloged in `Factions.md`. Runtime balance data lives in `../scripts/catalog.gd`.

## Setting and galactic control

- The year is **35,000 AD**. Advanced technology, magic, psychic powers, and other abilities coexist.
- Every faction is at war with every other faction and seeks control of the entire galaxy. The Heavenly Host and Infernal Legion pursue galactic control separately and are hostile to each other and to all other factions. The angels intend to use that control to eradicate all existing galactic life and start over.
- Humans control **30%** of the material galaxy; Iron Synod **30%**; Kharuun Brood **20%**; Veyr Dominion **20%**; Aetherbound **0%**. These narrative shares total **100%**; they do not determine skirmish starting resources, map ownership, or balance bonuses.
- The Aetherbound enter the galaxy through portals from Heaven or Hell. Their home realms are outside this territorial division.
- The demonic Infernal Legion seeks to conquer the galaxy for demonkind. The angelic Heavenly Host seeks to eradicate all life in the galaxy and start over. The two remain at war with one another.

## The closed gates and the Ark

- God has **closed the gates of Heaven and Hell**, leaving the souls of deceased life forms in Limbo.
- God has **already carried out a spacefaring version of Noah's Ark**, preserving life aboard an ark in space before the current setting of 35,000 AD.
- The Ark's exact date, passengers, destination, and current location remain undefined. No Ark-related gameplay is established by this lore.
- Aetherbound arrival through portals remains established. How those portals operate despite the closed gates remains undefined.

## Limbo and unit production

- When humans or other life forms die, their souls no longer enter Heaven or Hell because God has closed the gates; they wander Limbo.
- **All factions can use Limbo spirit energy to produce more units**, including both Aetherbound subfactions.
- Limbo spirit energy is distinct from a base's electrical power generation and consumption. It does not remove the existing requirement to define production costs, queues, prerequisites, and timing.
- Spiritual essence grows around spiritual wells, can be harvested by workers, and regrows over simulation time. Workers deliver their cargo to a completed friendly Refinery or Command Center; currency is credited only on delivery. The wells themselves are not harvested.
- Essence is the demo's sole currency for units and buildings, replacing the separate material-resource and starting-spirit-reserve proposals. There is no passive base income or reward for kills. Harvesting is not established to damage or consume individual souls.
- Producing units with spirit energy does not by itself resurrect fallen units, preserve their identities, or bypass documented production rules.
- Aetherbound arrival portals are established, but their placement, construction, costs, and interaction with production remain undefined. They do not imply free or instantaneous reinforcements.

## Demo scope and starting state

- Godot **4.5.1 stable**, GDScript, Linux x86-64, OpenGL compatibility renderer. Four handcrafted battlefields, **32 px** per tile. **The Silent Wells** remains the default **96 × 64** tile (**3072 × 2048 px**) battlefield; additional sizes are recorded below.
- Select any playable side for the player and the AI, including mirror matches. Humans versus Iron Synod remains the default. Both start with **900 essence**, a completed Command Center, Power Plant, Refinery, **3 workers**, and **2 infantry** at opposite corners. Starting workers automatically harvest nearby growth.
- Each side retains its original worker, frontline unit, and heavy unit, and adds the 18 units and eight faction-specific structures recorded in the expanded-roster section. Workers, the five original buildings, and the original frontline/heavy values remain unchanged.
- Win by destroying the enemy Command Center; lose when yours is destroyed. Simultaneous loss is a draw. The simulation and orders stop at match end. Command Centers cannot be rebuilt or multiplied in this demo.
- No population or army cap. The expanded roster includes its documented automatic combat/support abilities. Manual spells, upgrades, Aetherbound portals, campaigns, and persistence remain outside this demo.

## Title screen and skirmish creation

- Startup displays a separate title screen with six heavy-unit portraits, **Skirmish**, **Settings**, and **Quit**. Menus do not advance simulation time or accept battlefield orders.
- **Create Skirmish** selects the battlefield, each commander's faction and army color, and Easy/Normal/Hard difficulty. All 36 pairings are supported, including mirror matches and Heavenly Host versus Infernal Legion. No faction randomization, multiplayer, or procedural maps are introduced.
- Defaults are Humans versus Iron Synod on Normal. A completed setup creates a fresh match. Restart retains the map, faction choices, army colors, and difficulty. Results offer a new setup or title screen; Main Menu inside Settings / Pause confirms before discarding a running match. Session audio choices survive menu navigation and restarts.
- Full faction names, roster counts, and the original core unit names appear in setup. HUD labels, queue text, icons, world labels, construction previews, voices, and destruction snapshots use the chosen faction independently of player/enemy ownership. The original five functional building names remain shared; the eight added structures use their faction-specific names.
- Menu cards use the existing gunmetal theme, 32 px margins, a 520 px content column, full-width buttons, and at least 38 px selectors. The setup shows the selected map size, equal starting resources and unit counts, and victory condition before deployment. Both menus fit the 1100 × 720 minimum viewport.

### Skirmish maps and army colors — 2026-10-26

The map selector adds three authored layouts while preserving The Silent Wells exactly. Map dimensions govern navigation, fog, camera bounds, radar, terrain, placement, and orders independently for each match.

| Map | Size | Tiles | Simulation pixels | Wells |
|---|---|---|---|---:|
| The Silent Wells | Medium (default) | 96 × 64 | 3072 × 2048 | 6 |
| Ashen Crossing | Small | 72 × 48 | 2304 × 1536 | 6 |
| Shattered Basin | Large | 128 × 96 | 4096 × 3072 | 8 |
| Frontier Reach | Huge | 160 × 112 | 5120 × 3584 | 10 |

New layouts use mirrored resource pairs and obstacles, open base corners, and traversable routes between bases. Each base retains the existing corner-relative starting positions, buildings, three workers, two infantry, and 900 essence. Every well retains eight growth patches with the original harvest, capacity, and regrowth formulas. Match rules and all unit/building values are unchanged. Larger maps increase travel distances and available territory; no new performance guarantee or army cap is introduced.

Each commander selects Teal, Orange, Blue, Red, Gold, Violet, White, or Pink independently of faction. Teal versus Orange remains the default. Both commanders must have different colors; selecting the other commander's color automatically assigns that commander a different available color. Army colors appear on unit/building accents, ownership markers, selection indicators, and radar, including newly produced units and mirror-faction matches. Faction silhouettes and materials remain distinct. Choices last through restarts and menu navigation within the session; no persistence or multiplayer is added.

Verification: all **22 suites** pass. Focused coverage includes **4,853 map checks**, **361 army-color checks**, and **289 setup integration checks**. All four layouts and a blue-versus-gold Human mirror match were rendered and inspected with OpenGL 3.3 on the reference GPU; setup fits the **1100 × 720** minimum viewport. The rebuilt Linux package passes setup/color checks, isolated-profile startup, and ZIP integrity. Large terrain caches are limited to 8192 pixels wide; sprite paint is prepared once per faction/role/facing/color and shared across units.

### Explored-map performance correction — 2026-10-26

The radar previously emitted one terrain polygon for every explored cell on every HUD redraw (up to **17,920 polygons** on Frontier Reach), causing severe frame stalls as exploration accumulated. It now draws one cached terrain texture with one texel per simulation cell. The texture updates only when the simulation replaces its fog dictionaries or the map changes; camera movement, zoom, and unchanged frames reuse it. Visible units, explored wells, camera outlines, map input, and fog eligibility keep their existing rules. This changes rendering only, with no gameplay, simulation timing, layout, or balance changes.

Rendered diagnostics on the documented Ryzen 7 7800X3D / RTX 4070 SUPER reference machine at **1366 × 864**, OpenGL 3.3 and VSync disabled, used the normal **16 starting entities** (six buildings and ten units), AI disabled, **60 warm-up frames**, and **six wall-clock seconds** per scenario. Fully explored means every map cell is explored while current visibility remains normal. Before/after source-build results:

| Fully explored map | Radar redraw average before / after | Frame time average before / after | Frame time p95 before / after |
|---|---:|---:|---:|
| The Silent Wells (96 × 64) | 47.30 / 0.64 ms | 18.82 / 0.98 ms | 87.75 / 1.14 ms |
| Frontier Reach (160 × 112) | 144.97 / 1.70 ms | 241.82 / 1.01 ms | 274.82 / 1.14 ms |

The fully explored huge-map diagnostic improved from approximately **4 FPS** to **987 FPS** with VSync disabled. These are small-army diagnostic results on the reference machine, not guarantees for other hardware or uncapped armies. All **23 suites (25,868 checks)** pass. **139 minimap-cache checks** cover fog colors, all map sizes, unchanged-frame reuse, map/reset/world invalidation, and radar navigation. A rendered fully explored Frontier Reach minimap was visually inspected; the battlefield remains fogged normally and hidden enemies are absent from radar.

| Playable side | Command Center worker | Barracks frontline | Factory heavy |
|---|---|---|---|
| Humans | Prospector | Vanguard | Paladin Tank |
| Iron Synod | Synapse Harvester | Convergent Legionary | Chimera Tank |
| Kharuun Brood | Root Tender | Barkguard | Seedspine |
| Aetherbound — Heavenly Host | Sanctifier | Seraph Guard | Sanctum Colossus |
| Aetherbound — Infernal Legion | Ashshaper | Hellblade | Infernal Behemoth |
| Veyr Dominion | Shard Tender | Crystal Guard | Monolith |

Workers use the shared row below. Original frontline and heavy units use the core faction balance table; Humans retain the original infantry/tank rows. Those original heavy attacks retain single-target immediate damage with a beam tracer. The added units use the explicit expanded combat/support rules below. Wings, hovering plants, and suspended crystals obey ground navigation and ordinary fog of war. Building appearance is faction-specific; Command Center, Power Plant, Refinery, Barracks, and Factory remain the displayed functional names for each side.

## Faction playstyles and balance

All six selectable sides have distinct combat styles. These values apply equally to either commander and every AI difficulty; ownership never modifies a faction's stats. Starting resources, starting unit counts, workers, the five original building values, economy, original power/prerequisites, footprints, collision radii, and navigation remain unchanged. New roster entries follow the expanded specifications below.

| Playable side | Playstyle | Tradeoff and counterplay |
|---|---|---|
| Humans | Flexible combined arms with balanced frontline and tanks | No extreme specialization; combine roles against specialist armies |
| Iron Synod | Resilient hybrid assault units deliver rapid, sustained fire | Expensive replacements and smaller individual hits; heavy armor reduces their damage efficiency |
| Kharuun Brood | Cheap, quickly grown mass armies that replace losses rapidly | Each demo combat unit has low health and damage; strong armor blunts their small attacks |
| Heavenly Host | Armored defensive elites that hold ground through sustained fire | Expensive, slow reinforcements and shorter range; vulnerable to kiting and distant objectives |
| Infernal Legion | Fast, hard-hitting assaults that punish exposed targets | Fragile armor and short weapon range; prepared defenses can punish their approach |
| Veyr Dominion | Slow, heavily armored siege formations with long reach | Highest costs and long training times; raids and flanking attacks stretch their formations |

| Faction | Role | Essence | Train s | HP | Damage | Armor | Range px | Cooldown s | Speed px/s | Sight px |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Humans | Infantry | 80 | 8 | 110 | 12 | 0 | 150 | 0.8 | 88 | 330 |
| Humans | Tank | 220 | 16 | 420 | 48 | 4 | 230 | 1.6 | 68 | 380 |
| Iron Synod | Infantry | 100 | 10 | 140 | 9 | 2 | 150 | 0.5 | 92 | 330 |
| Iron Synod | Tank | 260 | 19 | 500 | 30 | 5 | 210 | 0.9 | 70 | 380 |
| Kharuun Brood | Infantry | 40 | 4 | 65 | 8 | 0 | 135 | 0.8 | 92 | 330 |
| Kharuun Brood | Tank | 140 | 10 | 260 | 32 | 2 | 220 | 1.6 | 64 | 380 |
| Heavenly Host | Infantry | 120 | 12 | 180 | 12 | 3 | 140 | 1.0 | 72 | 330 |
| Heavenly Host | Tank | 330 | 24 | 650 | 48 | 7 | 210 | 1.9 | 52 | 380 |
| Infernal Legion | Infantry | 70 | 7 | 85 | 18 | 0 | 100 | 0.7 | 118 | 330 |
| Infernal Legion | Tank | 200 | 15 | 340 | 64 | 2 | 170 | 1.4 | 84 | 380 |
| Veyr Dominion | Infantry | 115 | 12 | 160 | 16 | 4 | 190 | 1.1 | 60 | 350 |
| Veyr Dominion | Tank | 360 | 26 | 700 | 60 | 9 | 290 | 2.0 | 44 | 420 |

**Iron Synod sustained assault:** Convergent Legionaries and Chimera Tanks combine above-Human health and armor with shorter attack cooldowns and smaller damage per shot. Their modest mobility supports a steady advance, while their costs and training times punish careless losses. The shared damage formula applies armor to every shot, so heavily armored targets blunt their rapid fire. All factions use ordinary fog of war: enemy units on currently visible terrain are visible and targetable, regardless of distance to an observer or recent firing. Own units remain visible. These differences add no support aura, regeneration, or special visibility rules.

These original unit values remain the baseline. The expanded roster below adds explicitly priced support, area attacks, and gravity disruption. Portal production and manual spells remain outside the implementation.

## Expanded faction rosters — 2026-10-26

The roster expansion adds **18 new units and eight new buildings to each independently selectable side**, including Heavenly Host and Infernal Legion separately: **21 units and 13 buildings per side**, **126 faction/unit combinations and 78 faction/building combinations**. The original three unit and five building stat rows remain unchanged. All new mobile forms retain ground navigation and static, legless, faction-specific artwork. The original setting, map, resource loop, starting match, win condition, AI fairness, no army cap, and removed concealment system remain unchanged. This section supersedes earlier three-role demo-only scope limits.

Every new unit has its own faction name, appearance, combat profile, role-specific acknowledgments, and counters. Common role keys allow consistent commands and counter selection; they are not alternate faction identities. Humans combine piercing specialists and support wards; Synod uses rapid hybrid fire and disengagement repair; Kharuun cultivates cheap regenerating plants and sap/pollen area denial; the Host protects costly slow formations with strong wards; the Legion attacks quickly with fragile, draining assault forms; Veyr uses slow, costly piercing artillery and gravity suppression.

The new units were tuned with repeated equal-budget combat sweeps. Costs, durability, damage, range, and faction perks are listed exactly below; original unit and building values remain fixed. The final mirrored-fixture results and their limits are recorded under expanded-roster verification.

### Defensive building and artillery range increase — 2026-10-26

All armed defensive buildings (sentry, bastion, and Veyr’s armed Stasis Nexus relay) and the artillery, mortar, and siege_tank unit roles have **25% more maximum weapon range**, rounded to one simulation pixel decimal place. The exact updated faction values appear in the tables below. Matching player and AI roles use the same values. Sight and minimum firing distances retain their existing values, so scouts are required when weapon reach exceeds vision. All other stats and combat rules remain unchanged.

Validation: **20,387 checks pass across 20 suites**, including 284 new range-boundary checks for all affected roles and both owners. The rebuilt Linux package starts under an isolated profile and contains all 31 updated faction ranges; ZIP integrity passes. The existing **90 mirrored equal-budget combat fixtures** completed with scored results (draws count half): humans 66.7%, iron_synod 58.3%, kharuun 56.7%, heavenly_host 48.3%, infernal_legion 43.3%, veyr 26.7%. These are fixed-composition results; Humans and Veyr scored 66.7% and 26.7% respectively in this sweep, so further faction balance tuning would require a separate change. The earlier expanded-roster sweep below predates this range increase.

### Shared expanded combat rules

- Classes are **light**, **heavy**, and **structure**. Existing workers/frontline units are light, tanks heavy, and buildings structures. Damage is **max(1, damage × class bonus − max(0, target armor + strongest allied ward − armor piercing))**. Missing class bonuses are 1. Piercing removes armor points; it does not multiply raw damage.
- Splash applies the same per-target formula to hostile, currently visible targets whose centers lie within the listed impact radius. It never damages friendlies or reveals hidden units. No weapon can shoot inside its listed minimum range. Long-range siege needs scouts where its range exceeds sight.
- A healer restores **heal × simulation dt** to the single living, completed friendly target with the lowest HP fraction in range, excluding itself and capping HP at max. `repair=true` restricts its targets to structures; otherwise only mobile allies qualify. There is no resurrection or healing of incomplete structures. Unarmed heal/repair supports on attack-move pause their advance only while an eligible wounded ally is actually inside healing range, so they can restore that ally rather than stalling too far away. They continue toward their attack-move destination when no wounded ally is in range. Direct movement orders still control their position normally. Structure-repair specialists remain at the AI base instead of joining its attack army.
- Wards add the **strongest** living, completed allied emitter's armor bonus within its center-based range, including the emitter itself. Wards never stack.
- Regeneration restores the listed self HP/second only after **three simulation seconds without taking damage**. Dead/incomplete entities never regenerate. Lifesteal restores its fraction of actual victim HP removed, capped at the victim's remaining HP and the shooter's max HP; it produces no essence and never resurrects.
- Slowing weapons apply the listed movement multiplier for their simulation-time duration. Each factor retains its own expiry timer, so a longer weaker slow can remain after a shorter stronger one expires. The strongest active factor applies; effects never multiply, and a hit may refresh that factor's duration. All abilities, cooldowns, healing, regeneration, slowing, and production freeze with pause/end.
- Powered armed/support buildings stop their weapons, healing, regeneration, and wards during low power. Production queues retain the existing half-speed low-power rule. Mobile support works independently of base electricity. Incomplete structures provide neither power nor support nor weapons.
- Every player and AI faction uses identical costs, prerequisites, values, abilities, fog, construction, paid queues, cancellation refunds, exits, and gathering. No free income, units, tactical teleportation, conversion, air travel, or concealed movement is introduced.

### Production and prerequisites

All buildings require the existing valid placement, worker, Command Center, and nearby completed friendly structure. Builders approach a walkable point outside the expanded footprint and finish the last approach within three pixels, including diagonal corners; the same precise approach permits reliable cargo delivery. Additional completed-building prerequisites are listed below. Units require their completed friendly producer plus any additional prerequisite. These checks apply before charging; queued units retain their paid price and timer, and continue if a separate prerequisite structure is later destroyed. Destruction of the producer still loses its queue without refund. All original refund and blocked-exit rules remain.

| Kind | Producing structure | Additional prerequisite |
|---|---|---|
| worker | hq | — |
| infantry | barracks | — |
| tank | factory | — |
| scout | barracks | — |
| skirmisher | barracks | — |
| sniper | barracks | sanctum |
| shock | barracks | workshop |
| breacher | barracks | workshop |
| guardian | sanctum | — |
| medic | sanctum | — |
| mechanic | workshop | — |
| lancer | factory | workshop |
| suppressor | barracks | workshop |
| artillery | arsenal | — |
| mortar | arsenal | — |
| raider | workshop | — |
| destroyer | arsenal | — |
| juggernaut | factory | arsenal |
| disruptor | workshop | sanctum |
| siege_tank | arsenal | — |
| commander | sanctum | arsenal |

| Building kind | Additional prerequisite |
|---|---|
| hq | — |
| power | — |
| refinery | — |
| barracks | — |
| factory | barracks |
| outpost | refinery |
| sentry | barracks |
| bastion | factory |
| workshop | barracks |
| sanctum | barracks |
| arsenal | factory |
| reactor | factory |
| relay | sanctum |

The new construction functions are: outposts provide forward **620 px** vision; sentries counter light ground forces; bastions counter heavy armor; workshops produce mobile specialists; sanctums produce protective/restorative formations; arsenals produce siege/anti-heavy platforms; reactors generate advanced power; relays provide faction-specific positional support. Their faction names and exact values below are authoritative. The five original functional building labels remain unchanged.

The AI keeps its documented difficulty timing and normal economy. After completing its Factory it gradually adds the eight new building roles, starting at **60 simulated seconds** and advancing a stage every **10 seconds**, subject to resources, prerequisites, clear placement, worker availability, and power. It may reserve earned essence for its next technology structure instead of spending that income on more troops; reservations never grant resources or bypass costs. After 60 seconds it rotates paid production across the least recently served available producers, saving for the next selected unit when necessary so cheap queues cannot starve heavy or support production. Repair specialists remain near the base; other combat/support units join attacks. It produces a varied army and chooses counters only from targets actually observed through fog; it never receives hidden intelligence or combat/economy bonuses.

### Expanded sidebar layout

The existing right sidebar retains its radar, economy, selection, queues, and commands. Construction and production catalogs show **six cards per page** with previous/next arrows: **two construction pages** for 12 buildable structures (Command Centers remain non-buildable), and **four production pages** for 21 units. Cards use a **130 × 60 px minimum**, 11 px text, wrapped full names, essence prices, and baked thumbnails. The existing vertical scroll keeps all controls reachable at the **1100 × 720** minimum without reducing the battlefield. Tooltips list actual faction costs, times, producer/technology prerequisites, combat values, abilities, and counters before spending. Queue labels retain the full faction unit/producer names. Current and maximum selection HP use the same ceiling so fractional balance values never display current HP above maximum.

### Expanded sprite asset specification

The original unit/building atlases remain unchanged. The **18 new mobile roles per faction** use six additional **1024 × 2304 px** atlases, `assets/sprites/units_<faction>.png`: eight **128 × 128 px** facing cells per row and 18 role rows, with the existing **(64, 80)** anchor. The **48 new structures** use `assets/sprites/expansion_buildings.png`, **2560 × 1536 px**: eight **320 × 256 px** role columns by six faction rows, with the existing **(160, 165)** anchor. All geometry is authored offline in `scripts/sprite_models_3d.gd` and regenerated with `.tools/godot --path . --script res://scripts/bake_sprites.gd -- --expansion`; that mode preserves the original atlases. Runtime icons, world sprites, picking, hover/body placement, and destruction use the corresponding cached source cells, with dynamic ownership, selection, health, and progress overlays. Mobile silhouettes stay legless and require no locomotion animation. Faction galleries are `artifacts/expansion-<faction>.png`.

### Balance verification method

`tests/balance_benchmark.gd` runs **90 open-ground combat fixtures**: every unordered faction pairing, three equal-budget compositions (combined arms, siege, mobile), and both owner/deployment assignments. Budgets are **2400**, **3200**, and **2200 essence** respectively. Units are purchased at actual faction prices, then use normal fixed-step combat, vision, movement, support, damage, and counters. Each fixture ends when a side loses its armed force or reaches **45 simulated seconds**. A win scores one and a draw scores half. This isolates combat value; it does not model the timing, scouting, or decision-making of every live match. The benchmark was rerun after each tuning pass, and the exact final definitions below are authoritative. Reproduce with `.tools/godot --headless --path . --script res://tests/balance_benchmark.gd` under an isolated profile.

### Exact expanded unit values

Costs are essence; training, cooldown, and effect durations are simulation seconds; ranges, speed, sight, and radii are simulation pixels. Role descriptions and names are also available in `scripts/roster_data.json`; `scripts/catalog.gd` is the runtime source. All missing special values are zero, except movement slow defaults to 1 and class bonus to 1. `heal HP/s @range`, `ward armor @range`, `regen HP/s`, `drain fraction`, and `slow multiplier / seconds` are listed as special effects. The cost-normalized initial templates deliberately exchange survivability, rate of fire, reach, support, and replacement time. They are a measurable first balance pass, not proof of perfect competitive balance; equal-budget battles and counter matchups must accompany verification.

#### Humans additions

| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |
|---|---|---|---|---|---|---|
| scout — Pathfinder | 55 / 5.5 | 61.8 / 0 | 4.7 / 0.8 | 115 / 145 / 540 | light / 9 | — |
| skirmisher — Dragoon | 90 / 8 | 90.2 / 0 | 10.2 / 0.9 | 190 / 110 / 350 | light / 10 | targets light×1.25 |
| sniper — Horizon Marksman | 130 / 13 | 68.4 / 0 | 37.2 / 2.4 | 340 / 72 / 380 | light / 10 | targets light×1.6, heavy×0.65; pierce 2 |
| shock — Stormguard | 130 / 12 | 142.5 / 2 | 18.6 / 0.8 | 90 / 87 / 310 | light / 12 | targets light×1.2; blast 20 |
| breacher — Breach Pioneer | 150 / 13 | 128.2 / 1 | 29.8 / 1.4 | 110 / 94 / 320 | light / 12 | targets structure×2, heavy×0.7 |
| guardian — Aegis Marshal | 185 / 16 | 247 / 5 | 9.3 / 1.2 | 150 / 64 / 320 | light / 13 | ward 1.5 @110 |
| medic — Arcanist | 125 / 14 | 80.8 / 0 | 0 / 1 | 0 / 85 / 340 | light / 10 | heal 6/s @150; ward 2 @125 |
| mechanic — Field Artificer | 145 / 13 | 104.5 / 1 | 0 / 1 | 0 / 83 / 320 | light / 11 | repair 12/s @130 |
| lancer — Sentinel Walker | 165 / 15 | 114 / 1 | 37.2 / 1.5 | 220 / 80 / 360 | light / 12 | targets heavy×1.65, light×0.6; pierce 2 |
| suppressor — Tempest Carrier | 160 / 14 | 128.2 / 1 | 13.9 / 1.3 | 185 / 76 / 330 | light / 12 | targets light×1.3, heavy×0.65; blast 45 |
| artillery — Longbow Launcher | 290 / 22 | 180.5 / 1 | 69.8 / 3.5 | 537.5 / 44 / 330 | heavy / 17 | targets structure×1.35, heavy×0.9, light×0.8; blast 42; minimum 150 |
| mortar — Thunder Mortar | 170 / 15 | 104.5 / 0 | 33.5 / 2.3 | 381.2 / 61 / 330 | light / 12 | targets light×1.25, structure×1.2; blast 50; minimum 90 |
| raider — Sabre Interceptor | 205 / 16 | 218.5 / 2 | 22.3 / 1.2 | 170 / 112 / 370 | heavy / 15 | targets structure×1.35, heavy×0.75 |
| destroyer — Lancer Destroyer | 290 / 23 | 304 / 3 | 65.2 / 2 | 260 / 57 / 380 | heavy / 17 | targets heavy×1.5, light×0.55; pierce 2 |
| juggernaut — Imperial Bastion | 435 / 30 | 646 / 7 | 46.5 / 1.8 | 170 / 39 / 340 | heavy / 21 | blast 32 |
| disruptor — Nullifier | 200 / 17 | 152 / 1 | 7.4 / 1.4 | 240 / 70 / 360 | light / 12 | slow 0.7/2s |
| siege_tank — Siegebreaker | 375 / 28 | 380 / 4 | 88.4 / 3.2 | 468.8 / 43 / 370 | heavy / 19 | targets structure×1.7, light×0.65, heavy×0.9; pierce 2; blast 25; minimum 110 |
| commander — Imperial Strategos | 270 / 22 | 213.8 / 3 | 16.8 / 1.1 | 190 / 70 / 360 | light / 13 | ward 2 @145 |

| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |
|---|---|---|---|---|---|---|
| outpost — Forward Command Post | 130 / 10 | 550 / 1 | 64×64 / 620 | 0 / 5 | 0 / 1 / 0 | — |
| sentry — Sentinel Turret | 150 / 12 | 650 / 2 | 64×64 / 320 | 0 / 12 | 12 / 0.8 / 300 | targets light×1.4, heavy×0.65 |
| bastion — Aegis Cannon | 320 / 20 | 1000 / 4 | 96×96 / 370 | 0 / 28 | 85 / 2.8 / 400 | targets heavy×1.4, light×0.55 |
| workshop — Motor Workshop | 260 / 18 | 1000 / 3 | 96×96 / 300 | 0 / 30 | 0 / 1 / 0 | — |
| sanctum — Arcane Academy | 250 / 18 | 850 / 2 | 96×96 / 340 | 0 / 25 | 0 / 1 / 0 | — |
| arsenal — Siege Arsenal | 340 / 22 | 1100 / 3 | 128×96 / 300 | 0 / 45 | 0 / 1 / 0 | — |
| reactor — Fusion Reactor | 260 / 16 | 750 / 1 | 96×96 / 250 | 220 / 0 | 0 / 1 / 0 | — |
| relay — Ward Relay | 240 / 18 | 750 / 2 | 64×96 / 360 | 0 / 25 | 0 / 1 / 0 | ward 2 @180 |

#### Iron Synod additions

| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |
|---|---|---|---|---|---|---|
| scout — Neural Seeker | 65 / 6.2 | 79.1 / 1 | 3.6 / 0.58 | 111.5 / 137.8 / 540 | light / 9 | regen 1/s |
| skirmisher — Mesh Skirmisher | 100 / 9 | 115.6 / 1 | 8 / 0.65 | 184.3 / 104.5 / 350 | light / 10 | targets light×1.25; regen 1/s |
| sniper — Optic Exactor | 150 / 13.4 | 87.5 / 1 | 29.4 / 1.73 | 329.8 / 68.4 / 380 | light / 10 | targets light×1.6, heavy×0.65; regen 1/s |
| shock — Pulse Ravager | 150 / 13.4 | 182.5 / 3 | 14.7 / 0.58 | 87.3 / 82.6 / 310 | light / 12 | targets light×1.2; blast 20; regen 1/s |
| breacher — Breach Assimilator | 175 / 14.6 | 164.2 / 2 | 23.4 / 1.01 | 106.7 / 89.3 / 320 | light / 12 | targets structure×2, heavy×0.7; regen 1/s |
| guardian — Cohort Bulwark | 215 / 17.9 | 316.3 / 6 | 7.4 / 0.86 | 145.5 / 60.8 / 320 | light / 13 | ward 1 @125; regen 1/s |
| medic — Nexus Warden | 145 / 13.4 | 103.4 / 1 | 0 / 0.72 | 0 / 80.8 / 340 | light / 10 | heal 9/s @150; regen 0.5/s |
| mechanic — Reclaimer Drone | 165 / 14.6 | 133.9 / 2 | 0 / 0.72 | 0 / 78.8 / 320 | light / 11 | repair 16/s @130; regen 0.5/s |
| lancer — Induction Spear | 190 / 15.7 | 146 / 2 | 29.4 / 1.08 | 213.4 / 76 / 360 | light / 12 | targets heavy×1.65, light×0.6; regen 1/s |
| suppressor — Signal Obliterator | 185 / 15.7 | 164.2 / 2 | 11 / 0.94 | 179.4 / 72.2 / 330 | light / 12 | targets light×1.3, heavy×0.65; blast 45; regen 1/s |
| artillery — Convergence Engine | 335 / 24.6 | 231.2 / 2 | 55.1 / 2.52 | 521.4 / 41.8 / 330 | heavy / 17 | targets structure×1.35, heavy×0.9, light×0.8; blast 42; minimum 145.5; regen 2/s |
| mortar — Synaptic Lobber | 195 / 16.8 | 133.9 / 1 | 26.4 / 1.66 | 369.8 / 57.9 / 330 | light / 12 | targets light×1.25, structure×1.2; blast 50; minimum 87.3; regen 1/s |
| raider — Chorus Raider | 230 / 17.9 | 279.8 / 3 | 17.7 / 0.86 | 164.9 / 106.4 / 370 | heavy / 15 | targets structure×1.35, heavy×0.75; regen 2/s |
| destroyer — Terminus Crusher | 335 / 24.6 | 389.4 / 4 | 51.4 / 1.44 | 252.2 / 54.1 / 380 | heavy / 17 | targets heavy×1.5, light×0.55; regen 2/s |
| juggernaut — Dominion Shell | 500 / 33.6 | 827.4 / 8 | 36.7 / 1.3 | 164.9 / 37 / 340 | heavy / 21 | blast 32; regen 2/s |
| disruptor — Phase Jammer | 225 / 19 | 194.7 / 2 | 5.9 / 1.01 | 232.8 / 66.5 / 360 | light / 12 | regen 1/s; slow 0.7/2s |
| siege_tank — Oblivion Rig | 430 / 30.2 | 486.7 / 5 | 69.7 / 2.3 | 454.8 / 40.9 / 370 | heavy / 19 | targets structure×1.7, light×0.65, heavy×0.9; blast 25; minimum 106.7; regen 2/s |
| commander — Consensus Prime | 310 / 24.6 | 273.8 / 4 | 13.2 / 0.79 | 184.3 / 66.5 / 360 | light / 13 | ward 2 @145; regen 1/s |

| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |
|---|---|---|---|---|---|---|
| outpost — Synapse Pylon | 150 / 11 | 632.5 / 2 | 64×64 / 620 | 0 / 6 | 0 / 0.75 / 0 | regen 2.5/s |
| sentry — Needle Battery | 170 / 13.2 | 747.5 / 3 | 64×64 / 320 | 0 / 13 | 9 / 0.6 / 291 | targets light×1.4, heavy×0.65; regen 2.5/s |
| bastion — Convergence Cannon | 370 / 22 | 1150 / 5 | 96×96 / 370 | 0 / 31 | 63.8 / 2.1 / 388 | targets heavy×1.4, light×0.55; regen 2.5/s |
| workshop — Integration Foundry | 300 / 19.8 | 1150 / 4 | 96×96 / 300 | 0 / 33 | 0 / 0.75 / 0 | regen 2.5/s |
| sanctum — Neural Crucible | 290 / 19.8 | 977.5 / 3 | 96×96 / 340 | 0 / 28 | 0 / 0.75 / 0 | regen 2.5/s |
| arsenal — Consensus Forge | 390 / 24.2 | 1265 / 4 | 128×96 / 300 | 0 / 50 | 0 / 0.75 / 0 | regen 2.5/s |
| reactor — Singularity Reactor | 300 / 17.6 | 862.5 / 2 | 96×96 / 250 | 245 / 0 | 0 / 0.75 / 0 | regen 2.5/s |
| relay — Restoration Node | 275 / 19.8 | 862.5 / 3 | 64×96 / 360 | 0 / 28 | 0 / 0.75 / 0 | repair 18/s @180; regen 2.5/s |

#### Kharuun Brood additions

| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |
|---|---|---|---|---|---|---|
| scout — Thornrunner | 40 / 3.5 | 44.3 / 0 | 3.7 / 0.76 | 104.7 / 150.8 / 540 | light / 9 | regen 1/s |
| skirmisher — Bristle Pod | 60 / 5 | 64.8 / 0 | 8.3 / 0.85 | 172.9 / 114.4 / 350 | light / 10 | targets light×1.25; regen 1/s |
| sniper — Needle Orchid | 90 / 7.6 | 49.1 / 0 | 30.4 / 2.28 | 309.4 / 74.9 / 380 | light / 10 | targets light×1.6, heavy×0.65; regen 1/s |
| shock — Bramble Husk | 90 / 7.6 | 102.3 / 1 | 15.2 / 0.76 | 81.9 / 90.5 / 310 | light / 12 | targets light×1.2; blast 20; regen 1/s |
| breacher — Rotcap Burster | 100 / 8.2 | 92.1 / 0 | 24.3 / 1.33 | 100.1 / 97.8 / 320 | light / 12 | targets structure×2, heavy×0.7; regen 1/s |
| guardian — Ironbark Sentinel | 125 / 10.1 | 177.3 / 4 | 7.6 / 1.14 | 136.5 / 66.6 / 320 | light / 13 | heal 5/s @120; regen 1/s |
| medic — Grovekeeper | 85 / 7.6 | 58 / 0 | 0 / 0.95 | 0 / 88.4 / 340 | light / 10 | heal 7/s @170; regen 1/s |
| mechanic — Sap Mender | 100 / 8.2 | 75 / 0 | 0 / 0.95 | 0 / 86.3 / 320 | light / 11 | repair 12/s @130; regen 1/s |
| lancer — Pikevine | 110 / 8.8 | 81.8 / 0 | 30.4 / 1.42 | 200.2 / 83.2 / 360 | light / 12 | targets heavy×1.65, light×0.6; regen 1/s |
| suppressor — Acid Bloom | 110 / 8.8 | 92.1 / 0 | 11.3 / 1.23 | 168.3 / 79 / 330 | light / 12 | targets light×1.3, heavy×0.65; blast 45; regen 1/s; slow 0.82/2.2s |
| artillery — Spore Howitzer | 185 / 13.9 | 131.9 / 0 | 59.2 / 3.32 | 489.1 / 45.8 / 330 | heavy / 17 | targets structure×1.35, heavy×0.9, light×0.8; blast 42; minimum 136.5; regen 2/s |
| mortar — Seed Mortar | 115 / 9.4 | 75 / 0 | 27.4 / 2.18 | 347 / 63.4 / 330 | light / 12 | targets light×1.25, structure×1.2; blast 50; minimum 81.9; regen 1/s; slow 0.82/2.2s |
| raider — Vine Skimmer | 130 / 10.1 | 159.7 / 1 | 18.9 / 1.14 | 154.7 / 116.5 / 370 | heavy / 15 | targets structure×1.35, heavy×0.75; regen 2/s |
| destroyer — Corrosion Cyst | 185 / 13.9 | 222.2 / 2 | 55.2 / 1.9 | 236.6 / 59.3 / 380 | heavy / 17 | targets heavy×1.5, light×0.55; regen 2/s |
| juggernaut — Elderwood Titan | 280 / 18.9 | 472.2 / 6 | 39.4 / 1.71 | 154.7 / 40.6 / 340 | heavy / 21 | blast 32; regen 2/s |
| disruptor — Pollen Warden | 135 / 10.7 | 109.1 / 0 | 6 / 1.33 | 218.4 / 72.8 / 360 | light / 12 | regen 1/s; slow 0.65/2.2s |
| siege_tank — Worldroot Slinger | 240 / 17 | 277.8 / 3 | 74.8 / 3.04 | 426.5 / 44.7 / 370 | heavy / 19 | targets structure×1.7, light×0.65, heavy×0.9; blast 25; minimum 100.1; regen 2/s |
| commander — Elder Conductor | 180 / 13.9 | 153.5 / 2 | 13.6 / 1.04 | 172.9 / 72.8 / 360 | light / 13 | heal 8/s @170; regen 1/s |

| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |
|---|---|---|---|---|---|---|
| outpost — Watchbloom | 105 / 7.5 | 440 / 0 | 64×64 / 620 | 0 / 5 | 0 / 1 / 0 | regen 2/s |
| sentry — Thorn Nest | 120 / 9 | 520 / 1 | 64×64 / 320 | 0 / 12 | 9.6 / 0.8 / 285 | targets light×1.4, heavy×0.65; regen 2/s; slow 0.85/1.5s |
| bastion — Acid Bulwark | 255 / 15 | 800 / 3 | 96×96 / 370 | 0 / 28 | 50 / 2.8 / 380 | targets heavy×1.4, light×0.55; blast 30; regen 2/s; slow 0.85/1.5s |
| workshop — Bud Nursery | 210 / 13.5 | 800 / 2 | 96×96 / 300 | 0 / 30 | 0 / 1 / 0 | regen 2/s |
| sanctum — Elder Grove | 200 / 13.5 | 680 / 1 | 96×96 / 340 | 0 / 25 | 0 / 1 / 0 | regen 2/s |
| arsenal — Seed Crucible | 270 / 16.5 | 880 / 2 | 128×96 / 300 | 0 / 45 | 0 / 1 / 0 | regen 2/s |
| reactor — Photosynthesis Spire | 210 / 12 | 600 / 0 | 96×96 / 250 | 175 / 0 | 0 / 1 / 0 | regen 2/s |
| relay — Mycelial Heart | 190 / 13.5 | 600 / 1 | 64×96 / 360 | 0 / 25 | 0 / 1 / 0 | heal 8/s @200; regen 2/s |

#### Aetherbound — Heavenly Host additions

| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |
|---|---|---|---|---|---|---|
| scout — Dawn Seer | 70 / 7.2 | 89.7 / 1 | 4.8 / 0.86 | 111.1 / 113.1 / 540 | light / 9 | — |
| skirmisher — Dawn Herald | 105 / 10.4 | 131.1 / 1 | 10.7 / 0.97 | 183.5 / 85.8 / 350 | light / 10 | targets light×1.25 |
| sniper — Judicator | 155 / 15.6 | 99.4 / 1 | 38.8 / 2.59 | 328.4 / 56.2 / 380 | light / 10 | targets light×1.6, heavy×0.65 |
| shock — Solar Avenger | 155 / 15.6 | 207 / 3 | 19.4 / 0.86 | 86.9 / 67.9 / 310 | light / 12 | targets light×1.2; blast 20 |
| breacher — Gatebreaker | 180 / 16.9 | 186.3 / 2 | 31 / 1.51 | 106.3 / 73.3 / 320 | light / 12 | targets structure×2, heavy×0.7 |
| guardian — Aegis Seraph | 225 / 20.8 | 358.8 / 6 | 9.7 / 1.3 | 144.9 / 49.9 / 320 | light / 13 | ward 4 @145 |
| medic — Choir Warden | 150 / 15.6 | 117.3 / 1 | 0 / 1.08 | 0 / 66.3 / 340 | light / 10 | heal 11/s @170; ward 3 @145 |
| mechanic — Reliquary Tender | 175 / 16.9 | 151.8 / 2 | 0 / 1.08 | 0 / 64.7 / 320 | light / 11 | repair 14/s @130 |
| lancer — Sunlance | 200 / 18.2 | 165.6 / 2 | 38.8 / 1.62 | 212.5 / 62.4 / 360 | light / 12 | targets heavy×1.65, light×0.6 |
| suppressor — Purifier | 195 / 18.2 | 186.3 / 2 | 14.5 / 1.4 | 178.7 / 59.3 / 330 | light / 12 | targets light×1.3, heavy×0.65; blast 45 |
| artillery — Heaven's Decree | 345 / 28.6 | 262.2 / 3 | 72.8 / 3.78 | 519.2 / 34.3 / 330 | heavy / 17 | targets structure×1.35, heavy×0.9, light×0.8; blast 42; minimum 138 |
| mortar — Bell Mortar | 205 / 19.5 | 151.8 / 1 | 34.9 / 2.48 | 368.2 / 47.6 / 330 | light / 12 | targets light×1.25, structure×1.2; blast 50; minimum 82.8 |
| raider — Aurora Chariot | 245 / 20.8 | 317.4 / 4 | 23.3 / 1.3 | 164.2 / 87.4 / 370 | heavy / 15 | targets structure×1.35, heavy×0.75 |
| destroyer — Exorcist | 345 / 28.6 | 441.6 / 5 | 67.9 / 2.16 | 251.2 / 44.5 / 380 | heavy / 17 | targets heavy×1.5, light×0.55 |
| juggernaut — Throne Guardian | 520 / 39 | 938.4 / 9 | 48.5 / 1.94 | 164.2 / 30.4 / 340 | heavy / 21 | blast 32 |
| disruptor — Stillness Cantor | 235 / 22.1 | 220.8 / 2 | 7.8 / 1.51 | 231.8 / 54.6 / 360 | light / 12 | slow 0.7/2s |
| siege_tank — Firmament Engine | 445 / 35.1 | 552 / 6 | 92.1 / 3.46 | 452.8 / 33.5 / 370 | heavy / 19 | targets structure×1.7, light×0.65, heavy×0.9; blast 25; minimum 101.2 |
| commander — Archon | 325 / 28.6 | 310.5 / 4 | 17.5 / 1.19 | 183.5 / 54.6 / 360 | light / 13 | ward 4 @175 |

| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |
|---|---|---|---|---|---|---|
| outpost — Vigil Spire | 170 / 12.5 | 742.5 / 3 | 64×64 / 620 | 0 / 5 | 0 / 1.08 / 0 | — |
| sentry — Dawn Lance | 195 / 15 | 877.5 / 4 | 64×64 / 320 | 0 / 12 | 12 / 0.86 / 285 | targets light×1.4, heavy×0.65 |
| bastion — Judgment Bastion | 415 / 25 | 1350 / 6 | 96×96 / 370 | 0 / 28 | 85 / 3.02 / 380 | targets heavy×1.4, light×0.55 |
| workshop — Reliquary Works | 340 / 22.5 | 1350 / 5 | 96×96 / 300 | 0 / 30 | 0 / 1.08 / 0 | — |
| sanctum — Choir Sanctum | 325 / 22.5 | 1147.5 / 4 | 96×96 / 340 | 0 / 25 | 0 / 1.08 / 0 | — |
| arsenal — Tribunal Forge | 440 / 27.5 | 1485 / 5 | 128×96 / 300 | 0 / 45 | 0 / 1.08 / 0 | — |
| reactor — Radiant Font | 340 / 20 | 1012.5 / 3 | 96×96 / 250 | 285 / 0 | 0 / 1.08 / 0 | — |
| relay — Sanctuary Beacon | 310 / 22.5 | 1012.5 / 4 | 64×96 / 360 | 0 / 25 | 0 / 1.08 / 0 | heal 4/s @180; ward 4 @200 |

#### Aetherbound — Infernal Legion additions

| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |
|---|---|---|---|---|---|---|
| scout — Whisperfiend | 60 / 5.2 | 52 / 0 | 5.7 / 0.69 | 92 / 174 / 540 | light / 9 | — |
| skirmisher — Cinder Stalker | 90 / 7.5 | 76 / 0 | 12.6 / 0.77 | 152 / 132 / 350 | light / 10 | targets light×1.25 |
| sniper — Dreadweaver | 130 / 11.3 | 57.6 / 0 | 46.1 / 2.06 | 272 / 86.4 / 380 | light / 10 | targets light×1.6, heavy×0.65 |
| shock — Ragebound | 130 / 11.3 | 120 / 1 | 23.1 / 0.69 | 72 / 104.4 / 310 | light / 12 | targets light×1.2; blast 20; drain 0.12 |
| breacher — Wallreaper | 150 / 12.2 | 108 / 0 | 36.8 / 1.2 | 88 / 112.8 / 320 | light / 12 | targets structure×2, heavy×0.7; drain 0.12 |
| guardian — Obsidian Guard | 190 / 15 | 208 / 4 | 12.5 / 0.7 | 95 / 76.8 / 320 | light / 13 | drain 0.16 |
| medic — Flesh Cantor | 125 / 11.3 | 68 / 0 | 0 / 0.86 | 0 / 102 / 340 | light / 10 | heal 9/s @150 |
| mechanic — Forge Wretch | 145 / 12.2 | 88 / 0 | 0 / 0.86 | 0 / 99.6 / 320 | light / 11 | repair 12/s @130 |
| lancer — Soulbreaker | 170 / 13.2 | 96 / 0 | 46.1 / 1.29 | 176 / 96 / 360 | light / 12 | targets heavy×1.65, light×0.6 |
| suppressor — Ash Torrent | 165 / 13.2 | 108 / 0 | 17.3 / 1.12 | 148 / 91.2 / 330 | light / 12 | targets light×1.3, heavy×0.65; blast 45 |
| artillery — Doom Caller | 295 / 20.7 | 152 / 0 | 86.4 / 3.01 | 430 / 52.8 / 330 | heavy / 17 | targets structure×1.35, heavy×0.9, light×0.8; blast 42; minimum 120 |
| mortar — Brimstone Maw | 175 / 14.1 | 88 / 0 | 41.4 / 1.98 | 305 / 73.2 / 330 | light / 12 | targets light×1.25, structure×1.2; blast 50; minimum 72 |
| raider — Scourge Chariot | 205 / 15 | 184 / 1 | 27.7 / 1.03 | 136 / 134.4 / 370 | heavy / 15 | targets structure×1.35, heavy×0.75; drain 0.12 |
| destroyer — Ruin Butcher | 295 / 20.7 | 256 / 2 | 80.7 / 1.72 | 208 / 68.4 / 380 | heavy / 17 | targets heavy×1.5, light×0.55 |
| juggernaut — Abyssal Tyrant | 440 / 28.2 | 544 / 6 | 57.6 / 1.55 | 136 / 46.8 / 340 | heavy / 21 | blast 32; drain 0.12 |
| disruptor — Fear Binder | 200 / 16 | 128 / 0 | 9.2 / 1.2 | 192 / 84 / 360 | light / 12 | slow 0.72/2.5s |
| siege_tank — Apocalypse Engine | 380 / 25.4 | 320 / 3 | 109.5 / 2.75 | 375 / 51.6 / 370 | heavy / 19 | targets structure×1.7, light×0.65, heavy×0.9; blast 25; minimum 88 |
| commander — Warfiend Regent | 275 / 20.7 | 180 / 2 | 21.1 / 0.8 | 125 / 84 / 360 | light / 13 | drain 0.2 |

| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |
|---|---|---|---|---|---|---|
| outpost — Eye of Ruin | 110 / 8 | 440 / 0 | 64×64 / 620 | 0 / 5 | 0 / 0.9 / 0 | — |
| sentry — Ember Spitter | 130 / 9.6 | 520 / 1 | 64×64 / 320 | 0 / 12 | 13.8 / 0.72 / 264 | targets light×1.4, heavy×0.65; drain 0.08 |
| bastion — Hellfire Citadel | 270 / 16 | 800 / 3 | 96×96 / 370 | 0 / 28 | 97.7 / 2.52 / 352 | targets heavy×1.4, light×0.55; drain 0.08 |
| workshop — War Cauldron | 220 / 14.4 | 800 / 2 | 96×96 / 300 | 0 / 30 | 0 / 0.9 / 0 | — |
| sanctum — Pain Chapel | 210 / 14.4 | 680 / 1 | 96×96 / 340 | 0 / 25 | 0 / 0.9 / 0 | — |
| arsenal — Ruin Foundry | 290 / 17.6 | 880 / 2 | 128×96 / 300 | 0 / 45 | 0 / 0.9 / 0 | — |
| reactor — Inferno Furnace | 220 / 12.8 | 600 / 0 | 96×96 / 250 | 190 / 0 | 0 / 0.9 / 0 | — |
| relay — Blood Obelisk | 205 / 14.4 | 600 / 1 | 64×96 / 360 | 0 / 25 | 0 / 0.9 / 0 | heal 9/s @160 |

#### Veyr Dominion additions

| Kind / name | Essence / train s | HP / armor | Damage / cooldown | Range / speed / sight | Class / radius | Special effects |
|---|---|---|---|---|---|---|
| scout — Prism Scout | 80 / 7.7 | 87.8 / 1 | 5.8 / 0.94 | 135.7 / 97.2 / 540 | light / 9 | — |
| skirmisher — Facet Skimmer | 125 / 11.2 | 128.2 / 1 | 12.6 / 1.06 | 224.2 / 73.7 / 350 | light / 10 | targets light×1.25 |
| sniper — Lens Sentinel | 180 / 16.8 | 97.2 / 1 | 46 / 2.83 | 401.2 / 48.2 / 380 | light / 10 | targets light×1.6, heavy×0.65; slow 0.85/1.2s |
| shock — Impact Shard | 180 / 16.8 | 202.5 / 3 | 23 / 0.94 | 106.2 / 58.3 / 310 | light / 12 | targets light×1.2; blast 20 |
| breacher — Fault Breaker | 210 / 18.2 | 182.2 / 2 | 36.8 / 1.65 | 129.8 / 63 / 320 | light / 12 | targets structure×2, heavy×0.7 |
| guardian — Diamond Custodian | 260 / 22.4 | 351 / 6 | 11.5 / 1.42 | 177 / 42.9 / 320 | light / 13 | ward 1.5 @110 |
| medic — Memory Mender | 175 / 16.8 | 114.8 / 1 | 0 / 1.18 | 0 / 57 / 340 | light / 10 | heal 8/s @190 |
| mechanic — Lattice Sculptor | 205 / 18.2 | 148.5 / 2 | 0 / 1.18 | 0 / 55.6 / 320 | light / 11 | repair 12/s @130 |
| lancer — Null Lance | 230 / 19.6 | 162 / 2 | 46 / 1.77 | 259.6 / 53.6 / 360 | light / 12 | targets heavy×1.65, light×0.6; pierce 4 |
| suppressor — Splinter Weaver | 225 / 19.6 | 182.2 / 2 | 17.2 / 1.53 | 218.3 / 50.9 / 330 | light / 12 | targets light×1.3, heavy×0.65; blast 45 |
| artillery — Resonator | 405 / 30.8 | 256.5 / 3 | 86.2 / 4.13 | 634.2 / 29.5 / 330 | heavy / 17 | targets structure×1.35, heavy×0.9, light×0.8; pierce 4; blast 42; minimum 177 |
| mortar — Echo Mortar | 240 / 21 | 148.5 / 1 | 41.4 / 2.71 | 449.9 / 40.9 / 330 | light / 12 | targets light×1.25, structure×1.2; blast 50; minimum 106.2; slow 0.85/1.2s |
| raider — Glint Spear | 285 / 22.4 | 310.5 / 4 | 27.6 / 1.42 | 200.6 / 75 / 370 | heavy / 15 | targets structure×1.35, heavy×0.75 |
| destroyer — Mass Driver | 405 / 30.8 | 432 / 5 | 80.5 / 2.36 | 306.8 / 38.2 / 380 | heavy / 17 | targets heavy×1.5, light×0.55; pierce 4 |
| juggernaut — Adamant Colossus | 610 / 42 | 918 / 9 | 57.5 / 2.12 | 200.6 / 26.1 / 340 | heavy / 21 | blast 32 |
| disruptor — Gravity Warden | 275 / 23.8 | 216 / 2 | 9.2 / 1.65 | 283.2 / 46.9 / 360 | light / 12 | slow 0.55/2.5s |
| siege_tank — Worldshard Cannon | 520 / 37.8 | 540 / 6 | 109.2 / 3.78 | 553.1 / 28.8 / 370 | heavy / 19 | targets structure×1.7, light×0.65, heavy×0.9; pierce 4; blast 25; minimum 129.8 |
| commander — Ancestral Nexus | 375 / 30.8 | 303.8 / 4 | 20.7 / 1.3 | 224.2 / 46.9 / 360 | light / 13 | ward 2 @145 |

| Building kind / faction name | Essence / build s | HP / armor | Footprint / sight | Power supply / use | Weapon damage / cooldown / range | Special effects |
|---|---|---|---|---|---|---|
| outpost — Far Prism | 190 / 14 | 797.5 / 3 | 64×64 / 620 | 0 / 5 | 0 / 1.15 / 0 | — |
| sentry — Splinter Array | 220 / 16.8 | 942.5 / 4 | 64×64 / 320 | 0 / 12 | 13.2 / 0.92 / 360 | targets light×1.4, heavy×0.65; pierce 2; slow 0.85/1.2s |
| bastion — Gravity Bastion | 465 / 28 | 1450 / 6 | 96×96 / 370 | 0 / 28 | 93.5 / 3.22 / 480 | targets heavy×1.4, light×0.55; pierce 2; slow 0.85/1.2s |
| workshop — Lattice Works | 375 / 25.2 | 1450 / 5 | 96×96 / 300 | 0 / 30 | 0 / 1.15 / 0 | — |
| sanctum — Resonance Archive | 360 / 25.2 | 1232.5 / 4 | 96×96 / 340 | 0 / 25 | 0 / 1.15 / 0 | — |
| arsenal — Monolithic Forge | 495 / 30.8 | 1595 / 5 | 128×96 / 300 | 0 / 45 | 0 / 1.15 / 0 | — |
| reactor — Starcore Reactor | 375 / 22.4 | 1087.5 / 3 | 96×96 / 250 | 310 / 0 | 0 / 1.15 / 0 | — |
| relay — Stasis Nexus | 350 / 25.2 | 1087.5 / 4 | 64×96 / 360 | 0 / 25 | 5 / 1.6 / 350 | blast 55; slow 0.6/2s |

## Demo economy and production

- **6 spiritual wells**, each surrounded by **8 patches**. Every patch starts with **160 essence**, regrows at **1 essence/second**, and cannot exceed its capacity. Empty patches remain and regrow. Regrowth pauses with the simulation.
- Workers harvest **6 essence/second**, carry up to **60**, and automatically return cargo and resume harvesting. Exhausted patches trigger a search for other visible growth. All players can harvest the same neutral patches.
- Buildings require clear visible terrain, room for their footprint, an available worker, and a completed friendly building within **650 px**. A Factory additionally requires a completed Barracks. Wells, patches, cliffs, units, and other structures block placement.
- A worker moves to the site to construct it. Incomplete structures start at **10% HP** and gain the remaining **90%** during construction; their production and power functions activate only on completion.
- When construction completes, its builder automatically resumes harvesting, returning to its previous visible, usable patch when possible or finding another visible patch. Carried essence is preserved, and a full load is delivered first. This applies to every faction and does not override manual orders issued to a worker that left the construction job.
- Units are paid for when queued. Cancelling the last queued unit gives a **100% refund**; destroying its producer loses its queued orders without refunds. Completed units wait in the queue if every exit is blocked.
- Train units directly from the sidebar without selecting a building: owning a completed Command Center unlocks workers, Barracks infantry, and Factory tanks. All unit icons stay visible and are enabled when a matching completed friendly producer and sufficient essence are available; low power does not prevent queueing. A selected matching producer receives the order when available; otherwise the producer with the least queued training time is used (stable entity order breaks ties). The displayed queue and cancellation follow a selected queued producer, then the last used producer, then another friendly queued producer. Cancellation removes the last item from the displayed queue with the documented full refund. Matches begin with no building selected. Right-click still sets a selected producer's rally point.
- Power supply: Command Center **20**, Power Plant **100**. Consumption: Refinery **15**, Barracks **20**, Factory **40**. If demand exceeds supply, training runs at **half speed**; this is separate from the essence currency.
- Building tooltips and selected-building information show supply or consumption. The power meter shows **used / supplied** and explains the low-power penalty; the displayed production queue also flags half-speed training. Values and unit-to-producer mappings are shared from `scripts/catalog.gd`.

### Building repair and sale

Repair and Sell respond to the first completed mouse click, including clicks spanning the 150 ms HUD refresh. Refreshing availability does not temporarily disable an otherwise usable button. The existing eligibility, pause, funds, refund, and Command Center confirmation rules still apply. Regression coverage routes actual GUI presses and releases through an intervening simulation/HUD refresh.

- Select one friendly building to use **REPAIR** or **SELL** in its selection panel. Repair is a toggle for living, completed, damaged buildings, including the Command Center. It restores **2% of maximum HP per simulation second**, in paid pulses: each **1 essence** restores `max HP / (0.5 × building cost)` HP, capped at missing HP. Repairing from empty to full therefore costs half the building price, rounded up for a partial final pulse. No worker is required; production, existing support healing, and power rules remain unchanged.
- Repair stops at full health or when toggled off. With no essence it waits without accumulating free repair time, then resumes when income arrives. Repair freezes with pause and match end. Player and AI owners share the same action validation and formulas; no automatic AI repair/sale behavior is added.
- Sale removes a living friendly building immediately, including incomplete structures, and returns `floor(0.5 × building cost × current HP / maximum HP)` essence. All paid queued units are cancelled with their full recorded prices refunded; no queued units spawn. Selling cannot be repeated. Power, prerequisites, fog, and navigation update immediately. A construction worker still assigned to that site resumes harvesting with its cargo preserved; manual orders remain respected.
- Selling the **Command Center** requires an explicit in-game warning/confirmation and immediately causes the existing defeat condition (or victory when the enemy sells theirs). Other buildings sell directly. Sale is unavailable while paused, in menus, or after the match ends. Ownership is checked before either action; enemy buildings and mobile units cannot be repaired or sold through these controls.

The following rows are the shared worker values and original Human combat baseline; other combat units use the faction table above.

| Unit | Essence | Train seconds | HP | Damage | Armor | Range px | Cooldown seconds | Speed px/s | Sight px |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Worker | 60 | 6 | 70 | 0 | 0 | 0 | 1 | 100 | 300 |
| Infantry | 80 | 8 | 110 | 12 | 0 | 150 | 0.8 | 88 | 330 |
| Tank | 220 | 16 | 420 | 48 | 4 | 230 | 1.6 | 68 | 380 |

| Building | Essence | Build seconds | HP | Armor | Footprint px | Sight px |
|---|---:|---:|---:|---:|---|---:|
| Command Center | 400 | 20 | 1800 | 4 | 128 × 96 | 420 |
| Power Plant | 120 | 8 | 600 | 2 | 64 × 64 | 250 |
| Refinery | 180 | 12 | 1000 | 3 | 96 × 96 | 280 |
| Barracks | 180 | 12 | 800 | 2 | 96 × 64 | 280 |
| Factory | 300 | 18 | 1000 | 3 | 128 × 96 | 300 |

## Simulation, combat, and AI

- Fixed **20 Hz** simulation, independent of rendering. Fog updates every **0.25 seconds**. Pause freezes economy, regrowth, production, construction, movement, AI, and combat.
- Damage per shot is **max(1, attack damage − target armor)**, applied immediately with a visual laser-beam tracer. Infantry and tank weapons are lasers. A target must be visible and within weapon range plus its physical radius. Tanks have no splash damage in this demo.
- Matching player and AI units of the same faction and role have identical stats, costs, and training times from the faction table above. Workers and the original five buildings remain shared across factions; new structures use their recorded faction values. Neither ownership nor AI difficulty grants health or damage bonuses; armor, cooldowns, and construction health progression use the same rules for both sides.
- Grid pathfinding avoids terrain and building footprints; destination spreading and local separation reduce unit stacking. Combat uses spatial buckets rather than comparing every pair of units.
- Stop removes current movement orders but permits defensive fire. Hold position fires without pursuing enemies. Attack-move engages visible enemies encountered en route; direct attacks that lose sight continue toward the last observed position.
- AI uses the same costs, construction, power, production, navigation, and vision rules. On Normal it thinks every **2 seconds**, builds Barracks and Factory, maintains harvesting, scouts after **35 seconds**, and revisits attack orders every **18 seconds**. It does not query hidden current enemy positions.
- Choose **Easy**, **Normal** (default), or **Hard** on the deployment screen. Restarting retains the chosen level for the session. Difficulty changes AI planning only: no free resources, stat bonuses, faster production, or extra vision. Worker targets are economy goals, not population limits; all levels keep producing armies without a unit cap.

| AI difficulty | Decision interval | Worker target | First scouting/attack order | Attack order interval |
|---|---:|---:|---:|---:|
| Easy | 4 s | 4 | 70 s | 30 s |
| Normal | 2 s | 6 | 35 s | 18 s |
| Hard | 1 s | 8 | 20 s | 10 s |

Scouting/attack orders are issued on the next AI decision at or after the listed time, with available combat units. All levels use the same exploration route until the enemy Command Center has actually been seen. These times govern orders, not guaranteed arrival times at the player's base.

## Presentation and performance

- **All artwork must look complete and convincing without animation.** Design unit locomotion around static sprites: no visible legs or feet, and no silhouettes that require walking, running, crawling, or wing-flapping cycles to make movement believable. Buildings, terrain, weapons, and props must also read clearly in a still frame.
- Units use translation and directional facing changes, with an optional procedural hover bob. Prefer enclosed tracked/wheeled chassis, hover platforms, levitating pods, floating plant forms, legless spirits, and suspended crystals. Wings may be fixed decorative shapes; no flapping is required. Faction identities, unit names, combat roles, and gameplay stats remain as cataloged.
- All mobile units gently bob **±2.5 projected pixels** over a **2.6-second** cycle, with a stable phase per entity so units do not move in lockstep. Bodies, cargo indicators, and health bars move together; ground shadows and selection rings stay anchored to the ground. Buildings do not bob. The effect uses simulation time and freezes when paused or after the match ends. Picking and drag-selection follow the displaced body; gameplay positions, movement, targeting ranges, collision, fog, depth order, and radar positions remain ground-based. This effect adds no locomotion frames and the artwork remains complete when frozen.
- Faction applications: Humans use armored hover platforms or enclosed vehicle chassis; Iron Synod uses floating cyber-organic shells and pods; Kharuun uses levitating seed pods and plant masses; angels use floating robes/armor with halos and fixed wings; demons use legless horned spirit forms; Veyr uses suspended crystalline constructs. Hovering is a visual treatment and does not grant flight or terrain bypass.
- Human specifics: the **Prospector** has a single wheel-free hover hull with a smooth continuous underside, without wheel-like side pods, rollers, or tread belts. The **Vanguard** is a human-operated open hover vehicle with a clearly visible head/face, upper body, arms, and hands at the controls. Its pilot remains identifiable in directional views while legs and feet stay inside the chassis. No opaque canopy or sealed robot-like cab may hide the person.
- The **Paladin Tank** is a futuristic hovercraft tank: one broad, swept, beveled armored hull with a recessed smooth underside, small teal lift slots and rear thrusters, a raised turret, and its long cannon. It has no treads, wheels, rollers, or paired track-like side housings. Preserve this silhouette in both the baked eight-facing sprites and procedural fallback; its ground navigation, stats, existing hover bob, and anchored shadow remain unchanged.
- Walk cycles, skeletal rigs, moving treads, and animated limbs are not required asset work. Directional sprite variants remain supported. Optional glow, particles, muzzle flashes, and other effects may add polish, but the artwork must still look good when those effects are disabled or frozen.
- Actual unit losses play a **1.4-second** death animation: the existing faction/facing sprite breaks into darkening, falling strips beneath a brief fireball, drifting smoke, sparks, and ballistic armor fragments. Actual building losses play a **2.4-second** collapse with seven staggered fireballs, larger smoke plumes, and more debris. Bodies and effects share the battlefield's depth order, camera zoom, and fog overlay. `scripts/destruction_art.gd` caches original textured fire/smoke/glow once; `scripts/faction_sprites.gd` reuses the baked atlas for falling body strips without regenerating models or terrain. Each effect draws at most nine smoke puffs, seven fireballs, and eighteen fragments, with deterministic trajectories seeded by the lost entity ID.
- Destruction snapshots are created once at entity removal, only for friendly or currently visible enemy losses. Unseen deaths cannot be revealed by later exploration; enemy effects disappear outside current vision. Effects have no collision, targeting, radar, damage, income, or persistent wreckage. They age with simulation time and freeze on pause; restarting clears them. After match end, **only the remaining destruction effects** finish on a separate cosmetic update while gameplay, match time, and hover remain frozen. Victory/Defeat is determined and orders stop immediately; the results overlay appears after the last effect expires so it does not obscure the decisive Command Center explosion.
- This requirement supersedes earlier legged model concepts. The mobile sprite models, baked unit atlas, and procedural fallback use legless or enclosed silhouettes for all six visual families; movement does not require a locomotion animation cycle.
- Visual target: the detailed, gritty isometric fidelity of **Command & Conquer: Tiberian Sun**, using original assets. Units and buildings should read as lit, textured machinery or faction-specific living forms, with small surface details, worn materials, and consistent lighting. Terrain should have continuous organic variation, gravel, cracks, weathered roads, and rock strata rather than visible blocks of flat tile color. The sidebar uses recessed gunmetal plates, restrained accents, and rendered unit/building thumbnails while retaining its existing layout and controls.
- Visual reference: [Tiberian Sun screenshot gallery](https://cnc-comm.com/tiberian-sun/gallery?category=Screenshots).
- **2:1 isometric projection**: simulation position `(x, y)` renders at `(x − y + 2048, (x + y) / 2)`. Each 32 px simulation tile becomes a 64 × 32 px diamond. The unchanged 3072 × 2048 simulation battlefield occupies a projected bounding box of **5120 × 2560 px**. All economy, movement, range, collision, fog, and balance values above remain simulation-space values.
- Units and structures are upright sprites with height, shadows, and depth sorting by `x + y`. Cliffs, essence clusters, and entities share depth order. Ground placement previews use the exact projected simulation footprint; raised sprite bodies are clickable. Camera coordinates use projected space, and input, zoom, focus, rally points, and minimap clicks convert through `scripts/projection.gd`. Camera clamping keeps the view centered on the playable diamond.
- Original faction-specific 3D miniatures and worn materials are authored in `scripts/sprite_models_3d.gd` and rendered offline: Human olive armored hover platforms and sealed vehicle chassis with teal rune lights; Iron Synod violet floating cyber-organic shells and neural pods; Kharuun suspended bark/leaf/seed forms; Heavenly Host legless pale armor and robes with halos and fixed wings; Infernal Legion horned legless spirit forms with obsidian armor and tapered lower bodies; Veyr suspended faceted crystals. Static tools, weapons, fins, and decorative appendages distinguish roles without implying walking or crawling. Buildings retain their functional silhouettes, vents, pipes, tanks, doors, antennae, panel seams, and lit volume. All six visual families are selectable for either commander; team-colored ground stripes distinguish ownership even in mirror matches.
- Classic right sidebar with a matching diamond-shaped radar map, essence/power, construction icons, production queues, selection information, and orders. A **26 × 144 px** segmented power meter sits immediately left of the radar with a **5 px** gap: bottom-up bars show supply and a separate horizontal marker shows demand. Both share a scale of **1.15 × max(100, supply, demand)**, leaving headroom at any base size. The meter is green below **85%** utilization, amber at **85–100%**, and red when demand exceeds supply; its tooltip and the numeric **used / supplied** readout give exact totals and the existing shortage penalty. The top battlefield banner is removed; the battlefield starts at the top-left and uses the full viewport height. The objective/timer remains in the sidebar above the radar.
- Body artwork is baked into transparent atlases for all six visual families, with eight whole-model facing directions, directional lighting, self-shading, and composited soft ground shadows. `scripts/bake_sprites.gd` regenerates `assets/sprites/units.png` and `buildings.png` from the offline 3D source; append `-- --units-only` to preserve the building atlas during mobile-art revisions, `-- --human-units` to replace only Prospector/Vanguard facing cells, or `-- --human-tank` to replace only the eight Paladin Tank facing cells. The game still renders cached 2D sprites. Health, selection, cargo, construction, and queue indicators remain dynamic, with ground selection markers behind the upright sprites.
- `assets/terrain/generate.py` produces continuous multiscale soil, subtle gravel/cracks/dry grass/debris, the existing road's weathering, stratified cliff textures, weathered spiritual wells, and eight essence-growth stages. `scripts/terrain_art.gd` draws them without changing any map positions or footprints. Static terrain is cached once; fog uses a 96 × 64 nearest-filtered texture updated with simulation visibility. These caches preserve projection, gameplay rules, and runtime performance.
- `scripts/ui_skin.gd` supplies tiled brushed-metal plates and recessed/beveled control states. Construction and production buttons use cropped rendered atlas thumbnails, with full existing labels and costs. HUD layout and hotkeys remain as documented below.
- Default viewport **1366 × 864**, resizable with a **1100 × 720** minimum. Canvas-item scaling uses **expand** aspect handling: fullscreen and resized windows reveal additional battlefield area to fill the display without letterboxing, pillarboxing, or distorting sprites. The sidebar remains anchored to the right edge of the expanded viewport. **WASD**, arrow keys, edge scrolling, or middle drag pan the camera; mouse wheel zooms. Camera movement uses screen directions, with diagonal speed normalized. Attack-move uses **E**, stop uses **X**, and hold position uses **H**, avoiding conflicts with WASD. Controls are listed in `README.md` and **Settings → Controls**. Bindings are fixed and cannot be changed. The bottom-right status area shows only temporary command/event feedback, with no idle key-binding help.
- Edge scrolling uses **16 physical display-pixel** bands (converted through the current canvas stretch scale) at both the battlefield edges and the outer window edges, including the top battlefield edge and far side of the sidebar. In windowed mode, native title-bar and resize-border bounds also count as window edges, even if the engine's mouse-inside signal is stale; Camera edge scrolling uses the live native system pointer for both client and frame positions; the current native result, including zero movement, takes priority over cached viewport input and enter/exit flags. Selection and orders continue to use viewport coordinates. Dragging native decorations with a mouse button suppresses this fallback. Ordinary HUD interiors and positions outside the complete decorated window do not trigger scrolling. Tiny top/left coordinate roundoff up to **0.001 physical px** is clamped to the edge; a pointer one full pixel outside the client still cannot trigger client-edge scrolling. Camera movement stops at map bounds and is suppressed while the window is inactive, a modal is open, or a selection/middle drag is in progress.
- Target **30 FPS** or better on documented workloads. Reference machine available during development: **AMD Ryzen 7 7800X3D**, **NVIDIA RTX 4070 SUPER**, Linux x86-64, OpenGL 3.3. Record measured results after rendered packaged-build verification; performance is not guaranteed at arbitrary uncapped army sizes.

## Unit silhouette specifications

The original three core roles within each faction use separate body plans, proportions, tools, and weapons, rather than one shared form with different scales; added silhouettes follow the expanded asset specification above. Workers emphasize collection equipment and cargo capacity; frontline units present upright defensive/combat silhouettes; heavy units have broad, substantial weapon platforms. Faction materials and colors stay consistent across the roster.

| Faction | Worker | Frontline | Heavy |
|---|---|---|---|
| Humans | Prospector: squat continuous utility hover barge, open cargo bins, side crane | Vanguard: narrow open hover skiff with exposed human head/face, torso, and hands | Paladin Tank: broad swept hover wedge, raised turret, long cannon |
| Iron Synod | Synapse Harvester: crescent collection shell, reservoir, tool manipulators | Convergent Legionary: upright cyber-organic sentinel, neural crown, side gun | Chimera Tank: broad living-armored assault hull, organic turret, crystal shoulder spines |
| Kharuun Brood | Root Tender: hanging gourd/cargo pod with vine tools | Barkguard: upright bark shield body and thorn crest | Seedspine: horizontal pinecone artillery body, seed-launching trumpet, spines |
| Heavenly Host | Sanctifier: bell-shaped floating robe, collection tools, small halo | Seraph Guard: tapered armored spirit, shield/spear, fixed swept wings | Sanctum Colossus: broad reliquary construct, winged shoulders, protected spirit core |
| Infernal Legion | Ashshaper: round ash urn, tool tongs, small horns | Hellblade: narrow horned blade spirit with tapered lower body | Infernal Behemoth: massive horned torso, armored furnace hull, broad shoulders and maw |
| Veyr Dominion | Shard Tender: compact asymmetric tool-shard cluster and ring | Crystal Guard: tall shield prism, split fins, resonance emitter | Monolith: broad low hexagonal hull, protected crystal core, forward resonator |

All units remain legless or enclosed, visually complete as static sprites, and use the same eight whole-body facing views. Wings are fixed decorative forms; roots, vines, tools, and spines do not become walking limbs. Human hulls have no wheels, treads, wheel-like side pods, or exposed lower bodies. Models and procedural fallbacks preserve these role silhouettes.

The unit atlas remains **3072 × 768 px**, with **128 × 128 px** cells, the existing **(64, 80)** ground anchor, six faction rows, and **three roles × eight facings**. `bake_sprites.gd -- --units-only` preserves the building atlas. Runtime hover amplitude/phase, ground shadows, ownership/selection, health and cargo indicators, picking rules, simulation sizes/collision, navigation, fog, and every gameplay stat remain as before. Additional visual equipment does not introduce new attacks or abilities.

## Building silhouette specifications

Each faction's original five buildings have separate role silhouettes in the offline models, baked atlas, sidebar thumbnails, and procedural fallback. The shared faction palette/material language stays consistent, while roofline, height, mass distribution, open space, and recognizable machinery identify function without relying on a label or animation.

| Faction | Command Center | Power Plant | Refinery | Barracks | Factory |
|---|---|---|---|---|---|
| Humans | Raised radio/control tower with side wings | Twin ribbed reactor stacks | Asymmetric processing tower, storage silos, delivery dock | Low segmented training hall | Broad vehicle assembly bay with overhead gantry |
| Iron Synod | Neural brain dome with cable buttresses | Tall three-coil organic reactor | Digestive reservoirs and low intake mouth | Discrete augmentation capsules on a low spine | Open ribcage assembly cradle and manipulator arms |
| Kharuun Brood | Ancient hollow tree and crown | Tall open energy flower | Sap bulbs, collection funnel, delivery trough | Low seed nursery beneath leaf canopies | Massive hollow-log seedforge arch |
| Heavenly Host | Stepped cathedral and central spire | Suspended halo/core between pylons | Chalice reservoirs and collection channels | Low colonnaded training hall | High winged forge arch over an assembly plinth |
| Infernal Legion | Tiered horned command keep | Furnace chimney and contained ember core | Cauldron reservoirs and intake trough | Low serrated den with hatch rows | Open siege forge, anvil, and lifting cranes |
| Veyr Dominion | Tiered crystalline command citadel | Suspended crystal spindle within a ring | Low collection basin and shard reservoirs | Parallel low crystal training racks | Broad crystalline assembly arch and cradle |

The building atlas stays **1600 × 1536 px**, with **320 × 256 px** cells, the existing **(160, 165)** ground anchor, six faction rows, and five role columns. Material wear and directional lighting remain baked; selection, ownership, construction, health, and queues remain dynamic. `bake_sprites.gd -- --buildings-only` updates only building artwork. Unit artwork, simulation footprints, placement/navigation, costs, stats, production, and terrain are unchanged by this visual revision.

## Music

- **Iron Horizon** is an original **352-second (5:52)**, **120 BPM**, **44.1 kHz stereo** industrial rock/electronic suite. It follows the broad RTS music direction requested with Frank Klepacki as the style reference; no existing recordings, samples, or melodies are used. The revision replaces the short repeating cue with changing eight-bar riffs, independent syncopated bass parts, multiple drum feels and fills, moving minor-key harmonies, an eight-bar main theme, a broad second melody, and developed reprises. Double-tracked synthesized power riffs, organ, brass-like synths, toms, metallic percussion, atmospheric pads, and isolated echoing notes enter and leave to create contrast.
- `assets/music/generate.py` deterministically renders the included `assets/music/iron_horizon.ogg` offline using Python/NumPy and libsndfile. The **176-bar** arrangement has thirteen sections of eight or sixteen bars: **0:00** Signal in the Dust; **0:16** Assembly Line; **0:48** Forward Pressure; **1:20** Iron Horizon; **1:52** Fracture; **2:08** The Silent Wells; **2:40** Pursuit Circuit; **3:12** Reconnection; **3:28** Countermarch; **4:00** High Orbit; **4:32** Final Advance; **5:04** Fallout; **5:20** Dust and Signals. An ambient opening/ending and wrapped instrument/effect tails join the loop. No music synthesis runs during gameplay.
- One `AudioStreamPlayer` streams the looping Ogg at a default **−14 dB** from deployment through gameplay, pause, and results. **M** or the sidebar **MUSIC ON/OFF** button toggles music. Muting silences the stream while its playback continues and preserves the chosen volume; the choice survives match restarts for the current session. Music playback is independent of simulation timing.

## Unit acknowledgment audio

- Selecting an owned mobile unit (click, drag box, Shift-add, or group recall) plays one role-specific selection response. Accepted ground moves and worker harvest orders play a movement response. Direct attacks (right-click or E-click) and combat attack-move orders play an attack response; unarmed workers have no attack bank and retain movement responses for ground attack-move. One representative unit responds per group; buildings, enemy selections, AI/internal orders, and rejected/paused/end-state/HUD actions remain silent. Audio does not alter orders, fog, targeting, movement, or unit balance.
- `assets/voices/` contains **1,080 stereo Ogg cues** across six families and 21 mobile roles per family: **144 original-role cues** and **936 expanded-role cues**. Every supported action has three variants; unarmed workers and support units have no attack bank. The banks follow the existing `faction_sprites.gd` family mapping. Only the **180 Human cues** contain spoken dialogue; all **900 non-Human cues** are wordless.
- Human Prospector, Vanguard, and Paladin crews use distinct radio-colored voices, Republic callouts (including **“For the People's Republic!”**), and readiness/movement lines. The Prospector and Vanguard callouts omit “galactic” and “galaxy” as requested. This requested dialogue does not rename the catalog/HUD's Human Empire. All 180 Human recordings, including expanded unit dialogue, remain byte-identical in the wordless faction revision.
- Each non-Human family has a unique sound theme across its full roster: **Iron Synod — cybernetic resonance**, metallic pulses and network-like harmonics; **Kharuun — living grove**, leafy wind and creaking wood; **Heavenly Host — celestial choir**, wordless harmonies, organ tones, bells, and church-like reverberation; **Infernal Legion — abyssal growl**, snarls, rough breath, and dark reflections; **Veyr — crystal resonance**, inharmonic chimes and cavernous echoes. Seraph Guard’s existing wordless choir remains the Heavenly Host reference. Unit cues vary in register, weight, and texture within their faction theme; selection, movement, and attack have distinct responses. No speech source is used for non-Human cues.
- `scripts/unit_voice.gd` uses one non-positional player at a default **−3 dB**, cached non-looping streams, a **250 ms** minimum interval, and rotating variants. Every active response finishes naturally before another acknowledgment begins. Orders still execute immediately while the voice channel is busy; additional responses are suppressed rather than interrupting or creating a stale backlog. Restart clears the current response. Voice playback is independent of the music mute and uses bounded decoder cleanup on shutdown.
- `assets/voices/generate.py` renders neural speech and procedural effects offline; `manifest.json` records cue paths, Human dialogue, non-Human sound themes, and durations. Piper and the authoring models are kept outside the project/runtime. Provenance is recorded in `assets/voices/CREDITS.txt`, copied to the package as `VOICE-CREDITS.txt`.

## Command announcer

- `assets/announcer/` contains **17 event announcements**, all using the same **en_US-ljspeech-high** stock speech model, pace, and clear processing preset. This is one strategic command voice across all factions; existing faction-specific unit acknowledgments retain their own identities. `generate.py` renders speech offline, and `manifest.json` records the transcript, model, and duration of each cue. Model provenance shares `assets/voices/CREDITS.txt`.
- Player-only `player_event` signals report accepted unit queues (**“Building units”**), actual damage (**“Unit under attack” / “Building under attack”**), actual removals (**“Unit lost” / “Building lost”**), accepted placement (**“Construction started”**), completed construction (**“Building constructed”**), actual unit spawning (**“Unit ready”**), insufficient essence, invalid placement, successful training cancellation, blocked producer exits, low/restored power, and Victory/Defeat/Draw. Enemy/AI events and initial entity creation are silent. Snapshot details expose only player-owned entity information. Events do not change simulation costs, timings, damage, production, or state transitions.
- Power announcements occur on transitions, with reset silently seeding the current power state. A blocked-exit warning occurs once for a blocked queue head; waiting units are not announced as ready until actually spawned at a free exit.
- `scripts/announcer.gd` uses one player and at most **four pending messages**. Identical pending messages are coalesced; routine messages expire after **8 seconds**, warnings after **12 seconds**. Under-attack warnings have a **10-second** per-category cooldown, losses **3 seconds**, power/blocked-exit messages **5 seconds**, and other events **1 second**. Higher-priority attack/loss warnings move ahead of routine messages in the pending queue, without interrupting active speech. Results discard stale pending messages and wait for the active unit response or announcement to finish; the result itself never expires.
- Announcements wait for an active unit response to finish. Pending and active announcements hold the speech channel against new unit responses, preventing overlapping or truncated speech. **Unit voices** volume applies live to both players. Muting voices discards pending announcer chatter. Pause freezes unit/announcer playback and the announcement queue clock; resuming continues the same clips. Restart and returning to the title screen intentionally clear stale speech. Match results use the same voice, and shutdown drains the decoder.

Natural-completion verification: all **23 suites** pass. Focused checks include **83 announcer integration**, **56 real simulation-event**, **63 unit-voice**, **137 audio-settings**, and **40 weapon/effects** checks. Tests cover actual unit production preserving active recording and playback position, a real clip reaching its natural end before notification handoff, warning/result queue order, busy effects pools preserving decoders, and Space/Settings pause/resume preserving active clips. Audio assets and gameplay formulas remain unchanged.

## Weapon and construction sound effects

- The existing combat shot path emits `weapon_fired` exactly once when applying damage and creating its beam tracer. `scripts/weapon_audio.gd` receives the event directly; rendering frames and tracer lifetime do not replay sounds. Combat health, damage, armor, range, cooldown, and simulation timing remain as recorded above.
- Six original **44.1 kHz stereo Ogg** effects in `assets/sfx/` give infantry **0.362-second** electrical pulses and tanks **0.672-second** heavier laser discharges, with three variants per role. `assets/sfx/generate.py` renders oscillator sweeps, electrical transients, and short reflections offline without external recordings. There is no runtime synthesis.
- Shots are audible from currently visible on-screen sources on either side; hidden enemy sources and off-screen combat remain silent. The controller uses six preloaded clips, a **12-player** audio pool, and a **35 ms per-role** interval to coalesce dense volleys. These are audio mixing limits, independent of army size and actual firing. There is no sound backlog. New effects use idle players; if all players are busy, excess effects are skipped without restarting an active clip. Pause and modal pause suspend effects in place, and resume continues the same decoders. Match end lets active effects finish while rejecting new ones. Restart and returning to the title screen intentionally clear stale effects; shutdown drains active decoders.
- Two original construction clips add an industrial deployment/assembly cue (**0.912 seconds**) on accepted building placement and a mechanical power-up/completion cue (**1.112 seconds**) when construction actually completes. They are preloaded alongside weapon clips and share the **Sound effects** slider and bounded pool. Only on-screen player construction emits these cues; failed placement, initial structures, and enemy construction remain silent. There is no continuous construction loop or playback on rendering frames. `assets/sfx/generate.py` authors both cues offline.

## Settings

- The single **Settings / Pause** sidebar button and **SETTINGS** on the title/results screens open the same styled modal with **Audio** and **Controls** tabs. The sidebar has no separate pause, restart, music, main-menu, or Attack/Stop/Hold buttons; E/X/H remain the fixed command shortcuts. Opening Settings / Pause freezes an active match. **RESTART** and **MAIN MENU** are inside this modal, below either tab, and keep their existing confirmation dialogs; cancelling a confirmation returns to the same paused settings tab. **RESUME** closes the modal and resumes play, including a match that was already paused before opening it. The Audio tab contains the **MUSIC ON/OFF** toggle. **Controls** lists all fixed mouse/keyboard bindings as read-only labels, with a visible notice that they cannot be changed; it has no rebinding widgets. **Audio** contains the existing volume controls. **Music**, **Unit voices**, and **Sound effects** sliders each run from **0–100%** linear gain, with visible percentage readouts and keyboard focus. **0%** silences that channel; **100%** is **0 dB**. Defaults are approximately **20% music (−14 dB)**, **71% voices (−3 dB)**, and **50% effects (−6 dB)**.
- Adjustments apply immediately and independently, including sounds already playing. **Unit voices** controls unit responses and command announcements together; **Sound effects** controls laser and construction sounds. Music mute is separate from the chosen level: **M** restores that level when unmuted, and changing the slider while muted leaves music muted. A music volume of zero is reflected as **MUSIC OFF**. Voice and effects volume are unaffected by music mute.
- Volume and mute choices survive match restart within the session. No audio settings are written to disk. Opening the modal pauses an active match; **RESUME** returns to play. Outside an active match, **DONE** restores the previous screen. **Esc** closes settings and restores the previous pause state and any underlying screen. Fixed **Space** pause/resume and **M** music shortcuts remain available outside the modal as before.

## Demo verification — 2026-10-25

- `./tests/run.sh`: **788 checks pass**: **236 simulation**, **74 projection/art**, **233 scene integration**, **14 music integration**, **62 unit acknowledgment integration**, **44 audio settings integration**, **29 weapon audio integration**, **51 announcer integration**, and **45 announcer event integration**. Coverage includes destruction snapshots from actual lethal shots, hidden-death suppression, effect aging/expiry/reset, pause freeze, post-match explosions with stopped gameplay and delayed results, authoritative native client/frame pointer sampling with stale viewport coordinates and mouse-inside flags, native decorated-window borders, stale mouse-inside signal priority, exact top/left coordinates and fractional roundoff, expanded viewport coverage and physical mouse-edge scrolling at 1920 × 1080, 3440 × 1440, and 1280 × 1024, banner-free battlefield input, power-meter updates/layout at both viewport sizes, per-building power accounting, producer-only unit prerequisites, selection-independent sidebar production, automatic producer routing, queue cancellation and ownership, difficulty selection/restart retention, actual AI decision and attack timing, worker goals, equal rules across all difficulties, player/AI health and damage parity, harvesting/delivery, regrowth, automatic post-construction harvesting with preserved cargo, construction, power, queues/refunds, blocked exits, visibility, AI notification isolation, selection, HUD boundaries, pause, victory/restart, WASD/arrow movement and E/X command separation, edge scrolling, isometric inverse/footprints, raised-sprite/crystal picking, depth order, zoom anchoring, radar navigation, all six art families, atlas content, fog-cache updates/reset, phased hover motion, anchored shadows, cached shadow separation, bob-aware picking/drag selection, hover freeze at pause/end, music autoplay, mute controls, restart continuity, actual audio loop wrapping, all six unit sound banks, selection/order triggers, group ownership, response rotation, acknowledgment spam suppression, independent volume controls, actual slider mouse/keyboard input, mute-level restoration, modal pause lifecycle, audio layouts at both supported viewport sizes, actual-shot laser timing, volley coalescing, and hidden/off-screen shot suppression.
- All **144 unit cues** decode fully as **44.1 kHz stereo**, with finite samples, quiet file boundaries, and no clipping (decoded peaks below **1.0**). Including attack responses, the bank totals approximately **286.95 seconds**, with individual cues **0.74–2.76 seconds** long. Decode validation also checks transcript/variant completeness.
- Destruction art was rendered and inspected across six phases for Human/Synod infantry, tanks, and Command Centers, then checked in the actual battlefield under the OpenGL renderer. Isolated startup validation confirmed the unchanged **16 entities** and **900 essence per side** before triggering test losses.
- All **six laser clips** decode as finite stereo audio with quiet file boundaries and no clipping (**0.9891** maximum decoded peak, rounded up).
- All **17 announcer clips** decode as finite **44.1 kHz stereo** audio using one model/preset, totaling approximately **20.00 seconds** (**0.71–1.58 seconds** each), with **0.9261** maximum decoded peak. Both construction cues decode fully with quiet boundaries and **0.7714** maximum decoded peak. All prior unit/laser clips are byte-identical.
- The music integration checks require at least **five minutes** of compressed audio, verify actual end-to-start loop wrapping, and retain coverage of autoplay, mute, pause, match results, and restart continuity. The packaged HUD was rendered to verify the music control fits; startup and orderly audio shutdown were checked with an isolated profile.
- The revised **352-second** asset decodes fully as finite stereo audio, with **0.9143** decoded peak (no clipping), **0.1635** RMS, and **0.0010** maximum channel step at the loop boundary. Section RMS ranges from **0.0483** to **0.2110**, preserving contrast between atmosphere and the full band. The main theme and its final reprise have different accompaniment and articulation.
- A scripted Human commander using normal economy/visibility APIs defeated the full AI at **174.3 simulated seconds**. An idle Human base was defeated by AI in an unattended match. These checks demonstrate both match outcomes; they are not long-duration stability measurements.
- Standalone package launched from outside the source directory, passed headless smoke, and completed a rendered battle benchmark. ZIP integrity was verified; executable, PCK, launcher, README, and license notices are bundled together.

The following measurements are the **pre-isometric demo baseline**, retained for reference:

| Rendered benchmark | Starting added combat units | Average FPS | 95th-percentile frame time |
|---|---:|---:|---:|
| Standalone Linux package | 100 | 59.94 | 16.67 ms |
| Source stress battle | 250 | 36.02 | 36.36 ms |

Both benchmarks used the reference machine above at **1366 × 864**, with 60 warm-up frames followed by 300 measured frames. Units move, fight, and die during the measurement; these are starting workloads, not constant living-unit counts. The 250-unit stress case has frame-time spikes below 30 FPS even though its average exceeds 30. No army cap is imposed, and these measurements do not guarantee 30 FPS on other hardware or at arbitrary army sizes.

- Windowed edge correction: real native-pointer probes at the leftmost client pixel and the top of the operating-system title bar both moved the camera in the expected direction. The title-bar probe reproduced a stale **mouse-inside=true** signal. A follow-up live-render-loop probe verified all four client edges at **1366 × 864**, **1100 × 720**, and **1920 × 1080** while deliberately retaining a false mouse-inside flag. Native client/frame sampling handles these cases without mouse confinement.

- Fullscreen correction: a rendered **3840 × 2160** check reproduced the previous **213 px** left border and outside-viewport left/right mouse coordinates under fixed-aspect scaling. With expanded scaling, the viewport covers the entire display from **(0, 0)** to **(3840, 2160)** and all four physical display edges return the correct scroll direction.

- The earlier flat-sprite isometric baseline averaged **71.69 FPS**, with **16.50 ms** 95th-percentile frame time, in a 10-second rendered battle starting with 100 added combat units and VSync disabled.
- The detailed-art baseline before the legless-unit revision passed the same **10-second, 100-unit rendered diagnostic** at **186.64 FPS average** and **6.25 ms** 95th-percentile frame time on the reference machine and viewport. Prerendered bodies, terrain, cliffs, wells, and essence remain cached; the art upgrade adds no per-unit 3D simulation. This wall-clock diagnostic is not directly comparable to the older fixed-frame table above. Packaged sprite/terrain texture loading, smoke, README consistency, and ZIP integrity passed.
- Static-unit revision: all **144 mobile frames** across six visual families and eight facings were visually checked for legless silhouettes, translucent ground shadows, complete still-frame appearance, and atlas clipping. The packaged unit atlas matches the new source; building/terrain assets and gameplay/control source hashes remain unchanged. The full 209-check suite, standalone smoke, README consistency, and ZIP integrity passed.
- Focused Human revision: the **16 Prospector/Vanguard facing frames** were checked for a wheel-free continuous hover hull and a visible human operator in an open cockpit. The other **128 unit frames**, buildings, and terrain are pixel-identical to the prior revision. Packaged atlas alpha/opaque colors match the source, and all 209 checks, standalone smoke, README consistency, and ZIP integrity passed.
- Paladin hovercraft revision: all **eight Paladin facing frames** were visually checked for a continuous swept hover hull, detached shadow, visible lift/drive accents, and no treads or frame-edge clipping. The other **136 unit frames** are RGBA-identical and the building atlas is byte-identical. The procedural fallback uses the same hovercraft silhouette. All **682 checks pass**. Preview: `../artifacts/paladin-hover-preview.png`.
- Hover revision: **249 checks pass**, including body-following picking and drag selection, pause/end freeze, source-image preservation, and cached shadow separation. Rendered opposite-phase frames showed body offsets of approximately **−2.22/+2.22 px**, identical sampled ground-shadow pixels, and unchanged unit positions. The packaged 10-second, 100-unit diagnostic averaged **173.67 FPS**, with **6.25 ms** 95th-percentile frame time on the reference machine. Packaged smoke, raw atlas integrity, README consistency, and ZIP integrity passed. A rendered 2.6-second loop is available at `../artifacts/hover-preview.gif`.
- Difficulty revision: the standalone deployment selector was visually checked at **1366 × 864** and **1100 × 720**. A selected Hard match ran for **40 simulated seconds** without errors. Normal retains the previous AI profile; all three levels pass behavioral timing, economy-goal, fair-rules, deployment, and restart checks. The updated title preview is `../artifacts/title-preview.png`.
- Isometric title screen, developed base, and all-faction artwork gallery were visually inspected. Previews are in `../artifacts/`; that directory is excluded from Godot resource imports. The original art-gallery review preceded the all-faction skirmish update below.

- All-faction skirmish revision: **2,869 checks pass**, including all **36 faction pairings**, faction inheritance through production, six-faction HUD/icons, mirror matches, menu/confirmation freezes, and retained restart settings. The standalone package passes its **95-check menu suite**, isolated-profile startup smoke, and ZIP integrity check. Packaged title, setup, and Heavenly Host match were rendered with OpenGL 3.3 on the reference GPU; title/setup were inspected at **1366 × 864** and **1100 × 720**. Long production names wrap without truncation. Previews: `../artifacts/title-preview.png`, `../artifacts/skirmish-preview.png`, `../artifacts/skirmish-minimum-preview.png`, and `../artifacts/heavenly-host-preview.png`.

- Building silhouette revision: all **30 faction/role models** and their procedural fallbacks were reviewed in **1720 × 1600** galleries. The building atlas retains its dimensions and transparent cell borders; all 30 cells contain unclipped art. The **unit atlas and gameplay data/scripts match their pre-edit SHA-256 hashes**. All **2,869 checks pass**; the rebuilt standalone game rendered the updated battlefield without errors and its ZIP integrity passed. Previews: `../artifacts/building-art.png`, `../artifacts/building-fallback-art.png`, and `../artifacts/building-battlefield-preview.png`.

- Unit silhouette revision: all **18 playable unit models** and procedural fallbacks now have distinct role body plans within each faction. Rendered galleries cover native/2× scale and all **144 facing cells**; each cell contains art with transparent outer borders and no atlas clipping. Model construction, eight-facing geometry bounds, fallback draw/mutation checks, and all **2,869 project checks pass**. The **building atlas, catalog, simulation, projection, and terrain scripts match their pre-edit SHA-256 hashes**. The rebuilt standalone package passes isolated-profile startup smoke, a rendered Kharuun worker/frontline/heavy battlefield and HUD check, and ZIP integrity. Previews: `../artifacts/unit-art.png`, `../artifacts/unit-directions.png`, `../artifacts/unit-fallback-art.png`, and `../artifacts/unit-battlefield-preview.png`.

- Iron Synod sustained-assault revision: **3,470 checks pass** (**236 simulation, 2,503 faction, 173 menu, 74 projection/art, 238 scene, 14 music, 62 voices, 44 audio settings, 30 weapon audio, 51 announcer, 45 events**). Coverage includes all 36 pairings, faction owner parity, real combat and production values, ordinary fog visibility and targeting for every faction and both owners, AI last-observed positions, Synod picking/context orders, and visible/hidden shot audio. Runtime visibility now depends only on ownership and ordinary terrain fog. The rebuilt standalone package passes isolated-profile startup smoke and a packaged Synod stat/visibility/direct-attack check from outside the source directory; bundled README matches source and ZIP integrity passes. The revised setup description and selected Legionary HUD were rendered and inspected at **1100 × 720**, showing **140 HP** and normal order information. Previews: `../artifacts/faction-playstyle-setup.png` and `../artifacts/faction-synod-hud.png`.

## Expanded roster verification — 2026-10-26

- The expanded game passes **14,440 checks**: **236 simulation, 2,611 faction, 173 menu, 74 projection, 238 scene, 14 music, 62 unit voice, 44 audio settings, 30 weapon audio, 51 announcer, 45 events, 1,546 expanded gameplay, 2,516 expanded art, 4,011 expanded voice, 722 expanded UI, 23 expanded AI/construction, and 2,044 Synod adult voice**. Coverage includes all six 21-unit/13-building rosters, tech gating before charges, paid queue behavior and exact refunds, exit handling, faction abilities, power activation, body-radius turret acquisition, healer range behavior, diagonal builder completion/cargo delivery, paged cards, unit-specific recordings, and ordinary fog/AI fairness.
- All **108 new mobile models** were baked in eight facings (**864 frames**), plus **48 new building sprites**; original atlases are byte-identical. Baked/fallback galleries and all faction HUDs were rendered at **1100 × 720** and **1366 × 864**, with full queue/producer names and reachable page controls.
- The **936 additional acknowledgment cues** provide three variants per supported action for all 108 added units; unarmed healers/repair units have selection/movement responses, while armed units also have attack responses. There are **1,080 unit recordings** total. All decode as finite **44.1 kHz stereo**, have quiet boundaries, and stay below clipping. Only Human cues retain dialogue; the current wordless faction revision is recorded below.
- In six separate **600-second economy-only fixtures**, normal AI harvesting and spending completed all eight new buildings: Humans **360 s**, Synod **384 s**, Kharuun **281 s**, Host **412 s**, Infernal **272 s**, Veyr **417 s**. Armies included **13/11/17/9/14/5** distinct new types respectively. Combat attack orders were suppressed only in the fixture to keep the match alive; no resources, workers, construction speed, training speed, vision, or refunds were granted. Normal matches retain their battle and win conditions.
- The packaged **10-second rendered battle** with **100 added mixed new units**, 16 normal starting entities, an **8-second simulation warm-up** and **60 rendered warm-up frames**, measured **193.48 FPS average** and **13.53 ms p95 frame time** at **1366 × 864**, VSync disabled, on the documented Ryzen 7 7800X3D / RTX 4070 SUPER reference system. Host and Veyr fielded healing, wards, artillery, slowing, and heavy counters; **59 entities** remained at completion. This is a changing combat workload, not an arbitrary-unit-count performance guarantee. Preview: `../artifacts/expansion-battle-package.png`.

Final equal-budget combat sweep (**90 fixtures**, three compositions, mirrored deployment; draws score half):

| Side | Wins | Draws | Losses | Scored result |
|---|---:|---:|---:|---:|
| Humans | 16 | 0 | 14 | 53.3% |
| Iron Synod | 13 | 3 | 14 | 48.3% |
| Kharuun Brood | 13 | 1 | 16 | 45.0% |
| Heavenly Host | 10 | 5 | 15 | 41.7% |
| Infernal Legion | 16 | 0 | 14 | 53.3% |
| Veyr Dominion | 16 | 3 | 11 | 58.3% |

The final spread is **41.7–58.3%** in this controlled composition sweep. No faction wins every composition; counters, scouting, economy, player decisions, and terrain can change live-match outcomes. Full per-fixture results: `../artifacts/balance-final.json`. The sweep was repeated after tuning the newly added units; original unit/building values stayed fixed.

### Wordless faction sound revision — 2026-10-26

Only Human units speak. All **180 Human recordings** and the **96 original non-Synod wordless cues**, including every Seraph Guard response, remain byte-identical. The **804 former spoken non-Human responses** are replaced with procedural faction sounds, bringing all **900 non-Human cues** under their faction’s wordless theme. Every unit/action retains its runtime path and three variants; gameplay and command timing are unchanged.

`faction_theme_revision.json` records the revision, five sound themes, **276 preserved hashes**, **804 previous/current replacement hashes**, and all **900 current non-Human hashes**. Non-Human manifest entries contain no dialogue or speech-cast metadata. Regression coverage checks protected recordings, full 21-role coverage per family, procedural sound metadata, current hashes, and all expanded acknowledgment banks. The previous Synod adult regional speech revision is superseded by this request.

The final Linux bundle passes isolated-profile launcher smoke from outside the source tree and **1,392 packaged roster/art/audio checks**, including loading all **1,080 packaged recordings** and matching their current source-manifest durations. The bundled README/voice credits match source, and ZIP integrity passes. Final minimum-size packaged HUD verification confirms full 60-pixel catalog cards and complete faction names/costs.

## Building actions and Controls verification — 2026-10-26

- All **15,116 checks pass** across 19 suites. New coverage includes **536 building-action checks**, **58 building-action UI checks**, and **82 additional settings checks**. These verify paid repair timing, insufficient funds/resumption, original faction regeneration, all six factions and both owners, health-scaled salvage, recorded queue refunds, blocked production, construction-worker cargo/manual orders, immediate navigation/power/fog/prerequisite changes, Command Center confirmation/outcomes, pause/end gating, and stale confirmation cleanup on restart.
- Controls are read-only and complete, with unchanged bindings. Settings tabs and building action text/bounds pass at **1366 × 864** and **1100 × 720**. The standalone package passes all **720 targeted building/settings checks**, isolated-profile startup with **16 entities and 900 essence per side**, launcher smoke from outside the source directory, README consistency, and ZIP integrity. Packaged OpenGL renders were inspected for building actions, Settings → Controls, and the Command Center sale warning. Previews: `../artifacts/building-actions-preview.png`, `../artifacts/settings-controls-preview.png`, and `../artifacts/building-sale-warning-preview.png`.

## Consolidated pause menu verification — 2026-10-26

- All **15,254 checks pass** across 20 suites, including **138 new pause-menu checks**. The sidebar exposes one **Settings / Pause** button; Attack/Stop/Hold, the small pause button, Restart, Music, and Main Menu no longer appear as separate sidebar controls. The fixed E/X/H/Space/M shortcuts remain functional.
- The menu pauses simulation and orders, retains Audio/Controls, moves music mute into Audio, and makes Restart/Main Menu available below both tabs. Confirmation cancellation preserves the same paused tab; confirmed restart/leave clears modal state; Resume also resumes a previously paused match. Session audio choices survive navigation/restarts.
- The rebuilt standalone package passes **451 targeted pause/settings/music/menu checks**, unchanged **16-entity, 900-essence-per-side** startup, README consistency, and ZIP integrity. Packaged OpenGL sidebar, Audio, and Controls layouts were inspected at **1366 × 864** and **1100 × 720**. Previews: `../artifacts/pause-sidebar-1366x864.png`, `../artifacts/pause-settings-1100x720.png`, and `../artifacts/pause-controls-1100x720.png`.

## Remaining design decisions

- Competitive tuning of the initial faction balance pass, additional roster units, abilities, upgrades, and production prerequisites beyond the demo.
- Aetherbound portal mechanics and their relationship to the closed gates. Subfaction selection is implemented independently for each commander.
- Ark details, campaign progression, and any future persistence.
