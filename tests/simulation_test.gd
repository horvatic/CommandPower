extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_economy_delivery()
	_test_regrowth_and_time()
	_test_spending_and_production()
	_test_construction_and_power()
	_test_building_power_accounting()
	_test_producer_is_only_unit_prerequisite()
	_test_builders_resume_real_harvesting()
	_test_builder_patch_fallback_and_cargo()
	_test_replacement_builder_harvesting()
	_test_interrupted_builder_keeps_move()
	_test_blocked_exit()
	_test_ownership_and_visibility()
	_test_ai_information_boundary()
	_test_combat_and_end_state()
	_test_destruction_effects()
	_test_owner_health_and_damage_parity()
	_test_ai_difficulty_selection()
	_test_ai_decision_and_worker_profiles()
	_test_ai_attack_profiles()
	_test_difficulty_preserves_fair_rules()
	if failures == 0:
		print("PASS: %d simulation checks" % checks)
	else:
		push_error("FAIL: %d of %d simulation checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _fresh() -> Variant:
	var world: Variant = SIM.new()
	# Shared-rule regressions use matching Human armies; faction asymmetry is covered separately.
	world.configure_skirmish("humans", "humans")
	world.reset()
	world.ai_enabled = false
	for owner: int in range(2):
		var workers: Array = []
		for e: Dictionary in world.entities.values():
			if int(e.owner) == owner and str(e.kind) == "worker":
				workers.append(int(e.id))
		world.order_stop(workers, true)
	return world

func _find(world: Variant, owner: int, kind: String) -> Dictionary:
	for e: Dictionary in world.entities.values():
		if int(e.owner) == owner and str(e.kind) == kind:
			return e
	return {}

func _advance(world: Variant, seconds: float) -> void:
	for index: int in range(int(round(seconds / 0.05))):
		world.tick(0.05)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _count(world: Variant, owner: int, kind: String) -> int:
	var count: int = 0
	for e: Dictionary in world.entities.values():
		if int(e.owner) == owner and str(e.kind) == kind:
			count += 1
	return count

func _test_economy_delivery() -> void:
	var world: Variant = _fresh()
	var worker: Dictionary = _find(world, 0, "worker")
	var patch: Dictionary = world.deposits[0]
	worker["pos"] = Vector2(patch.pos) + Vector2(12, 0)
	world._update_fog()
	world.order_gather([int(worker.id)], int(patch.id))
	var funds: int = int(world.resources[0].essence)
	_advance(world, 1.0)
	_check(float(worker.cargo) > 0.0, "Worker must harvest nearby spiritual essence")
	_check(int(world.resources[0].essence) == funds, "Harvesting must not credit Essence before delivery")
	var refinery: Dictionary = _find(world, 0, "refinery")
	worker["cargo"] = 60.0
	worker["order"] = "return"
	worker["pos"] = Vector2(refinery.pos) + Vector2(65, 0)
	_advance(world, 0.05)
	_check(int(world.resources[0].essence) == funds + 60, "Completed friendly Refinery must credit delivered cargo once")
	_check(float(worker.cargo) < 0.01, "Delivery must remove cargo from the worker")

func _test_regrowth_and_time() -> void:
	var world: Variant = _fresh()
	var patch: Dictionary = world.deposits[0]
	patch["amount"] = 0.0
	_advance(world, 5.0)
	_check(absf(float(patch.amount) - 5.0) < 0.001, "Depleted Essence patches must regrow during simulation")
	patch["amount"] = float(patch.capacity) - 0.1
	_advance(world, 1.0)
	_check(float(patch.amount) <= float(patch.capacity), "Regrowth must stop at patch capacity")
	var a: Variant = _fresh()
	var b: Variant = _fresh()
	a.deposits[0]["amount"] = 0.0
	b.deposits[0]["amount"] = 0.0
	for frame: int in range(120):
		a.tick(1.0 / 60.0)
	for frame: int in range(40):
		b.tick(0.05)
	_check(absf(float(a.elapsed) - float(b.elapsed)) <= 0.051, "Simulation speed must be independent of rendering frame rate")
	_check(absf(float(a.deposits[0].amount) - float(b.deposits[0].amount)) <= 0.051, "Regrowth must be independent of rendering frame rate")

func _test_spending_and_production() -> void:
	var world: Variant = _fresh()
	var hq: Dictionary = _find(world, 0, "hq")
	var funds: int = int(world.resources[0].essence)
	_check(not world.start_build(0, "power", Vector2(-50, -50)), "Out-of-bounds building placement must fail")
	_check(int(world.resources[0].essence) == funds, "Invalid construction must not spend resources")
	_check(not world.queue_unit(int(hq.id), "tank"), "Command Center must not produce tanks")
	_check(int(world.resources[0].essence) == funds, "Invalid production must not spend resources")
	_check(world.queue_unit(int(hq.id), "worker"), "Command Center must queue a worker")
	_check(int(world.resources[0].essence) == funds - int(DATA.spec("worker").cost), "Production must charge once when queued")
	_check(world.cancel_queue(int(hq.id)), "Queued production must be cancellable")
	_check(int(world.resources[0].essence) == funds, "Cancellation must refund the documented full cost")
	world.resources[0]["essence"] = 0
	_check(not world.queue_unit(int(hq.id), "worker"), "Unaffordable production must be rejected")
	_check(hq.queue.is_empty(), "Rejected production must not enter the queue")
	world.resources[0]["essence"] = funds
	var before: int = _count(world, 0, "worker")
	world.queue_unit(int(hq.id), "worker")
	_advance(world, float(DATA.spec("worker").time) + 0.1)
	_check(_count(world, 0, "worker") == before + 1, "Completed production must spawn exactly one unit")
	_check(hq.queue.is_empty(), "Completed production must leave the queue")

func _test_construction_and_power() -> void:
	var world: Variant = _fresh()
	var site: Vector2 = Vector2(736, 320)
	_check(world.start_build(0, "barracks", site), "Valid visible building placement must start construction")
	var barracks: Dictionary = _find(world, 0, "barracks")
	_check(not bool(barracks.completed), "Placed structures must begin incomplete")
	_check(not world.queue_unit(int(barracks.id), "infantry"), "Incomplete structures must not produce units")
	_advance(world, 25.0)
	_check(bool(barracks.completed), "Worker travel followed by construction must complete a building")
	_check(world.queue_unit(int(barracks.id), "infantry"), "Completed Barracks must produce infantry")
	for e: Dictionary in world.entities.values():
		if int(e.owner) == 0 and str(e.kind) == "power":
			e["hp"] = 0.0
	_advance(world, 0.05)
	var electricity: Dictionary = world.power(0)
	_check(int(electricity.used) > int(electricity.produced), "Destroyed Power Plant must reduce available base power")
	var remaining: float = float(barracks.queue[0].remaining)
	_advance(world, 2.0)
	_check(absf(remaining - float(barracks.queue[0].remaining) - 1.0) < 0.01, "Power shortages must slow production to the documented half rate")

func _test_building_power_accounting() -> void:
	var contributions: Dictionary = {
		"hq": {"produced": 20, "used": 0},
		"power": {"produced": 100, "used": 0},
		"refinery": {"produced": 0, "used": 15},
		"barracks": {"produced": 0, "used": 20},
		"factory": {"produced": 0, "used": 40}
	}
	for owner: int in range(2):
		var world: Variant = _fresh()
		world.entities.clear()
		for kind: String in contributions:
			var building: Dictionary = world._spawn(kind, owner, Vector2(1200, 1000))
			_check(world.power(owner) == contributions[kind], "Each completed building must have its documented power supply/demand for either owner: " + kind)
			_check(world.power(1 - owner) == {"produced": 0, "used": 0}, "Buildings must affect only their owner's power")
			building["completed"] = false
			_check(world.power(owner) == {"produced": 0, "used": 0}, "Incomplete buildings must not affect power: " + kind)
			building["completed"] = true
			building["hp"] = 0.0
			_check(world.power(owner) == {"produced": 0, "used": 0}, "Dead buildings must not affect power before removal: " + kind)
			world.entities.clear()
		for kind: String in contributions:
			world._spawn(kind, owner, Vector2(1200, 1000))
		_check(world.power(owner) == {"produced": 120, "used": 75}, "A complete set of buildings must total 120 supply and 75 demand for either owner")

func _test_producer_is_only_unit_prerequisite() -> void:
	var producers: Dictionary = {"worker": "hq", "infantry": "barracks", "tank": "factory"}
	for owner: int in range(2):
		for kind: String in producers:
			var world: Variant = _fresh()
			world.entities.clear()
			var building: Dictionary = world._spawn(producers[kind], owner, Vector2(1200, 1000))
			var funds: int = int(world.resources[owner].essence)
			_check(world.queue_unit(int(building.id), kind), "A completed matching producer alone must unlock its unit for either owner: " + kind)
			_check(int(world.resources[owner].essence) == funds - int(DATA.spec(kind).cost), "Producer-only training must retain the documented Essence cost")
			if kind != "worker":
				_check(int(world.power(owner).used) > int(world.power(owner).produced), "An isolated combat-unit producer must have a power shortage")
				var remaining: float = float(building.queue[0].remaining)
				world._produce(building, 2.0)
				_check(absf(float(building.queue[0].remaining) - (remaining - 1.0)) < 0.001, "Low power must permit queuing and train at half speed")
			world.cancel_queue(int(building.id))
			for other: String in producers:
				if other != kind:
					_check(not world.queue_unit(int(building.id), other), "A producer must reject units belonging to another building")
			building["completed"] = false
			_check(not world.queue_unit(int(building.id), kind), "An incomplete matching producer must reject training")
			building["completed"] = true
			building["hp"] = 0.0
			_check(not world.queue_unit(int(building.id), kind), "A dead matching producer must reject training")
			_check(building.queue.is_empty() and int(world.resources[owner].essence) == funds, "Rejected producer orders must leave the queue and Essence unchanged")

func _test_builders_resume_real_harvesting() -> void:
	for owner: int in range(2):
		var world: Variant = _fresh()
		var worker: Dictionary = _find(world, owner, "worker")
		for e: Dictionary in world.entities.values():
			if int(e.owner) == owner and str(e.kind) == "worker" and int(e.id) != int(worker.id):
				world.entities.erase(int(e.id))
		worker["pos"] = world._mirror(Vector2(680, 400), owner == 1)
		world._update_fog()
		var prior_patch: int = owner * 8
		world.order_gather([int(worker.id)], prior_patch)
		_check(world.start_build(owner, "barracks", world._mirror(Vector2(736, 320), owner == 1)), "Harvesting worker must accept valid construction for either faction")
		var funds_after_build: int = int(world.resources[owner].essence)
		var building: Dictionary = _find(world, owner, "barracks")
		_advance(world, 16.0)
		_check(bool(building.completed) and str(worker.order) == "gather", "Actual completing builder must automatically resume harvesting for either faction")
		_check(int(worker.target) == prior_patch, "Completing builder must prefer its previous visible growth patch")
		_advance(world, 35.0)
		_check(int(world.resources[owner].essence) > funds_after_build, "Post-construction harvesting must travel, gather and deliver new income without another order")

func _test_builder_patch_fallback_and_cargo() -> void:
	for prior_patch: int in [-999, 0, 8]:
		var world: Variant = _fresh()
		var worker: Dictionary = _find(world, 0, "worker")
		worker["pos"] = Vector2(650, 400)
		worker["order"] = "gather"
		worker["target"] = prior_patch
		worker["cargo"] = 17.0
		var building: Dictionary = world._spawn("power", 0, Vector2(650, 450), false)
		building["build_progress"] = 0.9999
		if prior_patch == 0:
			world.deposits[0]["amount"] = 0.0
		world._update_fog()
		var fallback: int = world._nearest_patch(0, worker.pos)
		world._assign_builder(building, int(worker.id))
		var funds: int = int(world.resources[0].essence)
		world._construct(building, 0.05)
		_check(bool(building.completed) and str(worker.order) == "gather" and int(worker.target) == fallback, "Invalid, depleted or hidden previous patches must fall back to nearest visible growth")
		_check(float(worker.cargo) == 17.0 and int(world.resources[0].essence) == funds, "Resuming harvesting must preserve partial cargo without crediting currency")
	var waiting: Variant = _fresh()
	var waiting_worker: Dictionary = _find(waiting, 0, "worker")
	waiting_worker["pos"] = Vector2(650, 400)
	waiting_worker["order"] = "gather"
	waiting_worker["target"] = 0
	for patch: Dictionary in waiting.deposits:
		patch["amount"] = 0.0
	var waiting_site: Dictionary = waiting._spawn("power", 0, Vector2(650, 450), false)
	waiting_site["build_progress"] = 0.9999
	waiting._assign_builder(waiting_site, int(waiting_worker.id))
	waiting._construct(waiting_site, 0.05)
	_check(str(waiting_worker.order) == "gather" and int(waiting_worker.target) == -1, "Builder with no usable growth must wait in harvesting mode")
	_advance(waiting, 2.0)
	_check(str(waiting_worker.order) in ["gather", "return"] and int(waiting_worker.target) >= 0, "Waiting builder must find regrown Essence without a manual restart")
	var full: Variant = _fresh()
	var full_worker: Dictionary = _find(full, 0, "worker")
	full_worker["pos"] = Vector2(595, 320)
	full_worker["order"] = "gather"
	full_worker["target"] = 0
	full_worker["cargo"] = 60.0
	var full_site: Dictionary = full._spawn("power", 0, Vector2(650, 320), false)
	full_site["build_progress"] = 0.9999
	full._assign_builder(full_site, int(full_worker.id))
	var full_funds: int = int(full.resources[0].essence)
	full._construct(full_site, 0.05)
	_check(str(full_worker.order) == "return" and float(full_worker.cargo) == 60.0 and int(full.resources[0].essence) == full_funds, "Full completing builder must retain its load and return before harvesting")
	_advance(full, 0.05)
	_check(int(full.resources[0].essence) == full_funds + 60 and float(full_worker.cargo) < 0.01, "Resumed builder must deliver its preserved full cargo exactly once")
	_advance(full, 0.05)
	_check(int(full.resources[0].essence) == full_funds + 60 and str(full_worker.order) == "gather", "Delivered builder must resume gathering without double credit")

func _test_replacement_builder_harvesting() -> void:
	var world: Variant = _fresh()
	var original: Dictionary = _find(world, 0, "worker")
	var replacement: Dictionary = world._spawn("worker", 0, Vector2(650, 400))
	replacement["order"] = "gather"
	replacement["target"] = 0
	var site: Dictionary = world._spawn("power", 0, Vector2(650, 450), false)
	site["build_progress"] = 0.9999
	world._assign_builder(site, int(original.id))
	world.entities.erase(int(original.id))
	world._update_fog()
	world._construct(site, 0.05)
	_check(bool(site.completed) and int(site.builder) == int(replacement.id), "A nearby replacement worker must finish construction after the original is lost")
	_check(str(replacement.order) == "gather" and int(replacement.target) == 0, "Replacement builder must remember and resume its own prior harvesting patch")

func _test_interrupted_builder_keeps_move() -> void:
	var world: Variant = _fresh()
	var original: Dictionary = _find(world, 0, "worker")
	original["pos"] = Vector2(650, 400)
	var replacement: Dictionary = world._spawn("worker", 0, Vector2(650, 400))
	var site: Dictionary = world._spawn("power", 0, Vector2(650, 450), false)
	site["build_progress"] = 0.9999
	world._assign_builder(site, int(original.id))
	var manual_destination: Vector2 = Vector2(1100, 700)
	world.order_move([int(original.id)], manual_destination)
	world._update_fog()
	world._construct(site, 0.05)
	_check(bool(site.completed) and int(site.builder) == int(replacement.id) and str(replacement.order) == "gather", "Only the replacement that completes construction must resume harvesting")
	_check(str(original.order) == "move" and Vector2(original.goal) == manual_destination, "Completion must preserve the former builder's manual movement order")

func _test_blocked_exit() -> void:
	var world: Variant = _fresh()
	var hq: Dictionary = _find(world, 0, "hq")
	var before: int = _count(world, 0, "worker")
	world.queue_unit(int(hq.id), "worker")
	world.obstacles.append(Rect2(Vector2(hq.pos) - Vector2(180, 180), Vector2(360, 360)))
	world._rebuild_navigation()
	_advance(world, float(DATA.spec("worker").time) + 0.1)
	_check(_count(world, 0, "worker") == before, "Blocked exits must not spawn overlapping units")
	_check(hq.queue.size() == 1 and float(hq.queue[0].remaining) <= 0.001, "Blocked production must retain its completed queue item")
	world.obstacles.pop_back()
	world._rebuild_navigation()
	_advance(world, 0.1)
	_check(_count(world, 0, "worker") == before + 1 and hq.queue.is_empty(), "Unblocking an exit must release the waiting unit")

func _test_ownership_and_visibility() -> void:
	var world: Variant = _fresh()
	var soldier: Dictionary = _find(world, 0, "infantry")
	var enemy: Dictionary = _find(world, 1, "infantry")
	var enemy_hq: Dictionary = _find(world, 1, "hq")
	var enemy_order: String = str(enemy.order)
	world.order_move([int(soldier.id), int(enemy.id)], Vector2(800, 600))
	_check(str(soldier.order) == "move" and str(enemy.order) == enemy_order, "Mixed-owner selections must not command enemy units")
	world.order_stop([int(soldier.id)])
	world.order_attack([int(soldier.id)], int(enemy_hq.id))
	_check(int(soldier.target) == -1, "Hidden enemies must reject new direct attack orders")
	world.order_attack([int(soldier.id)], int(_find(world, 0, "hq").id))
	_check(int(soldier.target) == -1, "Friendly targets must reject attack orders")
	_check(not world.is_visible(0, enemy_hq.pos), "Enemy base must start outside player vision")

func _test_combat_and_end_state() -> void:
	var world: Variant = _fresh()
	var soldier: Dictionary = _find(world, 0, "infantry")
	var target: Dictionary = world._spawn("worker", 1, Vector2(soldier.pos) + Vector2(90, 0))
	target["order"] = "hold"
	world._rebuild_buckets()
	world._update_fog()
	var health: float = float(target.hp)
	world.order_attack([int(soldier.id)], int(target.id))
	_advance(world, 0.05)
	_check(float(target.hp) < health, "Visible enemies in range must take damage")
	var enemy_hq: Dictionary = _find(world, 1, "hq")
	enemy_hq["hp"] = 0.0
	_advance(world, 0.05)
	_check(str(world.match_state) == "victory", "Destroying the enemy Command Center must win the match")
	var elapsed_before: float = float(world.elapsed)
	var growth_before: float = float(world.deposits[0].amount)
	world.tick(10.0)
	_check(float(world.elapsed) == elapsed_before and float(world.deposits[0].amount) == growth_before, "Match completion must freeze the simulation")
	var losing: Variant = _fresh()
	_find(losing, 0, "hq")["hp"] = 0.0
	_advance(losing, 0.05)
	_check(str(losing.match_state) == "defeat", "Losing the player Command Center must end in defeat")

func _test_destruction_effects() -> void:
	var world: Variant = _fresh()
	var soldier: Dictionary = _find(world, 0, "infantry")
	var target: Dictionary = world._spawn("worker", 1, Vector2(soldier.pos) + Vector2(90, 0))
	target["hp"] = 1.0
	target["order"] = "hold"
	world._update_fog()
	world.order_attack([int(soldier.id)], int(target.id))
	var death_position: Vector2 = target.pos
	world.tick(0.05)
	_check(not world.entities.has(int(target.id)) and world.destruction_effects.size() == 1, "An actual lethal shot must remove its target and create one death animation")
	var effect: Dictionary = world.destruction_effects[0]
	_check(int(effect.id) == int(target.id) and effect.pos == death_position and str(effect.kind) == "worker" and str(effect.faction) == str(target.faction) and not bool(effect.building), "Death animation must retain the destroyed unit identity, faction, and position")
	_check(float(effect.duration) == 1.4 and float(effect.ttl) == 1.4 and bool(effect.visible_to_player), "Visible unit deaths must start a full cosmetic lifetime")
	target["pos"] = Vector2.ZERO
	_check(effect.pos == death_position, "Death snapshot must not follow later mutations of removed entity data")
	world.tick(0.05)
	_check(world.destruction_effects.size() == 1 and is_equal_approx(float(effect.ttl), 1.35), "Death effects must age in simulation time and never duplicate removed units")
	var ttl_before: float = effect.ttl
	world.tick(0.0)
	world.advance_destruction_effects(-1.0)
	_check(float(effect.ttl) == ttl_before, "Zero or negative time must not advance death animation")
	_advance(world, 1.5)
	_check(world.destruction_effects.is_empty(), "Expired death effects must be removed")
	var hidden: Dictionary = _find(world, 1, "worker")
	_check(not world.is_visible(0, hidden.pos), "Hidden destruction scenario must begin outside player vision")
	hidden["hp"] = 0.0
	world.tick(0.05)
	_check(world.destruction_effects.is_empty(), "Hidden enemy deaths must never create an effect that exposes their location")
	var building: Dictionary = _find(world, 0, "power")
	building["hp"] = 0.0
	world.tick(0.05)
	_check(world.destruction_effects.size() == 1 and bool(world.destruction_effects[0].building) and float(world.destruction_effects[0].duration) == 2.4, "Destroyed friendly buildings must create a longer explosion snapshot")
	world.reset()
	_check(world.destruction_effects.is_empty(), "Restart must clear every pending death animation and explosion")
	world.ai_enabled = false
	var hq: Dictionary = _find(world, 0, "hq")
	hq["hp"] = 0.0
	world.tick(0.05)
	_check(str(world.match_state) == "defeat" and world.destruction_effects.size() == 1, "Decisive Command Center loss must retain its explosion after the match ends")
	var elapsed_before: float = world.elapsed
	var resources_before: Array = world.resources.duplicate(true)
	var growth_before: float = world.deposits[0].amount
	ttl_before = world.destruction_effects[0].ttl
	world.tick(1.0)
	_check(float(world.destruction_effects[0].ttl) == ttl_before, "Ended match ticks must remain completely frozen")
	world.advance_destruction_effects(0.5)
	_check(is_equal_approx(float(world.destruction_effects[0].ttl), ttl_before - 0.5), "Cosmetic aftermath helper must allow the decisive explosion to finish")
	_check(float(world.elapsed) == elapsed_before and world.resources == resources_before and float(world.deposits[0].amount) == growth_before and not world.entities.has(int(hq.id)), "Advancing post-match explosions must not advance gameplay or restore dead buildings")
	world.advance_destruction_effects(3.0)
	_check(world.destruction_effects.is_empty(), "Post-match cosmetic aftermath must eventually expire")

func _test_ai_information_boundary() -> void:
	var world: Variant = _fresh()
	world.message = "PLAYER INFO"
	world.ai_enabled = true
	world.tick(0.05)
	world.ai_enabled = false
	_check(str(world.message) == "PLAYER INFO", "Hidden AI construction and production must not leak into the player HUD")
	var enemy_hq: Dictionary = _find(world, 1, "hq")
	_check(not enemy_hq.queue.is_empty(), "HUD isolation scenario must include an actual AI production order")
	world.cancel_queue(int(enemy_hq.id))
	_check(str(world.message) == "PLAYER INFO", "Enemy cancellation must not replace player HUD messages")
	world.resources[1]["essence"] = 0
	world.queue_unit(int(enemy_hq.id), "worker")
	_check(str(world.message) == "PLAYER INFO", "Enemy resource shortages must not leak into the player HUD")
	world.queue_unit(int(_find(world, 0, "hq").id), "worker")
	_check(str(world.message) != "PLAYER INFO", "Player production must still provide HUD feedback")
	var chase: Variant = _fresh()
	var soldier: Dictionary = _find(chase, 0, "infantry")
	var enemy: Dictionary = chase._spawn("worker", 1, Vector2(soldier.pos) + Vector2(90, 0))
	chase._update_fog()
	chase.order_attack([int(soldier.id)], int(enemy.id))
	var last_seen: Vector2 = soldier.goal
	enemy["pos"] = Vector2(2600, 1800)
	chase._update_fog()
	chase.tick(0.05)
	_check(Vector2(soldier.goal).distance_to(last_seen) < 0.01 and str(soldier.order) == "attack_move", "Losing sight of an enemy must preserve its last-seen position without tracking hidden movement")

func _test_owner_health_and_damage_parity() -> void:
	var world: Variant = _fresh()
	var equal_health: bool = true
	for kind: String in DATA.SPECS:
		var player: Dictionary = world._spawn(kind, 0, Vector2(700, 700))
		var enemy: Dictionary = world._spawn(kind, 1, DATA.MAP_SIZE - Vector2(700, 700))
		equal_health = equal_health and float(player.hp) > 0 and player.hp == player.maxhp and enemy.hp == enemy.maxhp and player.hp == enemy.hp and player.maxhp == enemy.maxhp
		if bool(DATA.spec(kind).building):
			var player_site: Dictionary = world._spawn(kind, 0, Vector2(900, 700), false)
			var enemy_site: Dictionary = world._spawn(kind, 1, DATA.MAP_SIZE - Vector2(900, 700), false)
			equal_health = equal_health and player_site.hp == enemy_site.hp and player_site.maxhp == enemy_site.maxhp
	_check(equal_health, "Player and AI must spawn matching workers, combat units, buildings, and construction sites with identical HP and max HP")
	var completed_health: Array = []
	var completed: bool = true
	for owner: int in range(2):
		var construction: Variant = _fresh()
		var worker: Dictionary = _find(construction, owner, "worker")
		worker["pos"] = construction._mirror(Vector2(680, 320), owner == 1)
		var site: Dictionary = construction._spawn("barracks", owner, construction._mirror(Vector2(736, 320), owner == 1), false)
		construction._assign_builder(site, int(worker.id))
		construction._construct(site, float(DATA.spec("barracks").time))
		completed = completed and bool(site.completed) and site.hp == site.maxhp
		completed_health.append(float(site.hp))
	_check(completed and completed_health[0] == completed_health[1], "Actual construction must finish at the same full HP for player and AI buildings")
	for scenario: Dictionary in [
		{"attacker": "infantry", "target": "worker", "damage": 12.0},
		{"attacker": "tank", "target": "worker", "damage": 48.0},
		{"attacker": "infantry", "target": "tank", "damage": 8.0},
		{"attacker": "tank", "target": "tank", "damage": 44.0}
	]:
		var player_damage: float = _single_shot_damage(str(scenario.attacker), str(scenario.target), 0)
		var enemy_damage: float = _single_shot_damage(str(scenario.attacker), str(scenario.target), 1)
		_check(player_damage == enemy_damage and player_damage == float(scenario.damage), "Mirrored actual shots must cause equal damage in both directions: " + str(scenario.attacker) + " versus " + str(scenario.target))

func _single_shot_damage(attacker_kind: String, target_kind: String, owner: int, level: String = "normal") -> float:
	var world: Variant = _fresh()
	world.set_ai_difficulty(level)
	for id: int in world.entities.keys():
		if str(world.entities[id].kind) != "hq":
			world.entities.erase(id)
	var attacker: Dictionary = world._spawn(attacker_kind, owner, world._mirror(Vector2(700, 700), owner == 1))
	var target: Dictionary = world._spawn(target_kind, 1 - owner, world._mirror(Vector2(790, 700), owner == 1))
	target["order"] = "move"
	target["goal"] = target.pos
	world._rebuild_buckets()
	world._update_fog()
	world.order_attack([int(attacker.id)], int(target.id))
	var before: float = float(target.hp)
	world.tick(0.05)
	return before - float(target.hp)

func _test_ai_difficulty_selection() -> void:
	var world: Variant = _fresh()
	_check(str(world.ai_difficulty) == "normal", "New matches must default to Normal AI")
	_check(world.set_ai_difficulty("hard") and str(world.ai_difficulty) == "hard", "Supported difficulty selection must succeed")
	_advance(world, 0.1)
	var elapsed_before: float = float(world.elapsed)
	var funds_before: int = int(world.resources[1].essence)
	var entity_count: int = world.entities.size()
	_check(world.set_ai_difficulty("easy") and float(world.elapsed) == elapsed_before and int(world.resources[1].essence) == funds_before and world.entities.size() == entity_count, "Selecting difficulty must not restart or modify the running match")
	_check(not world.set_ai_difficulty("unknown") and str(world.ai_difficulty) == "easy", "Invalid difficulty must fail without replacing the selection")
	for level: String in SIM.AI_LEVELS:
		world.set_ai_difficulty(level)
		world.reset()
		_check(str(world.ai_difficulty) == level and float(world.elapsed) == 0.0 and float(world._ai_timer) == 0.0 and float(world._attack_timer) == 0.0, "Reset must preserve selected difficulty and clear planning timers: " + level)

func _test_ai_decision_and_worker_profiles() -> void:
	for level: String in SIM.AI_LEVELS:
		var profile: Dictionary = SIM.AI_PROFILES[level]
		var cadence: Variant = _fresh()
		cadence.set_ai_difficulty(level)
		cadence.ai_enabled = true
		cadence.tick(0.05)
		var hq: Dictionary = _find(cadence, 1, "hq")
		_check(not hq.queue.is_empty(), "First AI decision must make an actual worker production order: " + level)
		cadence.cancel_queue(int(hq.id))
		_advance(cadence, float(profile.decision_interval) - 0.1)
		_check(hq.queue.is_empty(), "AI must wait its decision interval before replacing a cancelled order: " + level)
		_advance(cadence, 0.2)
		_check(not hq.queue.is_empty(), "AI must make a new production decision when its interval elapses: " + level)
		var economy: Variant = _fresh()
		economy.set_ai_difficulty(level)
		var goal: int = int(profile.worker_target)
		while _count(economy, 1, "worker") < goal - 1:
			economy._spawn("worker", 1, Vector2(2350, 1600))
		var economy_hq: Dictionary = _find(economy, 1, "hq")
		economy._ai_tick()
		_check(economy_hq.queue.size() == 1 and str(economy_hq.queue[0].kind) == "worker", "AI must order another worker below its economy target: " + level)
		economy.cancel_queue(int(economy_hq.id))
		economy._spawn("worker", 1, Vector2(2350, 1600))
		economy._ai_tick()
		_check(economy_hq.queue.is_empty(), "AI must stop requesting workers once its target is reached: " + level)
		_check(economy.queue_unit(int(economy_hq.id), "worker"), "AI economy targets must not impose a worker population cap: " + level)

func _test_ai_attack_profiles() -> void:
	for level: String in SIM.AI_LEVELS:
		var profile: Dictionary = SIM.AI_PROFILES[level]
		var world: Variant = _fresh()
		world.set_ai_difficulty(level)
		world.resources[1]["essence"] = 0
		world.elapsed = float(profile.first_attack) - 1.0
		world.ai_enabled = true
		var soldier: Dictionary = _find(world, 1, "infantry")
		world.tick(0.05)
		_check(str(soldier.order) == "idle", "AI must not scout or attack before its difficulty threshold: " + level)
		_advance(world, float(profile.decision_interval) - 0.1)
		_check(str(soldier.order) == "idle", "Crossing a threshold must still wait for the next AI planning decision: " + level)
		_advance(world, 0.2)
		_check(str(soldier.order) == "attack_move" and float(world.elapsed) >= float(profile.first_attack), "AI must issue an actual scouting order on the next eligible decision: " + level)
		world.order_stop([int(soldier.id)], true)
		_advance(world, float(profile.attack_interval) - 0.2)
		_check(str(soldier.order) == "hold", "AI must not reissue attack orders before its configured interval: " + level)
		_advance(world, float(profile.decision_interval) + 0.3)
		_check(str(soldier.order) == "attack_move", "AI must reissue attack orders on the next decision after its interval: " + level)

func _test_difficulty_preserves_fair_rules() -> void:
	for level: String in SIM.AI_LEVELS:
		var world: Variant = _fresh()
		world.set_ai_difficulty(level)
		_check(int(world.resources[0].essence) == 900 and int(world.resources[1].essence) == 900 and not world.is_visible(1, _find(world, 0, "hq").pos), "Difficulty must not grant free Essence or hidden enemy vision: " + level)
		var equal_health: bool = true
		for kind: String in DATA.SPECS:
			var player: Dictionary = world._spawn(kind, 0, Vector2(900, 600))
			var enemy: Dictionary = world._spawn(kind, 1, Vector2(2172, 1448))
			equal_health = equal_health and player.hp == enemy.hp and float(enemy.maxhp) == float(DATA.spec(kind, "humans").hp)
		_check(equal_health, "Difficulty must preserve shared role health without AI bonuses: " + level)
		_check(_single_shot_damage("infantry", "tank", 0, level) == 8.0 and _single_shot_damage("infantry", "tank", 1, level) == 8.0 and _single_shot_damage("tank", "worker", 0, level) == 48.0 and _single_shot_damage("tank", "worker", 1, level) == 48.0, "Actual infantry and tank shots must remain identical across difficulties and sides: " + level)
		var production: Variant = _fresh()
		production.set_ai_difficulty(level)
		for owner: int in range(2):
			production.queue_unit(int(_find(production, owner, "hq").id), "worker")
		_advance(production, 5.9)
		_check(_count(production, 0, "worker") == 3 and _count(production, 1, "worker") == 3 and int(production.resources[0].essence) == 840 and int(production.resources[1].essence) == 840, "Difficulty must preserve worker costs and avoid faster AI training: " + level)
		_advance(production, 0.2)
		_check(_count(production, 0, "worker") == 4 and _count(production, 1, "worker") == 4, "Both sides must finish worker training at the shared six-second duration: " + level)
