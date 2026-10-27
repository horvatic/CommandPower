# CommandPower factions

## Setting

The year is **35,000 AD**. Across worlds settled, abandoned, and rediscovered over millennia, advanced technology exists alongside magic, psychic powers, engineered biology, and alien abilities. Five major factions compete for territory, resources, and the remains of earlier civilizations; the Aetherbound are divided into two rival subfactions.

**Galactic war:** Every faction is at war with every other faction and seeks control of the entire galaxy. The Heavenly Host and Infernal Legion each pursue this goal independently; both are hostile to one another and to all other factions. The angels seek galactic control in order to eradicate all existing life and start over, while the demons seek dominion for demonkind.

Humans use both magic and advanced military technology, including high-tech tanks. Each of the four other factions has a different origin, army composition, and battlefield identity.

This is the fixed faction catalog. Each selectable side now fields **21 units and 13 buildings**: its original three units/five buildings plus 18 new units/eight faction-specific structures. The two Aetherbound hosts have independent rosters. Exact stats, costs, timers, prerequisites, and automatic support/weapon rules are recorded in `docs/DESIGN.md` and mirrored in `scripts/roster_data.json`. All units retain legless ground-moving forms and the established faction identities.

**Shared art requirement:** All factions use artwork that looks convincing without animation. Mobile units have no visible legs or feet and need no walk, crawl, or wing-flapping cycle. Preserve the unit names and battlefield roles below while using enclosed chassis, hovering bodies, floating plant forms, legless spirits, or suspended crystals as detailed in `DESIGN.md`. Wings can be fixed decorative forms. These visual treatments do not grant flight or terrain bypass and supersede earlier legged visual concepts.

## Galactic control

The current division of territory in the material galaxy is:

| Faction | Galactic territory controlled |
|---|---|
| Humans | 30% |
| Iron Synod | 30% |
| Kharuun Brood | 20% |
| Veyr Dominion | 20% |
| Aetherbound | 0% |

These shares total 100% and describe the setting, not starting territory or resource allocations in an individual skirmish. Heaven and Hell are outside this territorial division. The Aetherbound enter the galaxy through portals from those realms.

## The closed gates and the Ark

God has **closed the gates of Heaven and Hell**. The souls of deceased life forms can no longer enter either realm and remain in Limbo.

God has also **already carried out a spacefaring version of Noah's Ark**, preserving life aboard an ark in space. This event took place before the current setting of 35,000 AD. Its exact date, passengers, destination, and current location have not yet been defined.

The established Aetherbound portal incursions remain part of the setting. How these portals operate despite the closed gates has not yet been defined.

## Limbo and spirit energy

When humans or other life forms die, their souls no longer pass into Heaven or Hell because God has closed the gates. They are left to wander **Limbo**.

**Every faction**, including both Aetherbound subfactions, can use **Limbo spirit energy to produce more units**. This energy manifests as **spiritual essence growing around spiritual wells**. Workers harvest that growth and deliver it to a Refinery or Command Center; depleted growth regenerates over time. The resource loop follows the classic Command & Conquer harvesting model, with spiritual essence replacing its mineral resource. Essence is the demo's single currency for construction and unit production. Exact demo values are recorded in `docs/DESIGN.md`; death grants no automatic resource reward, and spirit-powered production is not resurrection.

## Humans

**Background:** In the game's alternate history, China achieved control of Earth in 2030 and subsequently led humanity's expansion into space. Over the following millennia, that world state developed into a vast interstellar empire whose institutions and cultural roots trace back to China.

By **35,000 AD**, the Human Empire spans an immense number of star systems. Its worlds belong to one enormous imperial civilization rather than an alliance of divided colonies. Its military combines advanced technology, high-tech tanks, and battlefield magic to defend its territories and extend imperial rule.

**Army identity:** Flexible combined arms. Infantry and high-tech tanks form the main force; battlefield mages protect and support them.

