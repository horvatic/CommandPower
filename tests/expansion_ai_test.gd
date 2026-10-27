extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_diagonal_construction()
	_test_earned_expansion_and_varied_production()
	print("%s: %d expansion AI/construction checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _test_diagonal_construction() -> void:
	var world = SIM.new()
	world.configure_skirmish("humans", "heavenly_host")
	world.reset()
	world.ai_enabled = false
	# This exact diagonal trapped the real AI builder outside a valid bastion.
	var worker: Dictionary = world._spawn("worker", 1, Vector2(2533.774, 1529.531))
	worker.order = "gather"
	worker.target = 8
	worker.cargo = 23.0
	var site: Dictionary = world._spawn("bastion", 1, Vector2(2612, 1453), false)
	world._assign_builder(site, int(worker.id))
	world._rebuild_navigation()
	world._rebuild_buckets()
	world._update_fog()
	var approach: Vector2 = world._approach_building(worker, site)
	_check(world._walkable(approach, float(worker.radius)), "A diagonal building approach must remain outside the worker-expanded footprint")
	for step: int in range(900):
		world.tick(SIM.STEP)
		if bool(site.completed): break
	_check(bool(site.completed) and float(site.build_progress) >= 1.0, "The exact diagonal bastion builder must reach construction range and finish through normal simulation")
	_check(str(worker.order) == "gather" and int(worker.target) == 8, "The diagonal builder must automatically resume its previous visible essence patch")
	_check(is_equal_approx(float(worker.cargo), 23.0), "Finishing diagonal construction must preserve the builder's carried essence")

func _test_earned_expansion_and_varied_production() -> void:
	var world = SIM.new()
	world.configure_skirmish("humans", "humans")
	world.reset()
	world.ai_enabled = true
	# Isolate economic planning from the player's unattended defeat. No faction
	# resources, prices, timers, prerequisites, or worker orders are altered.
	world._attack_timer = INF
	_check(int(world.resources[1].essence) == 900, "Expanded AI must begin with the documented 900 essence")
	var producers_used: Dictionary = {}
	var added_kinds: Dictionary = {}
	var complete_buildings: Dictionary = {}
	var support_produced := false
	var heavy_produced := false
	var nonnegative := true
	for second: int in range(600):
		world.tick(1.0)
		nonnegative = nonnegative and int(world.resources[1].essence) >= 0
		for entity: Dictionary in world.entities.values():
			if int(entity.owner) != 1: continue
			var definition: Dictionary = world.entity_spec(entity)
			if bool(definition.building):
				if bool(entity.completed): complete_buildings[str(entity.kind)] = true
				continue
			if DATA.NEW_UNIT_KINDS.has(str(entity.kind)):
				added_kinds[str(entity.kind)] = true
				producers_used[str(DATA.UNIT_PRODUCERS[str(entity.kind)])] = true
				support_produced = support_produced or float(definition.get("heal", 0.0)) > 0.0 or float(definition.get("ward", 0.0)) > 0.0
				heavy_produced = heavy_produced or str(definition.get("class", "")) == "heavy"
			# Ordinary move orders clear exit lanes in this quiet test fixture.
			if str(entity.kind) != "worker" and str(entity.order) == "idle":
				var slot: int = int(entity.id) % 64
				world.order_move([entity.id], Vector2(1800 + float(slot % 8) * 42, 1150 + float(slot / 8) * 42))
		if complete_buildings.size() >= DATA.BUILDING_KINDS.size() and producers_used.size() >= 5 and support_produced and heavy_produced:
			break
	_check(nonnegative, "AI purchases must never spend essence below zero")
	_check(world.match_state == "playing", "The economy fixture must retain both Command Centers")
	for kind: String in DATA.NEW_BUILDING_KINDS:
		_check(complete_buildings.has(kind), "Earned AI economy must complete its new " + kind)
	for kind: String in ["barracks", "factory", "workshop", "sanctum", "arsenal"]:
		_check(producers_used.has(kind), "Repeated early Barracks spending must not starve expanded production from " + kind)
	_check(added_kinds.size() >= 5 and support_produced and heavy_produced, "Expanded AI must field varied new units, protective/restorative support, and heavy specialists")
	var spent := 0
	for entity: Dictionary in world.entities.values():
		if int(entity.owner) != 1: continue
		if int(entity.id) > 16: spent += int(world.entity_spec(entity).cost)
		for item: Dictionary in entity.queue:
			spent += int(item.cost)
	_check(spent > 900, "Expanded construction and units must be funded by real harvested deliveries beyond the original stockpile")
	var electricity: Dictionary = world.power(1)
	_check(int(electricity.produced) >= int(electricity.used), "Expanded AI must provide working power for its completed tech and defensive buildings")
	print("AI_ECONOMY_REGRESSION seconds=", world.elapsed, " new_units=", added_kinds.keys(), " spent=", spent, " remaining_essence=", world.resources[1].essence)
