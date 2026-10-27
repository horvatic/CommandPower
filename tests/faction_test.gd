extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
const ART = preload("res://scripts/faction_sprites.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_matchups()
	_test_production()
	_test_configuration()
	_test_distinct_styles()
	_test_faction_combat_and_movement()
	_test_faction_visibility_and_orders()
	_test_ai_fog_memory()
	print("%s: %d faction checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_matchups() -> void:
	for player: String in DATA.FACTIONS:
		for enemy: String in DATA.FACTIONS:
			var world = SIM.new()
			_check(world.configure_skirmish(player, enemy), "Each faction pairing must be supported")
			world.reset()
			_check(world.entities.size() == 16 and world.match_state == "playing", "Each pairing must retain the documented starting forces")
			_check(int(world.resources[0].essence) == 900 and int(world.resources[1].essence) == 900, "Faction selection must preserve equal starting essence")
			for entity: Dictionary in world.entities.values():
				var expected: String = player if int(entity.owner) == 0 else enemy
				_check(str(entity.faction) == expected and ART.style_for(entity) == expected, "Every starting entity must have its selected faction art")
				_check(is_equal_approx(float(entity.maxhp), float(DATA.spec(str(entity.kind), expected).hp)), "Each starting entity must use its selected faction health")
				_check(world.entity_title(str(entity.kind), int(entity.owner)) == DATA.faction_title(str(entity.kind), expected), "Names must follow the selected faction independently of ownership")

func _test_production() -> void:
	for faction: String in DATA.FACTIONS:
		var world = SIM.new()
		world.ai_enabled = false
		world.configure_skirmish(faction, faction)
		world.reset()
		for owner: int in range(2):
			for kind: String in ["worker", "infantry", "tank"]:
				world.resources[owner]["essence"] = 1000
				var producer: Dictionary = world._spawn(str(DATA.UNIT_PRODUCERS[kind]), owner, Vector2(850, 700 + owner * 400))
				_check(world.queue_unit(int(producer.id), kind), "Each selected side must train all three roles")
				var definition: Dictionary = world.spec_for(kind, owner)
				_check(int(world.resources[owner].essence) == 1000 - int(definition.cost), "Each faction must pay its own unit cost exactly once")
				_check(is_equal_approx(float(producer.queue[0].remaining), float(definition.time)), "Each faction must queue its own train duration")
				_check(world.cancel_queue(int(producer.id)) and int(world.resources[owner].essence) == 1000, "Cancellation must refund the exact faction cost")
				world.resources[owner]["essence"] = int(definition.cost) - 1
				_check(not world.queue_unit(int(producer.id), kind) and producer.queue.is_empty() and int(world.resources[owner].essence) == int(definition.cost) - 1, "Unaffordable faction units must leave resources and queues unchanged")
				world.resources[owner]["essence"] = 1000
				world.queue_unit(int(producer.id), kind)
				var last_id: int = int(world._next_id)
				world._produce(producer, float(definition.time) - 0.1)
				_check(not world.entities.has(last_id) and producer.queue.size() == 1, "Faction production must not finish before its documented timer")
				world._produce(producer, 100.0)
				_check(producer.queue.is_empty() and world.entities.has(last_id), "Completed production must spawn its unit at an exit")
				if world.entities.has(last_id):
					_check(str(world.entities[last_id].faction) == faction and int(world.entities[last_id].owner) == owner, "Produced units must inherit the selected faction and owner")
				world.entities.erase(int(producer.id))
				world.entities.erase(last_id)
			world._rebuild_buckets()
			var built: Dictionary = world._spawn("barracks", owner, Vector2(850, 700 + owner * 400), false)
			_check(str(built.faction) == faction and not bool(built.completed), "Incomplete structures must retain their selected faction")

func _test_configuration() -> void:
	var world = SIM.new()
	_check(world.player_factions == ["humans", "iron_synod"], "Default matchup must remain Human versus Synod")
	_check(DATA.title("worker") == "Prospector" and DATA.title("tank", 1) == "Chimera Tank", "Legacy names must retain their default behavior")
	_check(world.configure_skirmish("heavenly_host", "infernal_legion"), "Rival Aetherbound sides must be separately selectable")
	_check(not world.configure_skirmish("unknown", "humans") and not world.configure_skirmish("humans", "unknown"), "Invalid faction selection must be rejected")
	_check(world.player_factions == ["heavenly_host", "infernal_legion"], "Invalid selection must preserve both previous choices")
	world.set_ai_difficulty("hard")
	world.reset()
	_check(world.player_factions == ["heavenly_host", "infernal_legion"] and world.ai_difficulty == "hard", "Restart must retain the chosen factions and difficulty")
	for faction: String in DATA.FACTIONS:
		_check(ART.STYLES.has(faction) and DATA.FACTION_NAMES.has(faction), "Every playable faction must have art and a display name")
		for kind: String in DATA.UNIT_PRODUCERS:
			_check(not DATA.faction_title(kind, faction).is_empty(), "Every faction must name its trainable units")

func _combat_world(player: String, enemy: String) -> Variant:
	var world: Variant = SIM.new()
	world.configure_skirmish(player, enemy)
	world.reset()
	world.ai_enabled = false
	for id: int in world.entities.keys():
		if str(world.entities[id].kind) != "hq":
			world.entities.erase(id)
	world._rebuild_buckets()
	world._update_fog()
	return world

func _test_distinct_styles() -> void:
	var human: Dictionary = DATA.spec("infantry", "humans")
	var human_tank: Dictionary = DATA.spec("tank", "humans")
	_check(human.hp == 110.0 and human.cost == 80 and human.time == 8.0 and human_tank.hp == 420.0, "Humans must retain the established combined-arms baseline")
	var synod: Dictionary = DATA.spec("infantry", "iron_synod")
	_check(synod.hp > human.hp and synod.armor > human.armor and synod.cooldown < human.cooldown and synod.damage < human.damage and synod.cost > human.cost, "Synod must favor resilient, costly sustained-fire units whose small shots are blunted by armor")
	var brood: Dictionary = DATA.spec("infantry", "kharuun")
	_check(brood.cost < human.cost and brood.time < human.time and brood.hp < human.hp and brood.damage < human.damage, "Kharuun must produce numerous cheaper, individually weaker frontline units")
	var heaven: Dictionary = DATA.spec("infantry", "heavenly_host")
	_check(heaven.hp > human.hp and heaven.armor > human.armor and heaven.cost > human.cost and heaven.speed < human.speed and heaven.range <= human.range, "Heavenly Host must trade mobility and reach for expensive defensive durability")
	var infernal: Dictionary = DATA.spec("infantry", "infernal_legion")
	_check(infernal.speed > human.speed and infernal.range < human.range and infernal.hp < human.hp and infernal.damage / infernal.cooldown > human.damage / human.cooldown, "Infernal Legion must favor fast, fragile, close-range assaults")
	var veyr: Dictionary = DATA.spec("tank", "veyr")
	_check(veyr.hp > human_tank.hp and veyr.armor > human_tank.armor and veyr.range > human_tank.range and veyr.speed < human_tank.speed and veyr.cost > human_tank.cost and veyr.time > human_tank.time, "Veyr must pay and wait for slow, durable siege units")
	var profiles: Dictionary = {}
	for faction: String in DATA.FACTIONS:
		var signature: String = ""
		for kind: String in ["infantry", "tank"]:
			var definition: Dictionary = DATA.spec(kind, faction)
			signature += str([definition.hp, definition.cost, definition.time, definition.speed, definition.damage, definition.range, definition.cooldown, definition.armor])
		profiles[signature] = true
		for kind: String in ["worker", "hq", "power", "refinery", "barracks", "factory"]:
			_check(DATA.spec(kind, faction) == DATA.spec(kind), "Faction combat identities must preserve worker economy and buildings")
	_check(profiles.size() == DATA.FACTIONS.size(), "Every selectable side must have a distinct gameplay profile")

func _test_faction_combat_and_movement() -> void:
	for faction: String in DATA.FACTIONS:
		var world: Variant = _combat_world(faction, faction)
		for kind: String in ["infantry", "tank"]:
			var definition: Dictionary = DATA.spec(kind, faction)
			var observed_damage: Array[float] = []
			for owner: int in range(2):
				var attacker: Dictionary = world._spawn(kind, owner, Vector2(900, 600))
				var target: Dictionary = world._spawn("tank", 1 - owner, Vector2(990, 600))
				attacker.order = "hold"
				target.order = "move"
				world._rebuild_buckets()
				world._update_fog()
				_check(attacker.hp == definition.hp and attacker.maxhp == definition.hp, "Both owners must spawn the same faction's actual combat HP")
				var before: float = target.hp
				world._combat_unit(attacker, SIM.STEP)
				var dealt: float = before - float(target.hp)
				observed_damage.append(dealt)
				_check(is_equal_approx(dealt, maxf(1.0, float(definition.damage) - float(DATA.spec("tank", faction).armor))), "Real shots must apply the attacker's faction damage and target's faction armor")
				_check(is_equal_approx(float(attacker.cooldown_left), float(definition.cooldown)), "Real shots must use the firing faction's cooldown")
				world.entities.erase(int(target.id))
				attacker.cooldown_left = 0.0
				attacker.order = "hold"
				attacker.target = -1
				var limit: float = float(definition.range) + 17.0
				target = world._spawn("tank", 1 - owner, Vector2(attacker.pos) + Vector2(limit + 10.0, 0))
				world._rebuild_buckets()
				world._update_fog()
				before = target.hp
				world._combat_unit(attacker, SIM.STEP)
				_check(target.hp == before, "Holding combat units must not fire outside their faction range")
				target.pos = Vector2(attacker.pos) + Vector2(float(definition.range) - 1.0, 0)
				world._rebuild_buckets()
				world._update_fog()
				world._combat_unit(attacker, SIM.STEP)
				_check(target.hp < before, "Holding combat units must fire within their faction range")
				world.entities.erase(int(target.id))
				world._rebuild_buckets()
				var start: Vector2 = attacker.pos
				world._move_towards(attacker, start + Vector2(200, 0), SIM.STEP)
				_check(absf(Vector2(attacker.pos).distance_to(start) - float(definition.speed) * SIM.STEP) < 0.001, "Actual navigation must use the selected faction's movement speed")
				world.entities.erase(int(attacker.id))
			world._rebuild_buckets()
			_check(observed_damage[0] == observed_damage[1], "Mirrored faction weapons must deal the same damage for player and AI")

func _test_faction_visibility_and_orders() -> void:
	for faction: String in DATA.FACTIONS:
		for owner: int in range(2):
			var world: Variant = _combat_world("humans" if owner == 0 else faction, faction if owner == 0 else "humans")
			var observer: Dictionary = world._spawn("tank", owner, Vector2(900, 600))
			var enemy: Dictionary = world._spawn("tank", 1 - owner, Vector2(1100, 600))
			world._rebuild_buckets()
			world._update_fog()
			_check(world.is_visible(owner, enemy.pos) and world.can_see_entity(owner, enemy), "Every faction must be visible on observed terrain before firing, even beyond close range")
			_check(world.can_see_entity(1 - owner, enemy), "Owners must always see their own units")
			_check(world._find_enemy(observer, 300.0) == int(enemy.id), "Automatic targeting must acquire any faction on visible terrain")
			world.order_attack([int(observer.id)], int(enemy.id))
			_check(str(observer.order) == "attack" and int(observer.target) == int(enemy.id), "Visible units of every faction must accept direct attack orders")
			var hp: float = enemy.hp
			world._combat_unit(observer, SIM.STEP)
			_check(enemy.hp < hp, "Visible targets in weapon range must take ordinary weapon damage")
			var last_seen: Vector2 = observer.goal
			enemy.pos = Vector2(1800, 600)
			world._rebuild_buckets()
			world._update_fog()
			_check(not world.can_see_entity(owner, enemy) and world._find_enemy(observer, 1000.0) == -1, "Terrain fog must hide every faction from visibility and automatic targeting")
			world._combat_unit(observer, SIM.STEP)
			_check(int(observer.target) == -1 and str(observer.order) == "attack_move" and Vector2(observer.goal) == last_seen, "Losing terrain vision must preserve the last observed attack position without tracking hidden movement")
			world.order_stop([int(observer.id)])
			world.order_attack([int(observer.id)], int(enemy.id))
			_check(str(observer.order) == "idle" and int(observer.target) == -1, "New direct attacks must reject targets hidden by fog")
			enemy.pos = Vector2(1050, 600)
			enemy.order = "hold"
			world._rebuild_buckets()
			world._update_fog()
			hp = observer.hp
			world._combat_unit(enemy, SIM.STEP)
			_check(observer.hp < hp and world.can_see_entity(owner, enemy), "Actual firing must retain normal terrain visibility for every faction")
			enemy.order = "hold"
			enemy.cooldown_left = 999.0
			observer.order = "hold"
			observer.cooldown_left = 999.0
			world.tick(4.0)
			_check(world.can_see_entity(owner, enemy), "A unit that stops firing must stay visible while its terrain remains observed")

func _test_ai_fog_memory() -> void:
	for faction: String in DATA.FACTIONS:
		var world: Variant = _combat_world(faction, "humans")
		var player: Dictionary = world._spawn("infantry", 0, Vector2(1500, 600))
		world._spawn("worker", 1, Vector2(900, 600))
		world._rebuild_buckets()
		world._update_fog()
		world._ai_tick()
		_check(not world._ai_enemy_memory.has(int(player.id)), "AI memory must not learn any faction's current positions through fog")
		player.pos = Vector2(1100, 600)
		world._rebuild_buckets()
		world._update_fog()
		world._ai_tick()
		_check(world._ai_enemy_memory.has(int(player.id)), "AI may remember any faction observed on currently visible terrain")
		var remembered: Vector2 = world._ai_enemy_memory[int(player.id)].pos
		player.pos = Vector2(1500, 600)
		world._rebuild_buckets()
		world._update_fog()
		world._ai_tick()
		_check(Vector2(world._ai_enemy_memory[int(player.id)].pos) == remembered, "AI memory must retain the last observed position after a unit returns to fog")