| Unit | Type and role |
|---|---|
| Prospector | Worker using industrial equipment to gather resources and construct buildings, carried by a wheel-free hover hull with a continuous underside and no wheel-like side pods or tread belts. |
| Vanguard | Human frontline operator in an open armored hover vehicle. The person's head, exposed face, upper torso, and hands must be visible; the cockpit conceals legs and feet. Retains the infantry combat role. |
| Paladin Tank | High-tech hovercraft battle tank combining an advanced cannon with enchanted armor, a continuous swept hover hull, and recessed lift machinery; no treads or wheels. |
| Pathfinder | Fast ground reconnaissance and light harassment; weak in direct combat. |
| Dragoon | Mobile ranged anti-light screen; fragile under concentrated fire. |
| Horizon Marksman | Long-range light-unit hunter; slow shots and poor heavy-target efficiency. 2 armor piercing. |
| Stormguard | Close assault with a small blast; kited by ranged formations. 20-px blast. |
| Breach Pioneer | Short-range structure breaker; inefficient against heavy mobile armor. |
| Aegis Marshal | Slow ward-bearing frontline; limited damage and exposed flanks. +1.5 armor ward. |
| Arcanist | Human mage specializing in protective wards and support spells. 6 HP/s unit healing; +2 armor ward. |
| Field Artificer | Unarmed structure repair support; cannot repair mobile units or resurrect. 12 HP/s structure repair. |
| Sentinel Walker | Combat mech carrying weapons specialized against heavy armor. 2 armor piercing. |
| Tempest Carrier | Anti-swarm blast platform; armor and dispersed troops reduce its efficiency. 45-px blast. |
| Longbow Launcher | Missile artillery for attacking fixed positions from behind the frontline. 42-px blast; 150-px minimum range. |
| Thunder Mortar | Light indirect-fire area pressure; vulnerable inside its minimum range. 50-px blast; 90-px minimum range. |
| Sabre Interceptor | Fast heavy raider for workers and structures; weak against heavy defenders. |
| Lancer Destroyer | Heavy-target hunter; slow and inefficient against massed light units. 2 armor piercing. |
| Imperial Bastion | Costly close-range armored anchor; long-range fire and flanks punish it. 32-px blast. |
| Nullifier | Low-damage slowing fire controls movement; needs damage-dealing partners. 70% movement slow. |
| Siegebreaker | Heavy structure siege with a minimum range; vulnerable to close assaults. 2 armor piercing; 25-px blast; 110-px minimum range. |
| Imperial Strategos | Expensive ward command platform; limited damage for its cost. +2 armor ward. |

| New structure | Role and faction function |
|---|---|
| Forward Command Post | Forward reconnaissance anchor with 620-pixel vision; low combat durability. Uses 5 power when complete. |
| Sentinel Turret | Rapid anti-light ground defense; needs power and is vulnerable to siege. Uses 12 power when complete. |
| Aegis Cannon | Heavy-target defensive battery; slow shots lose efficiency against swarms. Uses 28 power when complete. |
| Motor Workshop | Produces mobile workshop specialists, raiders, and disruption platforms. Uses 30 power when complete. |
| Arcane Academy | Produces healers, frontline ward carriers, and command support. Uses 25 power when complete. |
| Siege Arsenal | Produces escorted siege artillery and anti-heavy destruction platforms. Uses 45 power when complete. |
| Fusion Reactor | Advanced power generation; expensive and vulnerable if left unguarded. Supplies 220 power. |
| Ward Relay | Stationary faction support; concentrate fire or siege to break its position. +2 armor ward. Uses 25 power when complete. |

**Playable style — combined arms:** Humans retain the balanced original frontline/tank values. Moderate cost, speed, durability, and weapon range reward mixing Vanguards and Paladin Tanks rather than relying on one extreme.

**Strengths:** Adaptable armies and dependable general-purpose combat units; armor-piercing specialists, conventional siege weapons, and practical protective support magic.

**Weaknesses:** General-purpose units can be outmatched by enemy specialists; success depends on combining unit roles.

**Visual direction:** Industrial armor, recognizable tank tracks and turrets, powered infantry suits, and restrained glowing runes.

## Iron Synod

**Background:** The Iron Synod is a collective civilization formed by alien species, humans, and other beings merging with an artificial intelligence. At its center is a **Super AI** that controls the collective and coordinates its civilization and military. Its members share a connected existence known as the **Singularity**.

Life forms from any faction can join the Singularity by merging their minds and bodies with the AI network through interfaces adapted to their nature. The Synod incorporates knowledge and selected technologies from its members: human engineering and arcane technology, Kharuun biotechnology, Aetherbound spirit-binding, and Veyr crystal and gravity systems. It combines these into its own hybrid designs rather than simply fielding every other faction's roster.

**Army identity:** Hybrid warriors directed by a single intelligence. Organic bodies, cybernetic systems, magic interfaces, and alien technologies function together in coordinated formations.

