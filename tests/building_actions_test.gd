extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const DATA = preload("res://scripts/catalog.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_repair_timing_and_prices()
	_test_repair_funds_and_toggle()
	_test_action_validation()
	_test_sale_values_and_activation()
	_test_sale_queue()
	_test_sale_builder()
	_test_hq_sale_and_end()
	if failures == 0:
		print("PASS: %d building action checks" % checks)
	else:
		push_error("FAIL: %d of %d building action checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _fresh(faction: String = "humans") -> Variant:
	var world: Variant = SIM.new()
	world.configure_skirmish(faction, faction)
	world.reset()
	world.ai_enabled = false
	for owner: int in range(2):
		var units: Array = []
		for e: Dictionary in world.entities.values():
			if int(e.owner) == owner and not bool(world.entity_spec(e).building):
				units.append(int(e.id))
		world.order_stop(units, true)
	return world

func _find(world: Variant, owner: int, kind: String) -> Dictionary:
	for e: Dictionary in world.entities.values():
		if int(e.owner) == owner and str(e.kind) == kind:
			return e
	return {}

func _advance(world: Variant, seconds: float) -> void:
	for index: int in range(roundi(seconds / SIM.STEP)):
		world.tick(SIM.STEP)

func _count(world: Variant, kind: String) -> int:
	var count: int = 0
	for e: Dictionary in world.entities.values():
		if str(e.kind) == kind:
			count += 1
	return count

func _test_repair_timing_and_prices() -> void:
	for faction: String in DATA.FACTIONS:
		var world: Variant = _fresh(faction)
		for owner: int in range(2):
			var pos := Vector2(900, 300) if owner == 0 else Vector2(2200, 1700)
			var building: Dictionary = world._spawn("outpost", owner, pos)
			var cost: float = float(world.entity_spec(building).cost)
			building.hp = float(building.maxhp) * 0.5
			var before: int = int(world.resources[owner].essence)
			_check(world.toggle_repair(owner, int(building.id)), "Damaged completed buildings must accept repair: %s/%d" % [faction, owner])
			_advance(world, 10.0)
			var pulses: int = floori(cost * 0.1 + 0.00001)
			var expected: float = float(building.maxhp) * 0.5 + float(pulses) * float(building.maxhp) / (cost * 0.5) + 10.0 * float(world.entity_spec(building).get("regen", 0.0))
			_check(is_equal_approx(float(building.hp), expected), "Paid repair and existing faction regeneration must retain their simulation-time rates: %s/%d" % [faction, owner])
			_check(int(world.resources[owner].essence) == before - pulses, "Repair must charge the actual faction building cost equally for each owner: %s/%d" % [faction, owner])
			_check(world.toggle_repair(owner, int(building.id)) and not bool(building.repairing), "Repair must toggle off: %s/%d" % [faction, owner])

func _test_repair_funds_and_toggle() -> void:
	var world: Variant = _fresh()
	var building: Dictionary = _find(world, 0, "power")
	building.hp = float(building.maxhp) * 0.5
	world.resources[0].essence = 0
	_check(world.toggle_repair(0, int(building.id)), "Empty funds must allow pending repair")
	_advance(world, 20.0)
	_check(is_equal_approx(float(building.hp), 300.0) and int(world.resources[0].essence) == 0, "Unfunded repair must not heal or spend below zero")
	world.resources[0].essence = 1
	_advance(world, 0.1)
	_check(is_equal_approx(float(building.hp), 300.0), "Unfunded waiting must not bank repair time")
	_advance(world, 2.0)
	_check(is_equal_approx(float(building.hp), 310.0) and int(world.resources[0].essence) == 0 and bool(building.repairing), "A single essence must fund exactly one pulse and then wait")
	world.resources[0].essence = 100
	_advance(world, 40.0)
	_check(is_equal_approx(float(building.hp), 600.0) and not bool(building.repairing), "Repair must cap at maximum HP and turn off")
	_check(int(world.resources[0].essence) == 71, "Half-health repair must charge exactly one quarter of the building price")
	_advance(world, 2.0)
	_check(int(world.resources[0].essence) == 71, "A completed repair must stop charging")
	building.hp = 599.5
	_check(world.toggle_repair(0, int(building.id)), "Minor new damage must be repairable")
	_advance(world, 1.0)
	_check(is_equal_approx(float(building.hp), 600.0) and int(world.resources[0].essence) == 70, "A partial final pulse must cost one essence and never over-heal")
	building.hp = 300.0
	world.toggle_repair(0, int(building.id))
	_advance(world, 0.25)
	world.toggle_repair(0, int(building.id))
	var hp: float = float(building.hp)
	var essence: int = int(world.resources[0].essence)
	_advance(world, 3.0)
	_check(is_equal_approx(float(building.hp), hp) and int(world.resources[0].essence) == essence, "Turning repair off must stop healing and charges")
	world.toggle_repair(0, int(building.id))
	_advance(world, 0.6)
	_check(is_equal_approx(float(building.hp), hp), "Turning repair off must discard unfinished pulse time")

func _test_action_validation() -> void:
	var world: Variant = _fresh()
	var building: Dictionary = _find(world, 0, "power")
	var enemy: Dictionary = _find(world, 1, "power")
	building.hp = 300.0
	enemy.hp = 300.0
	var unit: Dictionary = _find(world, 0, "worker")
	unit.hp = 1.0
	var incomplete: Dictionary = world._spawn("barracks", 0, Vector2(850, 400), false)
	var dead: Dictionary = world._spawn("power", 0, Vector2(850, 600))
	dead.hp = 0.0
	var before: Array = world.resources.duplicate(true)
	for pair: Array in [[0, int(enemy.id)], [1, int(building.id)], [-1, int(building.id)], [2, int(building.id)], [0, -9], [0, int(unit.id)], [0, int(dead.id)]]:
		_check(not world.can_repair(pair[0], pair[1]) and not world.toggle_repair(pair[0], pair[1]), "Repair must reject invalid ownership/type/life: " + str(pair))
		_check(not world.can_sell(pair[0], pair[1]) and not world.sell_building(pair[0], pair[1]) and world.sell_refund(pair[0], pair[1]) == 0, "Sale must reject invalid ownership/type/life: " + str(pair))
	_check(not world.can_repair(0, int(incomplete.id)) and not world.toggle_repair(0, int(incomplete.id)), "Incomplete buildings must not accept repair")
	building.hp = building.maxhp
	_check(not world.can_repair(0, int(building.id)) and not world.toggle_repair(0, int(building.id)), "Full-health buildings must not accept repair")
	_check(world.resources == before and world.entities.has(enemy.id) and world.entities.has(building.id), "Rejected actions must preserve funds and buildings")

func _test_sale_values_and_activation() -> void:
	for faction: String in DATA.FACTIONS:
		var world: Variant = _fresh(faction)
		for owner: int in range(2):
			for kind: String in DATA.BUILDING_KINDS:
				if kind == "hq":
					continue
				var building: Dictionary = world._spawn(kind, owner, Vector2(1000, 600))
				building.hp = float(building.maxhp) * 0.37
				var refund: int = floori(float(world.entity_spec(building).cost) * 0.5 * 0.37)
				var before: int = int(world.resources[owner].essence)
				_check(world.sell_refund(owner, int(building.id)) == refund, "Sale quote must scale with actual faction cost and remaining HP: %s/%s/%d" % [faction, kind, owner])
				_check(world.sell_building(owner, int(building.id)) and not world.entities.has(building.id), "Sale must immediately remove every building role: %s/%s/%d" % [faction, kind, owner])
				_check(int(world.resources[owner].essence) == before + refund and not world.sell_building(owner, int(building.id)), "Sale must refund exactly once: %s/%s/%d" % [faction, kind, owner])
	var world: Variant = _fresh()
	var power: Dictionary = _find(world, 0, "power")
	world.sell_building(0, int(power.id))
	_check(int(world.power(0).produced) == 20, "Sold power generation must disappear immediately")
	var barracks: Dictionary = world._spawn("barracks", 0, Vector2(850, 300))
	var factory: Dictionary = world._spawn("factory", 0, Vector2(1050, 300))
	_check(world.has_requirements(0, "factory"), "Sale prerequisite fixture must have a completed Barracks")
	world.sell_building(0, int(barracks.id))
	_check(not world.has_requirements(0, "factory") and not world.can_produce(int(barracks.id), "infantry"), "Sold prerequisite and production permissions must disappear immediately")
	world.sell_building(0, int(factory.id))
	_check(int(world.power(0).used) == 15, "Sold building power use must disappear immediately")
	var outpost: Dictionary = world._spawn("outpost", 0, Vector2(950, 1450))
	world._rebuild_navigation()
	world._update_fog()
	var observed: Vector2 = Vector2(outpost.pos) + Vector2(0, 500)
	_check(world.is_visible(0, observed) and not world._walkable(outpost.pos, 1.0), "Sale fixture must contribute vision and block its footprint")
	world.sell_building(0, int(outpost.id))
	_check(not world.is_visible(0, observed) and world.explored[0].has(world._cell(observed)), "Sold vision must disappear while previously explored terrain stays explored")
	_check(world._walkable(outpost.pos, 1.0) and not world._grid.is_point_solid(world._cell(outpost.pos)), "Sold footprint must unblock both collision and navigation immediately")

func _test_sale_queue() -> void:
	var world: Variant = _fresh()
	var barracks: Dictionary = world._spawn("barracks", 0, Vector2(850, 300))
	_check(world.queue_unit(int(barracks.id), "infantry") and world.queue_unit(int(barracks.id), "infantry"), "Sale queue fixture must pay for both queued units")
	world.obstacles.append(Rect2(Vector2(barracks.pos) - Vector2(180, 180), Vector2(360, 360)))
	world._rebuild_navigation()
	_advance(world, 20.0)
	_check(barracks.queue.size() == 2 and float(barracks.queue[0].remaining) <= 0.001 and world._blocked_production.has(barracks.id), "Sale queue fixture must contain an actually blocked completed unit")
	var before: int = int(world.resources[0].essence)
	var count: int = _count(world, "infantry")
	var refund: int = int(world.sell_refund(0, int(barracks.id))) + int(barracks.queue[0].cost) + int(barracks.queue[1].cost)
	_check(world.sell_building(0, int(barracks.id)) and int(world.resources[0].essence) == before + refund, "Sale must refund all paid queue entries, including blocked ready units")
	_check(not world._blocked_production.has(barracks.id), "Sale must clear blocked production bookkeeping")
	_advance(world, 20.0)
	_check(_count(world, "infantry") == count, "Sold producer must never release queued units")

func _test_sale_builder() -> void:
	for manual: bool in [false, true]:
		var world: Variant = _fresh()
		var worker: Dictionary = _find(world, 0, "worker")
		worker.cargo = SIM.CARRY_CAPACITY
		worker.order = "gather"
		worker.target = 0
		var building: Dictionary = world._spawn("barracks", 0, Vector2(850, 400), false)
		world._assign_builder(building, int(worker.id))
		if manual:
			world.order_move([int(worker.id)], Vector2(800, 700))
		var before: int = int(world.resources[0].essence)
		var refund: int = floori(float(world.entity_spec(building).cost) * 0.05)
		_check(world.can_sell(0, int(building.id)) and world.sell_building(0, int(building.id)), "Incomplete structures must be sellable")
		_check(int(world.resources[0].essence) == before + refund, "Incomplete sale must use actual HP without a full-price construction refund")
		_check(is_equal_approx(float(worker.cargo), SIM.CARRY_CAPACITY), "Sale must preserve a builder's carried essence")
		if manual:
			_check(str(worker.order) == "move" and Vector2(worker.goal).distance_to(Vector2(800, 700)) < 0.001, "Sale must respect a former builder's manual orders")
		else:
			_check(str(worker.order) == "return" and int(worker.target) == 0, "Sale must resume the assigned builder's previous harvest patch and deliver full cargo first")

func _test_hq_sale_and_end() -> void:
	for owner: int in range(2):
		var world: Variant = _fresh()
		var hq: Dictionary = _find(world, owner, "hq")
		_check(world.sell_building(owner, int(hq.id)), "A Command Center sale must use the shared owner action")
		_check(world.match_state == ("defeat" if owner == 0 else "victory"), "A Command Center sale must resolve the match immediately")
		var power: Dictionary = _find(world, 1 - owner, "power")
		power.hp = 300.0
		var before: Array = world.resources.duplicate(true)
		_check(not world.toggle_repair(1 - owner, int(power.id)) and not world.sell_building(1 - owner, int(power.id)), "Match end must reject repair and sale")
		var elapsed: float = float(world.elapsed)
		_advance(world, 5.0)
		_check(world.resources == before and is_equal_approx(float(power.hp), 300.0) and is_equal_approx(float(world.elapsed), elapsed), "Match end must freeze repair charges and simulation")
