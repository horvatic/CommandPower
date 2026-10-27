extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")

const PREVIOUS_RANGES := {
	"humans": {
		"artillery": 430.0,
		"mortar": 305.0,
		"siege_tank": 375.0,
		"sentry": 240.0,
		"bastion": 320.0
	},
	"iron_synod": {
		"artillery": 417.1,
		"mortar": 295.8,
		"siege_tank": 363.8,
		"sentry": 232.8,
		"bastion": 310.4
	},
	"kharuun": {
		"artillery": 391.3,
		"mortar": 277.6,
		"siege_tank": 341.2,
		"sentry": 228.0,
		"bastion": 304.0
	},
	"heavenly_host": {
		"artillery": 415.4,
		"mortar": 294.6,
		"siege_tank": 362.2,
		"sentry": 228.0,
		"bastion": 304.0
	},
	"infernal_legion": {
		"artillery": 344.0,
		"mortar": 244.0,
		"siege_tank": 300.0,
		"sentry": 211.2,
		"bastion": 281.6
	},
	"veyr": {
		"artillery": 507.4,
		"mortar": 359.9,
		"siege_tank": 442.5,
		"sentry": 288.0,
		"bastion": 384.0,
		"relay": 280.0
	}
}

var checks := 0
var failures := 0

func _initialize() -> void:
	_test_roster_and_production()
	_test_building_prerequisites()
	_test_support_targeting()
	_test_wards_and_power()
	_test_damage_and_splash()
	_test_regeneration_and_drain()
	_test_slow_expiry_and_pause()
	_test_turrets_and_support_orders()
	_test_turret_range_boundary()
	_test_improved_range_boundaries()
	print("%s: %d expansion gameplay checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _fresh(player: String = "humans", enemy: String = "humans") -> Variant:
	var world: Variant = SIM.new()
	world.configure_skirmish(player, enemy)
	world.reset()
	world.ai_enabled = false
	for id: int in world.entities.keys():
		if str(world.entities[id].kind) != "hq":
			world.entities.erase(id)
	world._spawn("power", 0, Vector2(320, 480))
	world._spawn("power", 1, Vector2(2752, 1568))
	world.resources[0]["essence"] = 10000
	world.resources[1]["essence"] = 10000
	world._rebuild_navigation()
	_observe(world)
	return world

func _observe(world: Variant) -> void:
	world._rebuild_buckets()
	world._update_fog()

func _find(world: Variant, owner: int, kind: String) -> Dictionary:
	for e: Dictionary in world.entities.values():
		if int(e.owner) == owner and str(e.kind) == kind:
			return e
	return {}

func _test_roster_and_production() -> void:
	_check(DATA.UNIT_KINDS.size() == 21 and DATA.NEW_UNIT_KINDS.size() == 18, "Every side must retain its three units and add eighteen more")
	_check(DATA.BUILDING_KINDS.size() == 13 and DATA.NEW_BUILDING_KINDS.size() == 8, "Every side must retain five structures and add eight more")
	var unique_units: Dictionary = {}
	var unique_buildings: Dictionary = {}
	for faction: String in DATA.FACTIONS:
		_check(DATA.FACTION_UNITS[faction].size() == 21 and DATA.FACTION_BUILDINGS[faction].size() == 8, "Every selectable side needs a complete named expanded roster")
		for kind: String in DATA.NEW_UNIT_KINDS:
			var definition: Dictionary = DATA.spec(kind, faction)
			var name: String = DATA.faction_title(kind, faction)
			_check(not unique_units.has(name) and name != kind.capitalize(), "New units need distinct faction names, including the two separate hosts")
			unique_units[name] = true
			_check(float(definition.hp) > 0 and int(definition.cost) > 0 and float(definition.time) > 0 and float(definition.speed) > 0 and not bool(definition.building), "Each expanded unit must have paid, timed, ground-mobile production values")
			_check(DATA.BUILDING_KINDS.has(str(DATA.UNIT_PRODUCERS[kind])), "Each expanded unit needs an existing production role")
			var world: Variant = _fresh(faction, faction)
			var producer: Dictionary = world._spawn(str(DATA.UNIT_PRODUCERS[kind]), 0, Vector2(900, 600))
			var technology: Array[int] = []
			for requirement: String in DATA.requirements(kind, faction):
				_check(not world.can_produce(int(producer.id), kind), "Missing additional technology must block production before charging")
				var before: int = int(world.resources[0].essence)
				_check(not world.queue_unit(int(producer.id), kind) and int(world.resources[0].essence) == before, "Rejected technology orders must leave essence unchanged")
				var tech: Dictionary = world._spawn(requirement, 0, Vector2(600, 750 + technology.size() * 150))
				technology.append(int(tech.id))
			_check(world.can_produce(int(producer.id), kind), "Completed producer and technology must unlock a new unit")
			var funds: int = int(world.resources[0].essence)
			_check(world.queue_unit(int(producer.id), kind) and int(world.resources[0].essence) == funds - int(definition.cost), "New units must charge their actual faction price once")
			_check(is_equal_approx(float(producer.queue[0].remaining), float(definition.time)), "New unit queues must use the faction training timer")
			_check(world.cancel_queue(int(producer.id)) and int(world.resources[0].essence) == funds, "Cancellation must refund exactly the price paid for a new unit")
			world.queue_unit(int(producer.id), kind)
			for id: int in technology:
				world.entities.erase(id)
			var spawn_id: int = world._next_id
			world._produce(producer, float(definition.time) * 3.0)
			_check(producer.queue.is_empty() and world.entities.has(spawn_id), "Paid orders must complete even when separate technology is later lost")
			if world.entities.has(spawn_id):
				var unit: Dictionary = world.entities[spawn_id]
				_check(str(unit.faction) == faction and unit.maxhp == definition.hp and int(unit.owner) == 0, "Newly trained units must inherit their faction, owner and actual HP")
		for kind: String in DATA.NEW_BUILDING_KINDS:
			var definition: Dictionary = DATA.spec(kind, faction)
			var name: String = DATA.faction_title(kind, faction)
			_check(not unique_buildings.has(name) and name != kind.capitalize(), "New structures need distinct faction names")
			unique_buildings[name] = true
			_check(bool(definition.building) and Vector2(definition.size).x > 0 and Vector2(definition.size).y > 0 and int(definition.cost) > 0, "Every expanded structure needs a paid real footprint")
	_check(unique_units.size() == 108 and unique_buildings.size() == 48, "The expansion must supply all 108 new unit identities and 48 new structure identities")

func _test_building_prerequisites() -> void:
	for faction: String in DATA.FACTIONS:
		for kind: String in DATA.NEW_BUILDING_KINDS:
			var world: Variant = _fresh(faction, faction)
			world._spawn("worker", 0, Vector2(600, 350))
			var site := Vector2(800, 350)
			_observe(world)
			# Reveal the valid site with a temporary scout rather than overwriting fog state.
			var scout: Dictionary = world._spawn("scout", 0, Vector2(620, 350))
			_observe(world)
			_check(not world.can_build(0, kind, site), "An expanded building must require its documented completed technology")
			var requirement: String = str(DATA.requirements(kind, faction)[0])
			var tech: Dictionary = world._spawn(requirement, 1, Vector2(400, 650))
			_check(not world.can_build(0, kind, site), "Enemy technology must never unlock player construction")
			tech.owner = 0
			tech.completed = false
			_check(not world.can_build(0, kind, site), "Incomplete technology must never unlock construction")
			tech.completed = true
			tech.hp = 0.0
			_check(not world.can_build(0, kind, site), "Destroyed technology must never unlock construction")
			tech.hp = tech.maxhp
			_check(world.can_build(0, kind, site), "Completed friendly technology must unlock an otherwise valid expanded site")
			var before: int = int(world.resources[0].essence)
			_check(world.start_build(0, kind, site) and int(world.resources[0].essence) == before - int(world.spec_for(kind, 0).cost), "Accepted expanded construction must charge its faction price exactly once")
			_check(float(scout.hp) > 0, "Building validation must preserve nearby units")

func _test_support_targeting() -> void:
	var world: Variant = _fresh()
	var medic: Dictionary = world._spawn("medic", 0, Vector2(900, 600))
	var light: Dictionary = world._spawn("infantry", 0, Vector2(920, 600))
	var heavy: Dictionary = world._spawn("tank", 0, Vector2(940, 600))
	var building: Dictionary = world._spawn("power", 0, Vector2(960, 600))
	var dead: Dictionary = world._spawn("infantry", 0, Vector2(980, 600))
	var incomplete: Dictionary = world._spawn("infantry", 0, Vector2(980, 620), false)
	var enemy: Dictionary = world._spawn("infantry", 1, Vector2(960, 620))
	medic.hp = 1.0
	light.hp = 10.0
	heavy.hp = 20.0
	building.hp = 1.0
	dead.hp = 0.0
	incomplete.hp = 1.0
	enemy.hp = 1.0
	_observe(world)
	world._support(medic, 1.0)
	_check(is_equal_approx(float(heavy.hp), 20.0 + float(world.entity_spec(medic).heal)) and light.hp == 10.0, "Healers must choose the lowest HP fraction, not lowest absolute HP, and heal one ally")
	_check(building.hp == 1.0 and dead.hp == 0.0 and incomplete.hp == 1.0 and enemy.hp == 1.0 and medic.hp == 1.0, "Unit healing must exclude buildings, dead/incomplete targets, enemies and self")
	heavy.hp = heavy.maxhp
	light.hp = float(light.maxhp) - 1.0
	world._support(medic, 10.0)
	_check(light.hp == light.maxhp, "Healing must cap HP at the target maximum")
	var mechanic: Dictionary = world._spawn("mechanic", 0, Vector2(900, 900))
	var repair_target: Dictionary = world._spawn("power", 0, Vector2(920, 900))
	var mobile: Dictionary = world._spawn("infantry", 0, Vector2(940, 900))
	repair_target.hp = 10.0
	mobile.hp = 1.0
	_observe(world)
	world._support(mechanic, 1.0)
	_check(is_equal_approx(float(repair_target.hp), 10.0 + float(world.entity_spec(mechanic).heal)) and mobile.hp == 1.0, "Repair support must restore structures and exclude mobile allies")

func _test_wards_and_power() -> void:
	var world: Variant = _fresh("heavenly_host", "humans")
	var target: Dictionary = world._spawn("infantry", 0, Vector2(900, 600))
	var guardian: Dictionary = world._spawn("guardian", 0, Vector2(930, 600))
	var commander: Dictionary = world._spawn("commander", 0, Vector2(960, 600))
	_observe(world)
	var strongest: float = maxf(float(world.entity_spec(guardian).ward), float(world.entity_spec(commander).ward))
	_check(world._ward_armor(target) == strongest, "Multiple wards must use the strongest emitter instead of stacking")
	_check(world._ward_armor(guardian) == strongest, "A ward emitter must benefit from its own field")
	guardian.hp = 0.0
	commander.completed = false
	_check(world._ward_armor(target) == 0.0, "Dead or incomplete ward emitters must be inactive")
	world.entities.erase(int(guardian.id))
	world.entities.erase(int(commander.id))
	var relay: Dictionary = world._spawn("relay", 0, Vector2(960, 600))
	_observe(world)
	_check(world._ward_armor(target) == float(world.entity_spec(relay).ward), "A powered faction relay must project its ward")
	_find(world, 0, "power").hp = 0.0
	_check(world._ward_armor(target) == 0.0, "Low power must switch off stationary support wards")
	var support_world: Variant = _fresh("kharuun", "humans")
	var healer: Dictionary = support_world._spawn("relay", 0, Vector2(900, 600))
	var wounded: Dictionary = support_world._spawn("infantry", 0, Vector2(960, 600))
	wounded.hp = 10.0
	wounded.order = "hold"
	_find(support_world, 0, "power").hp = 0.0
	_observe(support_world)
	support_world.tick(SIM.STEP)
	_check(wounded.hp == 10.0, "Low-power stationary healing must be suppressed by the real simulation tick")
	support_world._spawn("medic", 0, Vector2(960, 620))
	_observe(support_world)
	support_world.tick(SIM.STEP)
	_check(wounded.hp > 10.0 and not support_world._ability_active(healer), "Mobile healing must remain active during low power while the relay stays disabled")

func _test_damage_and_splash() -> void:
	var world: Variant = _fresh("humans", "heavenly_host")
	var lancer: Dictionary = world._spawn("lancer", 0, Vector2(900, 600))
	var target: Dictionary = world._spawn("tank", 1, Vector2(1050, 600))
	world._spawn("guardian", 1, Vector2(1080, 600))
	_observe(world)
	var attack: Dictionary = world.entity_spec(lancer)
	var defense: Dictionary = world.entity_spec(target)
	var expected: float = maxf(1.0, float(attack.damage) * float(attack.bonuses.heavy) - maxf(0.0, float(defense.armor) + world._ward_armor(target) - float(attack.pierce)))
	var before: float = target.hp
	world._hit(lancer, target)
	_check(is_equal_approx(before - float(target.hp), expected), "Actual hits must multiply class bonuses before subtracting warded armor and piercing")
	var splash_world: Variant = _fresh()
	var mortar: Dictionary = splash_world._spawn("mortar", 0, Vector2(900, 600))
	var primary: Dictionary = splash_world._spawn("infantry", 1, Vector2(960, 600))
	mortar.order = "hold"
	primary.order = "hold"
	_observe(splash_world)
	before = primary.hp
	splash_world._combat_unit(mortar, SIM.STEP)
	_check(primary.hp == before and mortar.cooldown_left == 0.0, "Minimum-range weapons must not shoot targets inside their dead zone")
	primary.pos = Vector2(1100, 600)
	var secondary: Dictionary = splash_world._spawn("infantry", 1, Vector2(1120, 600))
	var friendly: Dictionary = splash_world._spawn("infantry", 0, Vector2(1105, 620))
	var hidden: Dictionary = splash_world._spawn("infantry", 1, Vector2(1100, 645))
	_observe(splash_world)
	splash_world.visible[0].erase(splash_world._cell(hidden.pos))
	var secondary_before: float = secondary.hp
	var friendly_before: float = friendly.hp
	var hidden_before: float = hidden.hp
	splash_world._combat_unit(mortar, SIM.STEP)
	_check(primary.hp < before and is_equal_approx(secondary_before - float(secondary.hp), splash_world.damage_for(mortar, secondary)), "A real area shot must hit visible hostile neighbors with their own damage calculation")
	_check(friendly.hp == friendly_before and hidden.hp == hidden_before, "Splash must never damage friendly or fog-hidden neighbors")

func _test_regeneration_and_drain() -> void:
	var world: Variant = _fresh("iron_synod", "infernal_legion")
	var regenerator: Dictionary = world._spawn("skirmisher", 0, Vector2(900, 600))
	regenerator.hp = float(regenerator.maxhp) - 50.0
	regenerator.last_damage_at = 0.0
	var before: float = regenerator.hp
	world.elapsed = 2.99
	world._regenerate(regenerator, 1.0)
	_check(regenerator.hp == before, "Regeneration must wait three full simulation seconds after damage")
	world.elapsed = 3.0
	world._regenerate(regenerator, 1.0)
	_check(is_equal_approx(float(regenerator.hp), before + float(world.entity_spec(regenerator).regen)), "Regeneration must restore its defined HP per simulation second")
	regenerator.hp = float(regenerator.maxhp) - 0.1
	world._regenerate(regenerator, 10.0)
	_check(regenerator.hp == regenerator.maxhp, "Regeneration must cap at max HP")
	regenerator.hp = 0.0
	world._regenerate(regenerator, 10.0)
	_check(regenerator.hp == 0.0, "Regeneration must never resurrect a dead unit")
	regenerator.hp = 1.0
	regenerator.completed = false
	world._regenerate(regenerator, 10.0)
	_check(regenerator.hp == 1.0, "Incomplete entities must not regenerate")
	var drainer: Dictionary = world._spawn("shock", 1, Vector2(940, 600))
	var victim: Dictionary = world._spawn("infantry", 0, Vector2(960, 600))
	drainer.hp = float(drainer.maxhp) - 10.0
	victim.hp = 1.0
	_observe(world)
	before = drainer.hp
	world._hit(drainer, victim)
	_check(is_equal_approx(float(drainer.hp), before + float(world.entity_spec(drainer).lifesteal)), "Overkill drain must use only the victim's actual one remaining HP")
	before = drainer.hp
	world._hit(drainer, victim)
	_check(drainer.hp == before, "Already dead targets must provide no drain healing")
	victim.hp = 1.0
	drainer.hp = float(drainer.maxhp) - 0.01
	world._hit(drainer, victim)
	_check(drainer.hp == drainer.maxhp, "Drain healing must cap at the attacker's maximum HP")

func _test_slow_expiry_and_pause() -> void:
	var world: Variant = _fresh("veyr", "humans")
	var strong: Dictionary = world._spawn("disruptor", 0, Vector2(900, 600))
	var weak: Dictionary = world._spawn("mortar", 0, Vector2(920, 600))
	var target: Dictionary = world._spawn("juggernaut", 1, Vector2(1040, 600))
	_observe(world)
	world._hit(strong, target)
	_check(world._movement_factor(target) == float(world.entity_spec(strong).slow), "Disruption fire must apply the defined movement multiplier")
	var elapsed_before: float = world.elapsed
	world.tick(0.0)
	_check(world.elapsed == elapsed_before and world._movement_factor(target) == float(world.entity_spec(strong).slow), "A paused simulation must freeze active slow expiry")
	world.elapsed = 2.0
	world._hit(weak, target)
	_check(world._movement_factor(target) == float(world.entity_spec(strong).slow), "A weaker slow must never multiply with or replace a stronger active slow")
	world.elapsed = 2.6
	_check(world._movement_factor(target) == float(world.entity_spec(weak).slow), "A longer weaker effect must remain after a stronger slow expires")
	world.elapsed = 3.3
	_check(world._movement_factor(target) == 1.0 and target.slows.is_empty(), "All slowing effects must expire independently and restore normal movement")
	var building: Dictionary = world._spawn("power", 1, Vector2(1050, 620))
	_observe(world)
	world._hit(strong, building)
	_check(building.slows.is_empty(), "Ground movement debuffs must not add meaningless slow state to buildings")

func _test_turrets_and_support_orders() -> void:
	var world: Variant = _fresh()
	var turret: Dictionary = world._spawn("sentry", 0, Vector2(900, 600))
	var enemy: Dictionary = world._spawn("infantry", 1, Vector2(1050, 600))
	enemy.order = "hold"
	enemy.cooldown_left = 999.0
	_observe(world)
	var before: float = enemy.hp
	world.tick(SIM.STEP)
	_check(enemy.hp < before and turret.cooldown_left > 0.0, "A completed powered defensive building must fire through the real simulation tick")
	_find(world, 0, "power").hp = 0.0
	world._spawn("factory", 0, Vector2(1000, 900))
	turret.cooldown_left = 0.0
	before = enemy.hp
	world.tick(SIM.STEP)
	_check(enemy.hp == before and not world._ability_active(turret), "A power shortage must disable defensive building weapons")
	var support_world: Variant = _fresh("heavenly_host", "humans")
	var support: Dictionary = support_world._spawn("medic", 0, Vector2(900, 600))
	var ally: Dictionary = support_world._spawn("infantry", 0, Vector2(1090, 600))
	ally.hp = 50.0
	support_world._spawn("infantry", 1, Vector2(1240, 600))
	_observe(support_world)
	support_world.order_move([support.id], Vector2(1250, 600), true)
	var position_before: Vector2 = support.pos
	support_world._combat_unit(support, SIM.STEP)
	_check(Vector2(support.pos).distance_to(position_before) > 0.0, "Unarmed support must keep advancing when its injured ally is 190 pixels away outside its 170-pixel healing range")
	ally.pos = Vector2(support.pos) + Vector2(160, 0)
	_observe(support_world)
	position_before = support.pos
	support_world._combat_unit(support, SIM.STEP)
	_check(Vector2(support.pos) == position_before, "Attack-moving support must stop only when a wounded eligible ally is actually inside healing range")
	support_world._support(support, 1.0)
	_check(float(ally.hp) > 50.0, "A support unit that stops inside range must actually restore its wounded ally")
	support_world.order_move([support.id], Vector2(1250, 600))
	support_world._combat_unit(support, SIM.STEP)
	_check(Vector2(support.pos).distance_to(position_before) > 0.0, "A direct move must still reposition unarmed support while a wounded ally is in healing range")

func _test_turret_range_boundary() -> void:
	var world: Variant = _fresh()
	var turret: Dictionary = world._spawn("sentry", 0, Vector2(900, 600))
	var definition: Dictionary = world.entity_spec(turret)
	var enemy: Dictionary = world._spawn("tank", 1, Vector2(900.0 + float(definition.range) + 16.0, 600))
	world._spawn("outpost", 0, Vector2(enemy.pos) + Vector2(0, 180))
	enemy.order = "hold"
	enemy.cooldown_left = 999.0
	_observe(world)
	var before: float = enemy.hp
	world.tick(SIM.STEP)
	_check(enemy.hp < before, "Turrets must automatically acquire a target whose body is inside weapon range even when its center lies beyond range")
	enemy.pos = Vector2(900.0 + float(definition.range) + float(enemy.radius) + 1.0, 600)
	turret.cooldown_left = 0.0
	_observe(world)
	before = enemy.hp
	world._combat_unit(turret, SIM.STEP)
	_check(enemy.hp == before, "Turrets must reject target bodies beyond the documented range plus radius")

func _test_improved_range_boundaries() -> void:
	for faction: String in PREVIOUS_RANGES:
		for owner: int in range(2):
			for kind: String in PREVIOUS_RANGES[faction]:
				var world: Variant = _fresh(faction, faction)
				var attacker: Dictionary = world._spawn(kind, owner, Vector2(900, 600))
				var definition: Dictionary = world.entity_spec(attacker)
				var old_range: float = float(PREVIOUS_RANGES[faction][kind])
				var reach: float = float(definition.range)
				var label := "%s %s owner %d" % [faction, kind, owner]
				_check(reach > old_range, "Requested defensive and artillery reach must increase: " + label)
				var enemy: Dictionary = world._spawn("tank", 1 - owner, Vector2.ZERO)
				enemy.pos = Vector2(attacker.pos) + Vector2((old_range + reach) * .5 + float(enemy.radius), 0)
				var spotter: Dictionary = world._spawn("outpost", owner, Vector2(enemy.pos) + Vector2(0, 180))
				attacker.order = "hold"
				enemy.order = "hold"
				enemy.cooldown_left = 999.0
				_observe(world)
				var before: float = enemy.hp
				world.tick(SIM.STEP)
				_check(enemy.hp < before and attacker.cooldown_left > 0.0, "Powered defenses and held artillery must acquire and fire into newly gained range with a spotter: " + label)
				attacker.cooldown_left = 0.0
				attacker.target = -1
				enemy.hp = enemy.maxhp
				enemy.pos = Vector2(attacker.pos) + Vector2(reach + float(enemy.radius) + 1.0, 0)
				spotter.pos = Vector2(enemy.pos) + Vector2(0, 180)
				_observe(world)
				world._combat_unit(attacker, SIM.STEP)
				_check(enemy.hp == enemy.maxhp and attacker.cooldown_left == 0.0, "Target bodies beyond improved weapon reach must remain unharmed: " + label)
				attacker.target = -1
				enemy.pos = Vector2(attacker.pos) + Vector2((old_range + reach) * .5 + float(enemy.radius), 0)
				_observe(world)
				world.visible[owner].clear()
				world._combat_unit(attacker, SIM.STEP)
				_check(enemy.hp == enemy.maxhp and attacker.cooldown_left == 0.0, "Improved reach must not acquire targets hidden by fog: " + label)
				if float(definition.get("min_range", 0.0)) > 0.0:
					attacker.target = -1
					enemy.pos = Vector2(attacker.pos) + Vector2(float(definition.min_range) - 1.0, 0)
					_observe(world)
					world._combat_unit(attacker, SIM.STEP)
					_check(enemy.hp == enemy.maxhp and attacker.cooldown_left == 0.0, "Longer-range artillery must retain its close-range dead zone: " + label)