| Unit | Type and role |
|---|---|
| Synapse Harvester | Worker combining a cybernetic chassis with biological manipulators for gathering and construction. |
| Convergent Legionary | Infantry drawn from different species, augmented with cybernetics and standardized hybrid weapons. |
| Chimera Tank | Heavy combat vehicle combining human-inspired engineering, living armor, and crystalline defensive technology. |
| Neural Seeker | Light ground scout combining an integrated alien mind with advanced sensors. 1 HP/s regeneration after disengaging. |
| Mesh Skirmisher | Mobile ranged anti-light screen; fragile under concentrated fire. 1 HP/s regeneration after disengaging. |
| Optic Exactor | Long-range light-unit hunter; slow shots and poor heavy-target efficiency. 1 HP/s regeneration after disengaging. |
| Pulse Ravager | Close assault with a small blast; kited by ranged formations. 20-px blast; 1 HP/s regeneration after disengaging. |
| Breach Assimilator | Short-range structure breaker; inefficient against heavy mobile armor. 1 HP/s regeneration after disengaging. |
| Cohort Bulwark | Slow ward-bearing frontline; limited damage and exposed flanks. +1 armor ward; 1 HP/s regeneration after disengaging. |
| Nexus Warden | Support unit that maintains allied biological and mechanical systems and coordinates the local formation. 9 HP/s unit healing; 0.5 HP/s regeneration after disengaging. |
| Reclaimer Drone | Unarmed structure repair support; cannot repair mobile units or resurrect. 16 HP/s structure repair; 0.5 HP/s regeneration after disengaging. |
| Induction Spear | Anti-heavy specialist; smaller damage against light targets. 1 HP/s regeneration after disengaging. |
| Signal Obliterator | Anti-swarm blast platform; armor and dispersed troops reduce its efficiency. 45-px blast; 1 HP/s regeneration after disengaging. |
| Convergence Engine | Siege platform combining electromagnetic launch systems with Veyr-derived gravity and resonance technology. 42-px blast; 145.5-px minimum range; 2 HP/s regeneration after disengaging. |
| Synaptic Lobber | Light indirect-fire area pressure; vulnerable inside its minimum range. 50-px blast; 87.3-px minimum range; 1 HP/s regeneration after disengaging. |
| Chorus Raider | Fast heavy raider for workers and structures; weak against heavy defenders. 2 HP/s regeneration after disengaging. |
| Terminus Crusher | Heavy-target hunter; slow and inefficient against massed light units. 2 HP/s regeneration after disengaging. |
| Dominion Shell | Costly close-range armored anchor; long-range fire and flanks punish it. 32-px blast; 2 HP/s regeneration after disengaging. |
| Phase Jammer | Low-damage slowing fire controls movement; needs damage-dealing partners. 1 HP/s regeneration after disengaging; 70% movement slow. |
| Oblivion Rig | Heavy structure siege with a minimum range; vulnerable to close assaults. 25-px blast; 106.7-px minimum range; 2 HP/s regeneration after disengaging. |
| Consensus Prime | Expensive ward command platform; limited damage for its cost. +2 armor ward; 1 HP/s regeneration after disengaging. |

| New structure | Role and faction function |
|---|---|
| Synapse Pylon | Forward reconnaissance anchor with 620-pixel vision; low combat durability. 2.5 HP/s regeneration after disengaging. Uses 6 power when complete. |
| Needle Battery | Rapid anti-light ground defense; needs power and is vulnerable to siege. 2.5 HP/s regeneration after disengaging. Uses 13 power when complete. |
| Convergence Cannon | Heavy-target defensive battery; slow shots lose efficiency against swarms. 2.5 HP/s regeneration after disengaging. Uses 31 power when complete. |
| Integration Foundry | Produces mobile workshop specialists, raiders, and disruption platforms. 2.5 HP/s regeneration after disengaging. Uses 33 power when complete. |
| Neural Crucible | Produces healers, frontline ward carriers, and command support. 2.5 HP/s regeneration after disengaging. Uses 28 power when complete. |
| Consensus Forge | Produces escorted siege artillery and anti-heavy destruction platforms. 2.5 HP/s regeneration after disengaging. Uses 50 power when complete. |
| Singularity Reactor | Advanced power generation; expensive and vulnerable if left unguarded. 2.5 HP/s regeneration after disengaging. Supplies 245 power. |
| Restoration Node | Stationary faction support; concentrate fire or siege to break its position. 18 HP/s structure repair; 2.5 HP/s regeneration after disengaging. Uses 28 power when complete. |

**Playable style — sustained assault:** Convergent Legionaries and Chimera Tanks combine resilient hybrid armor with rapid, repeated attacks. They advance with modest mobility and maintain pressure through short firing cooldowns. Their smaller individual hits lose efficiency against heavy armor, and their expensive units take longer to replace than Human equivalents. Visibility follows ordinary fog of war for every faction.

**Strengths:** Resilient frontline units and steady rapid-fire pressure. Disengagement regeneration and structure-repair support preserve its expensive hybrid armies.

**Weaknesses:** Expensive replacements and smaller individual attacks make losses costly and heavy armor difficult to overcome efficiently. Complex hybrid forces rely on coordination, and access to many technologies does not make every Synod unit superior to its source faction's specialists.

**Visual direction:** Different alien anatomies joined by a consistent cybernetic design: living tissue, metal frames, crystalline implants, arcane circuitry, and shared neural lights.

**Membership and gameplay:** Other life forms can join the Singularity in the setting. This does not establish an in-match enemy-conversion ability, unrestricted access to other factions' units, or omniscient AI vision; those rules remain subject to the shared design boundaries.

## Kharuun Brood

**Background:** The Kharuun are a plant-based species that evolved into an intelligent civilization. Over countless generations, interconnected forests developed memory, language, and mobile plant bodies. Their cities are cultivated living environments, and their science shapes roots, bark, seeds, sap, and other biological materials into tools and weapons.

They defend their inhabited ecosystems and cultivate new worlds through deliberate biological engineering. Their armies are intelligent plant beings and cultivated warforms, rather than animal swarms.

**Army identity:** Botanical warfare. Mobile plant soldiers fight with thorn projectiles, corrosive sap, toxic pollen, and explosive seed pods, supported by living artillery and restorative flora.

| Unit | Type and role |
|---|---|
| Root Tender | Plant worker that gathers and carries resources and cultivates living buildings. |
| Barkguard | Heavy infantry protected by dense bark and wielding hardened botanical weapons. |
| Seedspine | Living artillery that launches explosive seed pods against entrenched positions. |
| Thornrunner | Light mobile plant scout armed with defensive thorns. 1 HP/s regeneration after disengaging. |
| Bristle Pod | Mobile ranged anti-light screen; fragile under concentrated fire. 1 HP/s regeneration after disengaging. |
| Needle Orchid | Long-range light-unit hunter; slow shots and poor heavy-target efficiency. 1 HP/s regeneration after disengaging. |
| Bramble Husk | Close assault with a small blast; kited by ranged formations. 20-px blast; 1 HP/s regeneration after disengaging. |
| Rotcap Burster | Short-range structure breaker; inefficient against heavy mobile armor. 1 HP/s regeneration after disengaging. |
| Ironbark Sentinel | Slow ward-bearing frontline; limited damage and exposed flanks. 5 HP/s unit healing; 1 HP/s regeneration after disengaging. |
| Grovekeeper | Support plant that tends wounded biological allies with restorative compounds. 7 HP/s unit healing; 1 HP/s regeneration after disengaging. |
| Sap Mender | Unarmed structure repair support; cannot repair mobile units or resurrect. 12 HP/s structure repair; 1 HP/s regeneration after disengaging. |
| Pikevine | Anti-heavy specialist; smaller damage against light targets. 1 HP/s regeneration after disengaging. |
| Acid Bloom | Mobile ranged warform that projects corrosive sap and toxic pollen. 45-px blast; 1 HP/s regeneration after disengaging; 82% movement slow. |
| Spore Howitzer | Long-range area siege; minimum range and low mobility require an escort. 42-px blast; 136.5-px minimum range; 2 HP/s regeneration after disengaging. |
| Seed Mortar | Light indirect-fire area pressure; vulnerable inside its minimum range. 50-px blast; 81.9-px minimum range; 1 HP/s regeneration after disengaging; 82% movement slow. |
| Vine Skimmer | Fast heavy raider for workers and structures; weak against heavy defenders. 2 HP/s regeneration after disengaging. |
| Corrosion Cyst | Heavy-target hunter; slow and inefficient against massed light units. 2 HP/s regeneration after disengaging. |
| Elderwood Titan | Costly close-range armored anchor; long-range fire and flanks punish it. 32-px blast; 2 HP/s regeneration after disengaging. |
| Pollen Warden | Low-damage slowing fire controls movement; needs damage-dealing partners. 1 HP/s regeneration after disengaging; 65% movement slow. |
| Worldroot Slinger | Heavy structure siege with a minimum range; vulnerable to close assaults. 25-px blast; 100.1-px minimum range; 2 HP/s regeneration after disengaging. |
| Elder Conductor | Expensive ward command platform; limited damage for its cost. 8 HP/s unit healing; 1 HP/s regeneration after disengaging. |

| New structure | Role and faction function |
|---|---|
| Watchbloom | Forward reconnaissance anchor with 620-pixel vision; low combat durability. 2 HP/s regeneration after disengaging. Uses 5 power when complete. |
| Thorn Nest | Rapid anti-light ground defense; needs power and is vulnerable to siege. 2 HP/s regeneration after disengaging; 85% movement slow. Uses 12 power when complete. |
| Acid Bulwark | Heavy-target defensive battery; slow shots lose efficiency against swarms. 30-px blast; 2 HP/s regeneration after disengaging; 85% movement slow. Uses 28 power when complete. |
| Bud Nursery | Produces mobile workshop specialists, raiders, and disruption platforms. 2 HP/s regeneration after disengaging. Uses 30 power when complete. |
| Elder Grove | Produces healers, frontline ward carriers, and command support. 2 HP/s regeneration after disengaging. Uses 25 power when complete. |
| Seed Crucible | Produces escorted siege artillery and anti-heavy destruction platforms. 2 HP/s regeneration after disengaging. Uses 45 power when complete. |
| Photosynthesis Spire | Advanced power generation; expensive and vulnerable if left unguarded. 2 HP/s regeneration after disengaging. Supplies 175 power. |
| Mycelial Heart | Stationary faction support; concentrate fire or siege to break its position. 8 HP/s unit healing; 2 HP/s regeneration after disengaging. Uses 25 power when complete. |

**Playable style — mass armies:** The playable Barkguard and Seedspine are cheap, quickly grown warforms with low individual health and damage. Build multiple producers, replace losses quickly, and overwhelm exposed positions with numbers. Barkguard bark remains a frontline silhouette and a defensive trait relative to lighter plant scouts; it does not give the demo unit elite durability.

**Strengths:** Low costs, rapid production, and large replaceable armies. Regenerating bodies, restorative plants, and sap/pollen slowing blasts sustain the swarm.

**Weaknesses:** Weak individual units lose isolated fights, and armor reduces their small attacks sharply. Close-range plants are exposed while crossing open ground; artillery and restorative plants need protection from fast attackers.

**Visual direction:** Bark armor, branching limbs, vines, flowers, luminous sap, and cultivated tree-like buildings. Distinguish soldiers, workers, and artillery through their plant silhouettes.

## Aetherbound

**Background:** The Aetherbound are angelic and demonic spirit beings from **Heaven** and **Hell**. They control **0% of the material galaxy** and enter it through portals from their home realms, manifesting physical bodies and wielding spiritual and psychic powers. Their two subfactions, the **Heavenly Host** and the **Infernal Legion**, are locked in an enduring war against one another across their home realms and the inhabited worlds of the far future.

The Aetherbound name describes their shared spiritual nature, not a united empire or a permanent alliance. **Demons seek to conquer the galaxy for demonkind. Angels seek to wipe out all life in the galaxy so they can start over.** Neither realm now receives the souls of deceased galactic life forms; those souls remain in Limbo. Both sides can use Limbo spirit energy for unit production, just as the other factions can.

**Army identity:** Spirit and psychic warfare. Both sides field supernatural soldiers, psychic casters, and powerful embodied warforms; angels emphasize protection and disciplined formations, while demons emphasize aggressive assaults and destructive spiritual attacks.

### Heavenly Host — angels

**Background:** The Heavenly Host comes through portals from Heaven. Its angelic orders intend to eradicate all life in the galaxy and begin creation anew. Their discipline and protective battlefield magic serve this extermination campaign rather than a mission to protect galactic civilizations. They also wage continual war against the demons of Hell.

| Unit | Type and role |
|---|---|
| Sanctifier | Angelic worker that gathers resources and constructs sacred structures. |
| Seraph Guard | Armored angelic frontline soldier wielding a radiant weapon. |
| Sanctum Colossus | Large spirit-bound construct used to assault fortified positions. |
| Dawn Seer | Light scout using spiritual perception to observe visible threats. |
| Dawn Herald | Mobile ranged anti-light screen; fragile under concentrated fire. |
| Judicator | Psychic combat caster directing focused spiritual attacks against heavy enemies. |
| Solar Avenger | Close assault with a small blast; kited by ranged formations. 20-px blast. |
| Gatebreaker | Short-range structure breaker; inefficient against heavy mobile armor. |
| Aegis Seraph | Slow ward-bearing frontline; limited damage and exposed flanks. +4 armor ward. |
| Choir Warden | Support caster that protects allied formations with spiritual wards. 11 HP/s unit healing; +3 armor ward. |
| Reliquary Tender | Unarmed structure repair support; cannot repair mobile units or resurrect. 14 HP/s structure repair. |
| Sunlance | Anti-heavy specialist; smaller damage against light targets. |
| Purifier | Anti-swarm blast platform; armor and dispersed troops reduce its efficiency. 45-px blast. |
| Heaven's Decree | Long-range area siege; minimum range and low mobility require an escort. 42-px blast; 138-px minimum range. |
| Bell Mortar | Light indirect-fire area pressure; vulnerable inside its minimum range. 50-px blast; 82.8-px minimum range. |
| Aurora Chariot | Fast heavy raider for workers and structures; weak against heavy defenders. |
| Exorcist | Heavy-target hunter; slow and inefficient against massed light units. |
| Throne Guardian | Costly close-range armored anchor; long-range fire and flanks punish it. 32-px blast. |
| Stillness Cantor | Low-damage slowing fire controls movement; needs damage-dealing partners. 70% movement slow. |
| Firmament Engine | Heavy structure siege with a minimum range; vulnerable to close assaults. 25-px blast; 101.2-px minimum range. |
| Archon | Expensive ward command platform; limited damage for its cost. +4 armor ward. |

| New structure | Role and faction function |
|---|---|
| Vigil Spire | Forward reconnaissance anchor with 620-pixel vision; low combat durability. Uses 5 power when complete. |
| Dawn Lance | Rapid anti-light ground defense; needs power and is vulnerable to siege. Uses 12 power when complete. |
| Judgment Bastion | Heavy-target defensive battery; slow shots lose efficiency against swarms. Uses 28 power when complete. |
| Reliquary Works | Produces mobile workshop specialists, raiders, and disruption platforms. Uses 30 power when complete. |
| Choir Sanctum | Produces healers, frontline ward carriers, and command support. Uses 25 power when complete. |
| Tribunal Forge | Produces escorted siege artillery and anti-heavy destruction platforms. Uses 45 power when complete. |
| Radiant Font | Advanced power generation; expensive and vulnerable if left unguarded. Supplies 285 power. |
| Sanctuary Beacon | Stationary faction support; concentrate fire or siege to break its position. 4 HP/s unit healing; +4 armor ward. Uses 25 power when complete. |

**Playable style — defensive elites:** Seraph Guards and Sanctum Colossi have high health and armor, trading movement speed, weapon reach, cost, and training time for staying power. Hold contested ground with a compact, resilient army. Their support specialists now project strong nonstacking wards and restore nearby wounded units.

**Strengths:** Durable frontline units and disciplined defensive formations; protective wards, restorative choirs, and focused psychic specialists.

**Weaknesses:** Expensive losses are slow to replace, and short reach lets mobile enemies kite them or attack distant objectives. Lighter units depend on ward support; breaking up a formation exposes its vulnerable casters.

**Visual direction:** Angelic wings, halos, luminous armor, sacred geometry, and radiant spirit cores.

### Infernal Legion — demons

**Background:** The Infernal Legion comes through portals from Hell and seeks to conquer the entire galaxy for demonkind. Its hosts fight the Heavenly Host while pursuing dominion over the existing galactic civilizations.

| Unit | Type and role |
|---|---|
| Ashshaper | Demonic worker that gathers resources and constructs infernal structures. |
| Hellblade | Close-assault demon armed with an infernal weapon. |
| Infernal Behemoth | Massive embodied demon used to break through fortified positions. |
| Whisperfiend | Light scout specializing in observing enemy approaches. |
| Cinder Stalker | Mobile ranged anti-light screen; fragile under concentrated fire. |
| Dreadweaver | Ranged caster that attacks enemies through destructive psychic force. |
| Ragebound | Close assault with a small blast; kited by ranged formations. 20-px blast; 12% damage drain. |
| Wallreaper | Short-range structure breaker; inefficient against heavy mobile armor. 12% damage drain. |
| Obsidian Guard | Slow ward-bearing frontline; limited damage and exposed flanks. 16% damage drain. |
| Flesh Cantor | Unarmed single-target mobile-unit healer; protect it from raids. 9 HP/s unit healing. |
| Forge Wretch | Unarmed structure repair support; cannot repair mobile units or resurrect. 12 HP/s structure repair. |
| Soulbreaker | Specialist directing concentrated spiritual attacks against heavily protected enemies. |
| Ash Torrent | Anti-swarm blast platform; armor and dispersed troops reduce its efficiency. 45-px blast. |
| Doom Caller | Long-range area siege; minimum range and low mobility require an escort. 42-px blast; 120-px minimum range. |
| Brimstone Maw | Light indirect-fire area pressure; vulnerable inside its minimum range. 50-px blast; 72-px minimum range. |
| Scourge Chariot | Fast heavy raider for workers and structures; weak against heavy defenders. 12% damage drain. |
| Ruin Butcher | Heavy-target hunter; slow and inefficient against massed light units. |
| Abyssal Tyrant | Costly close-range armored anchor; long-range fire and flanks punish it. 32-px blast; 12% damage drain. |
| Fear Binder | Low-damage slowing fire controls movement; needs damage-dealing partners. 72% movement slow. |
| Apocalypse Engine | Heavy structure siege with a minimum range; vulnerable to close assaults. 25-px blast; 88-px minimum range. |
| Warfiend Regent | Expensive ward command platform; limited damage for its cost. 20% damage drain. |

| New structure | Role and faction function |
|---|---|
| Eye of Ruin | Forward reconnaissance anchor with 620-pixel vision; low combat durability. Uses 5 power when complete. |
| Ember Spitter | Rapid anti-light ground defense; needs power and is vulnerable to siege. 8% damage drain. Uses 12 power when complete. |
| Hellfire Citadel | Heavy-target defensive battery; slow shots lose efficiency against swarms. 8% damage drain. Uses 28 power when complete. |
| War Cauldron | Produces mobile workshop specialists, raiders, and disruption platforms. Uses 30 power when complete. |
| Pain Chapel | Produces healers, frontline ward carriers, and command support. Uses 25 power when complete. |
| Ruin Foundry | Produces escorted siege artillery and anti-heavy destruction platforms. Uses 45 power when complete. |
| Inferno Furnace | Advanced power generation; expensive and vulnerable if left unguarded. Supplies 190 power. |
| Blood Obelisk | Stationary faction support; concentrate fire or siege to break its position. 9 HP/s unit healing. Uses 25 power when complete. |

**Playable style — assault rush:** Hellblades and Infernal Behemoths move quickly and strike hard at short range, with lower durability than balanced Human combat units. Concentrate attacks on exposed workers and isolated forces, then move before a defensive line can answer.

**Strengths:** Fast assaults and high damage; destructive spirit attacks, drain-on-hit assault specialists, and strong psychic offense.

**Weaknesses:** Fragile assault forces must close through enemy fire and fare poorly in prolonged fights against prepared defenses. Ranged caster support broadens their options against entrenched enemies.

**Visual direction:** Horns, infernal armor, ember-lit bodies, jagged silhouettes, and dark psychic effects.

**Subfaction boundaries:** Heaven and Hell are real realms in this setting, and portal-based arrival and the angel-demon conflict are established lore. Each subfaction is hostile to the other and to every other faction. Each subfaction is independently selectable in skirmish setup. Portal placement and portal production rules remain undefined; do not implement random friendly attacks or a combined allied angel-demon roster by assumption. Arrival portals do not establish unrestricted tactical teleportation or free reinforcements. Wings and spiritual origins do not automatically grant flight, terrain bypass, invulnerability, or resurrection. Psychic perception obeys fog of war.

## Veyr Dominion

**Background:** The Veyr are crystalline aliens whose memories are preserved within living mineral structures. Their ancient dominions were built around resonance and gravity manipulation. They consider the disorder of younger civilizations a danger to their ancestral worlds and expand through calculated military campaigns.

**Army identity:** Heavy siege and positional control. Durable crystalline formations advance methodically behind gravity weapons and resonant artillery.

| Unit | Type and role |
|---|---|
| Shard Tender | Worker that harvests resources and assembles crystalline structures. |
| Crystal Guard | Durable infantry with focused resonance weapons. |
| Monolith | Heavy ground combat vehicle built around a protected crystal core. |
| Prism Scout | Light surveying unit that identifies routes and distant threats. |
| Facet Skimmer | Mobile ranged anti-light screen; fragile under concentrated fire. |
| Lens Sentinel | Long-range light-unit hunter; slow shots and poor heavy-target efficiency. 85% movement slow. |
| Impact Shard | Close assault with a small blast; kited by ranged formations. 20-px blast. |
| Fault Breaker | Short-range structure breaker; inefficient against heavy mobile armor. |
| Diamond Custodian | Slow ward-bearing frontline; limited damage and exposed flanks. +1.5 armor ward. |
| Memory Mender | Unarmed single-target mobile-unit healer; protect it from raids. 8 HP/s unit healing. |
| Lattice Sculptor | Unarmed structure repair support; cannot repair mobile units or resurrect. 12 HP/s structure repair. |
| Null Lance | Anti-heavy specialist; smaller damage against light targets. 4 armor piercing. |
| Splinter Weaver | Anti-swarm blast platform; armor and dispersed troops reduce its efficiency. 45-px blast. |
| Resonator | Siege engine that directs destructive resonance into enemy defenses. 4 armor piercing; 42-px blast; 177-px minimum range. |
| Echo Mortar | Light indirect-fire area pressure; vulnerable inside its minimum range. 50-px blast; 106.2-px minimum range; 85% movement slow. |
| Glint Spear | Fast heavy raider for workers and structures; weak against heavy defenders. |
| Mass Driver | Heavy-target hunter; slow and inefficient against massed light units. 4 armor piercing. |
| Adamant Colossus | Costly close-range armored anchor; long-range fire and flanks punish it. 32-px blast. |
| Gravity Warden | Support weapons platform using localized gravity effects to disrupt enemy movement. 55% movement slow. |
| Worldshard Cannon | Heavy structure siege with a minimum range; vulnerable to close assaults. 4 armor piercing; 25-px blast; 129.8-px minimum range. |
| Ancestral Nexus | Expensive ward command platform; limited damage for its cost. +2 armor ward. |

| New structure | Role and faction function |
|---|---|
| Far Prism | Forward reconnaissance anchor with 620-pixel vision; low combat durability. Uses 5 power when complete. |
| Splinter Array | Rapid anti-light ground defense; needs power and is vulnerable to siege. 2 armor piercing; 85% movement slow. Uses 12 power when complete. |
| Gravity Bastion | Heavy-target defensive battery; slow shots lose efficiency against swarms. 2 armor piercing; 85% movement slow. Uses 28 power when complete. |
| Lattice Works | Produces mobile workshop specialists, raiders, and disruption platforms. Uses 30 power when complete. |
| Resonance Archive | Produces healers, frontline ward carriers, and command support. Uses 25 power when complete. |
| Monolithic Forge | Produces escorted siege artillery and anti-heavy destruction platforms. Uses 45 power when complete. |
| Starcore Reactor | Advanced power generation; expensive and vulnerable if left unguarded. Supplies 310 power. |
| Stasis Nexus | Stationary faction support; concentrate fire or siege to break its position. 55-px blast; 60% movement slow. Uses 25 power when complete. |

**Playable style — heavy siege:** Crystal Guards and Monoliths have thick armor, high health, and longer weapon range than their Human counterparts. They advance slowly, establish favorable firing positions, and force opponents to respond. Their high prices and long training times keep each loss significant.

**Strengths:** The toughest demo heavy unit, long-reach weapons, and control of contested approaches; gravity disruption slows opponents into piercing firing lanes.

**Weaknesses:** The slowest, most expensive demo heavy forces are difficult to replace. Slow repositioning leaves flanks and distant objectives exposed; mobile opponents can force them to abandon favorable positions.

**Visual direction:** Faceted mineral armor, geometric structures, luminous crystal cores, and visible gravity distortions around specialized weapons.

## Shared design boundaries

- Every faction uses the same resource accounting, construction validation, queue/timer processing, order ownership, and ordinary fog rules. Combat prices, durations, and stats differ only as documented in `docs/DESIGN.md`; every faction uses the same terrain visibility checks without faction-specific concealment or detection.
- All factions retain Command Center, Power Plant, Refinery, Barracks, and Factory with their established functional labels. Each also has eight named faction-specific structures: forward observation, light/heavy defense, workshop/sanctum/arsenal production, advanced power, and positional support. Their prerequisites and capabilities follow the exact design tables.
- Workers and combat units still require documented production and costs. Spirits, machines, and living organisms do not receive free units or unlimited resources because of their lore.
- No artificial army or population cap applies to any faction.
- Spiritual essence is the shared production resource harvested from regrowing growth around spiritual wells. Preserve the collection, delivery, regrowth, and spending rules recorded in `docs/DESIGN.md`; no other resource systems are established by this catalog.
- Numerical strengths, weaknesses, and ability effects require balance definitions before implementation. Beyond the established Aetherbound arrival portals, this catalog does not establish tactical teleportation, resurrection, permanent enemy conversion, or airborne movement.
