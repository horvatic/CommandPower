extends RefCounted

signal weapon_fired(shooter: Dictionary, target_position: Vector2)
signal player_event(event: String, details: Dictionary)

const DATA = preload("res://scripts/catalog.gd")
const MAP_CATALOG = preload("res://scripts/skirmish_maps.gd")
const PLAYER_COLOR_NAMES := ["Teal", "Orange", "Blue", "Red", "Gold", "Violet", "White", "Pink"]
const PLAYER_COLORS := [Color("58e6c2"), Color("ff805b"), Color("5d9eff"), Color("ee505b"), Color("f0d45b"), Color("b58aee"), Color("e6ece8"), Color("f08bce")]
const STEP: float = 0.05
const BUCKET_SIZE: float = 160.0
const CARRY_CAPACITY: float = 60.0
const HARVEST_RATE: float = 6.0
const REGROW_RATE: float = 1.0
const REPAIR_RATE: float = 0.02
const REPAIR_COST_FRACTION: float = 0.5
const SELL_FRACTION: float = 0.5
const AI_LEVELS: Array[String] = ["easy", "normal", "hard"]
const AI_PROFILES: Dictionary = {
	"easy": {"decision_interval": 4.0, "worker_target": 4, "first_attack": 70.0, "attack_interval": 30.0},
	"normal": {"decision_interval": 2.0, "worker_target": 6, "first_attack": 35.0, "attack_interval": 18.0},
	"hard": {"decision_interval": 1.0, "worker_target": 8, "first_attack": 20.0, "attack_interval": 10.0}
}

var map_id: String = "silent_wells"
var map_size: Vector2 = DATA.MAP_SIZE
var player_colors: Array[Color] = [PLAYER_COLORS[0], PLAYER_COLORS[1]]
var entities: Dictionary = {}
var deposits: Array = []
var wells: Array = []
var obstacles: Array[Rect2] = []
var resources: Array = []
var visible: Array[Dictionary] = [{}, {}]
var explored: Array[Dictionary] = [{}, {}]
var effects: Array = []
var destruction_effects: Array = []
var elapsed: float = 0.0
var match_state: String = "playing"
var ai_enabled: bool = true
var ai_difficulty: String = "normal"
var player_factions: Array[String] = ["humans", "iron_synod"]
var message: String = ""
var _next_id: int = 1
var _accumulator: float = 0.0
var _fog_timer: float = 0.0
var _ai_timer: float = 0.0
var _attack_timer: float = 0.0
var _ai_scout_step: int = 0
var _ai_enemy_memory: Dictionary = {}
var _buckets: Dictionary = {}
var _grid: AStarGrid2D = AStarGrid2D.new()
var _navigation_version: int = 0
var _solid_rects: Array[Rect2] = []
var _blocked_production: Dictionary = {}
var _player_low_power := false

func _init() -> void:
	reset()

func set_ai_difficulty(level: String) -> bool:
	if not AI_PROFILES.has(level):
		return false
	ai_difficulty = level
	return true

func configure_skirmish(player: String, enemy: String) -> bool:
	if not DATA.FACTIONS.has(player) or not DATA.FACTIONS.has(enemy):
		return false
	player_factions = [player, enemy]
	return true

func configure_map(id: String) -> bool:
	if not MAP_CATALOG.MAPS.has(id):
		return false
	map_id = id
	map_size = MAP_CATALOG.MAPS[id].size
	return true

func configure_colors(player: Color, enemy: Color) -> bool:
	if player == enemy or not PLAYER_COLORS.has(player) or not PLAYER_COLORS.has(enemy):
		return false
	player_colors = [player, enemy]
	return true

func color_for(owner: int) -> Color:
	return player_colors[clampi(owner, 0, 1)]

func faction_for(owner: int) -> String:
	return player_factions[clampi(owner, 0, 1)]

func entity_title(kind: String, owner: int = 0) -> String:
	return DATA.faction_title(kind, faction_for(owner))

func spec_for(kind: String, owner: int = 0) -> Dictionary:
	return DATA.spec(kind, faction_for(owner))

func entity_spec(entity: Dictionary) -> Dictionary:
	return DATA.spec(str(entity.kind), str(entity.get("faction", faction_for(int(entity.owner)))))

func reset() -> void:
	entities.clear()
	_buckets.clear()
	deposits.clear()
	wells.clear()
	effects.clear()
	destruction_effects.clear()
	resources = [{"essence": 900}, {"essence": 900}]
	visible = [{}, {}]
	explored = [{}, {}]
	_next_id = 1
	elapsed = 0.0
	_accumulator = 0.0
	_fog_timer = 0.0
	_ai_timer = 0.0
	_attack_timer = 0.0
	_ai_scout_step = 0
	_ai_enemy_memory.clear()
	_blocked_production.clear()
	match_state = "playing"
	message = "Harvest Spiritual Essence, build an army, destroy the enemy Command Center."
	var layout: Dictionary = MAP_CATALOG.MAPS[map_id]
	map_size = layout.size
	obstacles.assign(layout.obstacles)
	var well_positions: Array = layout.wells
	for w: int in range(well_positions.size()):
		wells.append({"id": w, "pos": well_positions[w]})
		for p: int in range(8):
			var angle: float = TAU * float(p) / 8.0
			deposits.append({"id": deposits.size(), "pos": well_positions[w] + Vector2.from_angle(angle) * 98.0, "amount": 160.0, "capacity": 160.0, "well_id": w})
	for owner: int in range(2):
		var flip: bool = owner == 1
		_spawn("hq", owner, _mirror(Vector2(320, 320), flip))
		_spawn("power", owner, _mirror(Vector2(320, 480), flip))
		_spawn("refinery", owner, _mirror(Vector2(530, 320), flip))
		for i: int in range(3):
			var worker: Dictionary = _spawn("worker", owner, _mirror(Vector2(450 + i * 34, 430), flip))
			worker["order"] = "gather"
			worker["target"] = owner * 8 + i
		for i: int in range(2):
			_spawn("infantry", owner, _mirror(Vector2(410 + i * 35, 225), flip))
	_rebuild_navigation()
	_rebuild_buckets()
	_update_fog()
	var electricity: Dictionary = power(0)
	_player_low_power = int(electricity.used) > int(electricity.produced)

func _mirror(pos: Vector2, flip: bool) -> Vector2:
	return map_size - pos if flip else pos

func _spawn(kind: String, owner: int, pos: Vector2, complete: bool = true) -> Dictionary:
	var definition: Dictionary = spec_for(kind, owner)
	var entity: Dictionary = {"id": _next_id, "kind": kind, "owner": owner, "pos": pos, "hp": float(definition.hp) if complete else float(definition.hp) * 0.1, "maxhp": float(definition.hp), "radius": float(definition.radius), "completed": complete, "build_progress": 1.0 if complete else 0.0, "queue": [], "rally": pos + Vector2(0, 120 if owner == 0 else -120), "order": "idle", "target": -1, "goal": pos, "cargo": 0.0, "facing": Vector2.DOWN if owner == 0 else Vector2.UP, "cooldown_left": 0.0, "last_damage_at": -99.0, "slow_until": -1.0, "slow_factor": 1.0, "slows": {}, "path": PackedVector2Array(), "path_index": 0, "path_goal": Vector2(-9999, -9999), "path_version": -1, "repath": 0.0, "builder": -1, "gather_target": -1}
	entity["faction"] = faction_for(owner)
	entity["team_color"] = color_for(owner)
	entity["repairing"] = false
	entity["repair_progress"] = 0.0
	entities[_next_id] = entity
	var bucket := Vector2i(floor(pos.x / BUCKET_SIZE), floor(pos.y / BUCKET_SIZE))
	if not _buckets.has(bucket):
		_buckets[bucket] = []
	_buckets[bucket].append(_next_id)
	_next_id += 1
	return entity

func tick(dt: float) -> void:
	if match_state != "playing" or dt <= 0.0:
		return
	_accumulator += dt
	while _accumulator >= STEP and match_state == "playing":
		_accumulator -= STEP
		_step(STEP)

func _step(dt: float) -> void:
	elapsed += dt
	for patch: Dictionary in deposits:
		patch["amount"] = minf(float(patch.capacity), float(patch.amount) + REGROW_RATE * dt)
	for i: int in range(effects.size() - 1, -1, -1):
		effects[i]["ttl"] = float(effects[i].ttl) - dt
		if float(effects[i].ttl) <= 0.0:
			effects.remove_at(i)
	advance_destruction_effects(dt)
	_fog_timer -= dt
	if _fog_timer <= 0.0:
		_update_fog()
		_fog_timer = 0.25
	_rebuild_buckets()
	if ai_enabled:
		_ai_timer -= dt
		if _ai_timer <= 0.0:
			_ai_tick()
			_ai_timer = float(AI_PROFILES[ai_difficulty].decision_interval)
	var entity_ids: Array = entities.keys()
	for id: int in entity_ids:
		if not entities.has(id):
			continue
		var e: Dictionary = entities[id]
		if float(e.hp) <= 0.0:
			continue
		e["cooldown_left"] = maxf(0.0, float(e.cooldown_left) - dt)
		e["repath"] = maxf(0.0, float(e.repath) - dt)
		var definition: Dictionary = entity_spec(e)
		if bool(definition.building):
			if not bool(e.completed):
				_construct(e, dt)
			else:
				_repair(e, dt)
				_produce(e, dt)
		elif str(e.kind) == "worker":
			_worker(e, dt)
		else:
			_combat_unit(e, dt)
		if _ability_active(e):
			_regenerate(e, dt)
			_support(e, dt)
			if bool(definition.building) and float(definition.damage) > 0.0:
				_combat_unit(e, dt)
	var navigation_changed: bool = false
	for id: int in entities.keys():
		var e: Dictionary = entities[id]
		if float(e.hp) <= 0.0:
			if bool(entity_spec(e).building):
				navigation_changed = true
			_record_destruction(e)
			_player_notice(int(e.owner), "building_lost" if bool(entity_spec(e).building) else "unit_lost", e)
			_blocked_production.erase(id)
			entities.erase(id)
	if navigation_changed:
		_rebuild_navigation()
	_check_match_end()

func _check_match_end() -> void:
	var alive: Array[bool] = [false, false]
	for e: Dictionary in entities.values():
		if str(e.kind) == "hq" and float(e.hp) > 0.0:
			alive[int(e.owner)] = true
	if not alive[0] or not alive[1]:
		match_state = "draw" if not alive[0] and not alive[1] else ("victory" if alive[0] else "defeat")
		message = "Command Center destroyed. " + match_state.capitalize() + "."
		_player_notice(0, match_state)
	else:
		_check_power_notice()

func advance_destruction_effects(dt: float) -> void:
	# Cosmetic aftermath may finish after victory without advancing the match.
	if dt <= 0.0:
		return
	for i: int in range(destruction_effects.size() - 1, -1, -1):
		destruction_effects[i]["ttl"] = float(destruction_effects[i].ttl) - dt
		if float(destruction_effects[i].ttl) <= 0.0:
			destruction_effects.remove_at(i)

func _record_destruction(entity: Dictionary) -> void:
	# Capture only observed losses; later exploration must never reveal a hidden death.
	if int(entity.owner) != 0 and not can_see_entity(0, entity):
		return
	var building: bool = bool(entity_spec(entity).building)
	var duration: float = 2.4 if building else 1.4
	destruction_effects.append({
		"id": int(entity.id), "kind": str(entity.kind), "owner": int(entity.owner),
		"faction": str(entity.get("faction", faction_for(int(entity.owner)))),
		"team_color": entity.get("team_color", color_for(int(entity.owner))),
		"pos": Vector2(entity.pos), "radius": float(entity.radius), "building": building,
		"completed": bool(entity.completed), "build_progress": float(entity.build_progress),
		"facing": Vector2(entity.facing), "ttl": duration, "duration": duration,
		"seed": int(entity.id), "visible_to_player": true, "elapsed_at_death": elapsed
	})

func _player_notice(owner: int, event: String, entity: Dictionary = {}) -> void:
	if owner != 0:
		return
	var details := {"owner": 0}
	for key: String in ["id", "kind", "pos", "completed"]:
		if entity.has(key):
			details[key] = entity[key]
	player_event.emit(event, details)

func _check_power_notice() -> void:
	var electricity: Dictionary = power(0)
	var low: bool = int(electricity.used) > int(electricity.produced)
	if low != _player_low_power:
		_player_low_power = low
		_player_notice(0, "low_power" if low else "power_restored")

func _valid_order_ids(ids: Array) -> Array:
	var result: Array = []
	var owner: int = -1
	for value: Variant in ids:
		var id: int = int(value)
		if not entities.has(id):
			continue
		var e: Dictionary = entities[id]
		if owner < 0:
			owner = int(e.owner)
		if int(e.owner) == owner and not bool(entity_spec(e).building) and bool(e.completed):
			result.append(id)
	return result

func order_move(ids: Array, goal: Vector2, attack_move: bool = false) -> void:
	if match_state != "playing":
		return
	var valid: Array = _valid_order_ids(ids)
	var columns: int = maxi(1, int(ceil(sqrt(float(valid.size())))))
	for index: int in range(valid.size()):
		var e: Dictionary = entities[valid[index]]
		var offset: Vector2 = Vector2(float(index % columns) - float(columns - 1) * 0.5, float(index / columns) - float(columns - 1) * 0.5) * 38.0
		e["goal"] = (goal + offset).clamp(Vector2(24, 24), map_size - Vector2(24, 24))
		e["order"] = "attack_move" if attack_move else "move"
		e["target"] = -1
		_clear_path(e)

func order_attack(ids: Array, target: int) -> void:
	if match_state != "playing" or not entities.has(target):
		return
	var enemy: Dictionary = entities[target]
	for id: int in _valid_order_ids(ids):
		var e: Dictionary = entities[id]
		if int(e.owner) == int(enemy.owner) or not can_see_entity(int(e.owner), enemy) or float(entity_spec(e).damage) <= 0.0:
			continue
		e["order"] = "attack"
		e["target"] = target
		e["goal"] = enemy.pos
		_clear_path(e)

func order_gather(ids: Array, deposit: int) -> void:
	if match_state != "playing" or deposit < 0 or deposit >= deposits.size():
		return
	for id: int in _valid_order_ids(ids):
		var e: Dictionary = entities[id]
		if str(e.kind) != "worker" or not is_visible(int(e.owner), deposits[deposit].pos):
			continue
		e["order"] = "gather"
		e["target"] = deposit
		e["gather_target"] = deposit
		_clear_path(e)

func order_stop(ids: Array, hold: bool = false) -> void:
	if match_state != "playing":
		return
	for id: int in _valid_order_ids(ids):
		var e: Dictionary = entities[id]
		e["order"] = "hold" if hold else "idle"
		e["target"] = -1
		e["goal"] = e.pos
		_clear_path(e)

func can_build(owner: int, kind: String, pos: Vector2) -> bool:
	var definition: Dictionary = spec_for(kind, owner)
	if match_state != "playing" or owner < 0 or owner > 1 or definition.is_empty() or not bool(definition.building):
		return false
	if int(resources[owner].essence) < int(definition.cost) or not is_visible(owner, pos):
		return false
	if kind == "hq" or not _has_building(owner, "hq"):
		return false
	if not has_requirements(owner, kind):
		return false
	var worker: int = _available_worker(owner, pos, false)
	if worker < 0:
		return false
	var size: Vector2 = definition.size
	var area: Rect2 = Rect2(pos - size * 0.5, size).grow(12.0)
	if not Rect2(Vector2(16, 16), map_size - Vector2(32, 32)).encloses(area):
		return false
	for obstacle: Rect2 in obstacles:
		if obstacle.intersects(area):
			return false
	for patch: Dictionary in deposits:
		if area.grow(20.0).has_point(patch.pos):
			return false
	for well: Dictionary in wells:
		if area.grow(38.0).has_point(well.pos):
			return false
	var near_base: bool = false
	for e: Dictionary in entities.values():
		var other_def: Dictionary = entity_spec(e)
		if bool(other_def.building):
			if area.intersects(Rect2(Vector2(e.pos) - Vector2(other_def.size) * 0.5, other_def.size)):
				return false
			if int(e.owner) == owner and bool(e.completed) and pos.distance_to(e.pos) <= 650.0:
				near_base = true
		elif area.grow(float(e.radius)).has_point(e.pos):
			return false
	return near_base

func start_build(owner: int, kind: String, pos: Vector2) -> bool:
	if not can_build(owner, kind, pos):
		_notify(owner, "Cannot build: check Essence, worker, prerequisites, vision and clear terrain.")
		var definition: Dictionary = spec_for(kind, owner)
		if match_state == "playing" and owner == 0 and not definition.is_empty() and bool(definition.building):
			_player_notice(owner, "insufficient_essence" if int(resources[owner].essence) < int(definition.cost) else "cannot_build_here", {"kind": kind, "pos": pos})
		return false
	var worker_id: int = _available_worker(owner, pos, false)
	resources[owner]["essence"] = int(resources[owner].essence) - int(spec_for(kind, owner).cost)
	var building: Dictionary = _spawn(kind, owner, pos, false)
	_assign_builder(building, worker_id)
	_rebuild_navigation()
	_notify(owner, entity_title(kind, owner) + " construction started.")
	_player_notice(owner, "construction_started", building)
	return true

func _notify(owner: int, text: String) -> void:
	if owner == 0:
		message = text

func _assign_builder(building: Dictionary, worker_id: int) -> void:
	var worker: Dictionary = entities[worker_id]
	if str(worker.order) in ["gather", "return"]:
		worker["gather_target"] = int(worker.target)
	building["builder"] = worker_id
	worker["order"] = "construct"
	worker["target"] = int(building.id)
	_clear_path(worker)

func _resume_harvesting(worker: Dictionary) -> void:
	var patch: int = int(worker.gather_target)
	if patch < 0 or patch >= deposits.size() or float(deposits[patch].amount) < 1.0 or not is_visible(int(worker.owner), deposits[patch].pos):
		patch = _nearest_patch(int(worker.owner), worker.pos)
	worker["target"] = patch
	worker["gather_target"] = patch
	worker["order"] = "return" if float(worker.cargo) >= CARRY_CAPACITY - 0.001 else "gather"
	_clear_path(worker)

func _available_worker(owner: int, pos: Vector2, idle_only: bool) -> int:
	var best: int = -1
	var distance: float = INF
	for e: Dictionary in entities.values():
		if int(e.owner) != owner or str(e.kind) != "worker" or str(e.order) == "construct":
			continue
		if idle_only and str(e.order) not in ["idle", "hold"]:
			continue
		var d: float = pos.distance_squared_to(e.pos)
		if d < distance:
			best = int(e.id)
			distance = d
	return best

func _has_building(owner: int, kind: String) -> bool:
	for e: Dictionary in entities.values():
		if int(e.owner) == owner and str(e.kind) == kind and bool(e.completed) and float(e.hp) > 0.0:
			return true
	return false

func has_requirements(owner: int, kind: String) -> bool:
	for requirement: String in DATA.requirements(kind, faction_for(owner)):
		if not _has_building(owner, requirement):
			return false
	return true

func can_produce(building: int, kind: String) -> bool:
	if not entities.has(building) or match_state != "playing":
		return false
	var e: Dictionary = entities[building]
	if not bool(e.completed) or float(e.hp) <= 0.0:
		return false
	return DATA.UNIT_PRODUCERS.get(kind, "") == str(e.kind) and has_requirements(int(e.owner), kind)

func queue_unit(building: int, kind: String, payment: String = "essence") -> bool:
	if not can_produce(building, kind) or payment != "essence":
		return false
	var e: Dictionary = entities[building]
	var owner: int = int(e.owner)
	var cost: int = int(spec_for(kind, owner).cost)
	if int(resources[owner].essence) < cost:
		_notify(owner, "Not enough Spiritual Essence.")
		_player_notice(owner, "insufficient_essence", e)
		return false
	resources[owner]["essence"] = int(resources[owner].essence) - cost
	e.queue.append({"kind": kind, "payment": payment, "cost": cost, "remaining": float(spec_for(kind, owner).time), "total": float(spec_for(kind, owner).time)})
	_notify(owner, entity_title(kind, owner) + " queued.")
	_player_notice(owner, "production_started", e)
	return true

func cancel_queue(building: int) -> bool:
	if match_state != "playing" or not entities.has(building):
		return false
	var e: Dictionary = entities[building]
	if e.queue.is_empty():
		return false
	var item: Dictionary = e.queue.pop_back()
	if e.queue.is_empty():
		_blocked_production.erase(building)
	resources[int(e.owner)]["essence"] = int(resources[int(e.owner)].essence) + int(item.cost)
	_notify(int(e.owner), "Last queued unit cancelled; full Essence refund.")
	_player_notice(int(e.owner), "training_cancelled", e)
	return true

func can_sell(owner: int, building: int) -> bool:
	if match_state != "playing" or owner < 0 or owner >= resources.size() or not entities.has(building):
		return false
	var e: Dictionary = entities[building]
	return int(e.owner) == owner and float(e.hp) > 0.0 and bool(entity_spec(e).building)

func can_repair(owner: int, building: int) -> bool:
	if not can_sell(owner, building):
		return false
	var e: Dictionary = entities[building]
	return bool(e.completed) and float(e.hp) < float(e.maxhp)

func toggle_repair(owner: int, building: int) -> bool:
	if not can_repair(owner, building):
		return false
	var e: Dictionary = entities[building]
	e["repairing"] = not bool(e.repairing)
	e["repair_progress"] = 0.0
	_notify(owner, entity_title(str(e.kind), owner) + (" repair started; spends Essence over time." if bool(e.repairing) else " repair stopped."))
	return true

func _repair(e: Dictionary, dt: float) -> void:
	if not bool(e.repairing):
		return
	if float(e.hp) >= float(e.maxhp):
		e["repairing"] = false
		e["repair_progress"] = 0.0
		return
	var owner: int = int(e.owner)
	if int(resources[owner].essence) <= 0:
		return
	var price: float = float(entity_spec(e).cost) * REPAIR_COST_FRACTION
	e["repair_progress"] = float(e.repair_progress) + dt * REPAIR_RATE * price
	while float(e.repair_progress) >= 1.0 - 0.000001 and int(resources[owner].essence) > 0:
		resources[owner]["essence"] = int(resources[owner].essence) - 1
		e["repair_progress"] = maxf(0.0, float(e.repair_progress) - 1.0)
		e["hp"] = minf(float(e.maxhp), float(e.hp) + float(e.maxhp) / price)
		if float(e.hp) >= float(e.maxhp) - 0.000001:
			e["hp"] = float(e.maxhp)
			e["repairing"] = false
			e["repair_progress"] = 0.0
			break

func sell_refund(owner: int, building: int) -> int:
	if not can_sell(owner, building):
		return 0
	var e: Dictionary = entities[building]
	return floori(float(entity_spec(e).cost) * SELL_FRACTION * clampf(float(e.hp) / float(e.maxhp), 0.0, 1.0) + 0.000001)

func sell_building(owner: int, building: int) -> bool:
	if not can_sell(owner, building):
		return false
	var e: Dictionary = entities[building]
	var refund: int = sell_refund(owner, building)
	for item: Dictionary in e.queue:
		refund += int(item.cost)
	e.queue.clear()
	for worker: Dictionary in entities.values():
		if int(worker.owner) == owner and str(worker.kind) == "worker" and str(worker.order) == "construct" and int(worker.target) == building:
			_resume_harvesting(worker)
	_blocked_production.erase(building)
	entities.erase(building)
	_rebuild_navigation()
	_rebuild_buckets()
	_update_fog()
	resources[owner]["essence"] = int(resources[owner].essence) + refund
	_notify(owner, entity_title(str(e.kind), owner) + " sold; %d Essence refunded." % refund)
	_check_match_end()
	return true

func power(owner: int) -> Dictionary:
	var produced: int = 0
	var used: int = 0
	for e: Dictionary in entities.values():
		if int(e.owner) != owner or not bool(e.completed) or float(e.hp) <= 0.0:
			continue
		var definition: Dictionary = entity_spec(e)
		produced += int(definition.get("power_supply", DATA.POWER_SUPPLY.get(str(e.kind), 0)))
		used += int(definition.get("power_demand", DATA.POWER_DEMAND.get(str(e.kind), 0)))
	return {"produced": produced, "used": used}

func _construct(e: Dictionary, dt: float) -> void:
	var builder_id: int = int(e.builder)
	if not entities.has(builder_id) or str(entities[builder_id].order) != "construct" or int(entities[builder_id].target) != int(e.id):
		var builder_lost: bool = not entities.has(builder_id)
		builder_id = _available_worker(int(e.owner), e.pos, not builder_lost)
		e["builder"] = builder_id
		if builder_id >= 0:
			_assign_builder(e, builder_id)
	if builder_id < 0 or not entities.has(builder_id):
		return
	var builder: Dictionary = entities[builder_id]
	var half: Vector2 = Vector2(entity_spec(e).size) * 0.5
	var closest: Vector2 = Vector2(builder.pos).clamp(Vector2(e.pos) - half, Vector2(e.pos) + half)
	if Vector2(builder.pos).distance_to(closest) > float(builder.radius) + 18.0:
		return
	var progress: float = minf(1.0, float(e.build_progress) + dt / float(entity_spec(e).time))
	var added_hp: float = (progress - float(e.build_progress)) * float(e.maxhp) * 0.9
	e["build_progress"] = progress
	e["hp"] = minf(float(e.maxhp), float(e.hp) + added_hp)
	if progress >= 1.0:
		e["completed"] = true
		_resume_harvesting(builder)
		_notify(int(e.owner), entity_title(str(e.kind), int(e.owner)) + " ready.")
		_player_notice(int(e.owner), "building_constructed", e)

func _produce(e: Dictionary, dt: float) -> void:
	if e.queue.is_empty():
		_blocked_production.erase(int(e.id))
		return
	var item: Dictionary = e.queue[0]
	var electricity: Dictionary = power(int(e.owner))
	var rate: float = 0.5 if int(electricity.used) > int(electricity.produced) else 1.0
	item["remaining"] = maxf(0.0, float(item.remaining) - dt * rate)
	if float(item.remaining) > 0.0:
		return
	var exit: Vector2 = _find_exit(e, float(spec_for(str(item.kind), int(e.owner)).radius))
	if exit.x < 0.0:
		if not is_same(_blocked_production.get(int(e.id)), item):
			_blocked_production[int(e.id)] = item
			_player_notice(int(e.owner), "exit_blocked", e)
		return
	_blocked_production.erase(int(e.id))
	var unit: Dictionary = _spawn(str(item.kind), int(e.owner), exit)
	e.queue.pop_front()
	if str(unit.kind) == "worker":
		var patch: int = _nearest_patch(int(e.owner), exit)
		if patch >= 0:
			unit["order"] = "gather"
			unit["target"] = patch
	else:
		unit["order"] = "move"
		unit["goal"] = e.rally
	_player_notice(int(unit.owner), "unit_ready", unit)

func _find_exit(e: Dictionary, radius: float) -> Vector2:
	var half: Vector2 = Vector2(entity_spec(e).size) * 0.5 + Vector2(radius + 14, radius + 14)
	for ring: int in range(3):
		for i: int in range(16):
			var angle: float = TAU * float(i) / 16.0
			var pos: Vector2 = Vector2(e.pos) + Vector2(cos(angle) * (half.x + ring * 24), sin(angle) * (half.y + ring * 24))
			if not _walkable(pos, radius):
				continue
			var clear: bool = true
			for other: Dictionary in _nearby(pos, radius + 40.0):
				if int(other.id) != int(e.id) and not bool(entity_spec(other).building) and pos.distance_to(other.pos) < radius + float(other.radius) + 3.0:
					clear = false
					break
			if clear:
				return pos
	return Vector2(-1, -1)

func _worker(e: Dictionary, dt: float) -> void:
	match str(e.order):
		"move", "attack_move":
			if _move_towards(e, e.goal, dt):
				e["order"] = "idle"
		"construct":
			if not entities.has(int(e.target)) or bool(entities[int(e.target)].completed):
				e["order"] = "idle"
			else:
				var building: Dictionary = entities[int(e.target)]
				var half: Vector2 = Vector2(entity_spec(building).size) * 0.5
				var near: Vector2 = Vector2(e.pos).clamp(Vector2(building.pos) - half, Vector2(building.pos) + half)
				if Vector2(e.pos).distance_to(near) > float(e.radius) + 16.0:
					_move_towards(e, _approach_building(e, building), dt, 3.0)
		"gather", "return":
			_gather(e, dt)

func _gather(e: Dictionary, dt: float) -> void:
	if float(e.cargo) >= CARRY_CAPACITY - 0.001 or str(e.order) == "return":
		e["order"] = "return"
		var dropoff: int = _nearest_dropoff(int(e.owner), e.pos)
		if dropoff < 0:
			return
		var base: Dictionary = entities[dropoff]
		var half: Vector2 = Vector2(entity_spec(base).size) * 0.5
		var near: Vector2 = Vector2(e.pos).clamp(Vector2(base.pos) - half, Vector2(base.pos) + half)
		if Vector2(e.pos).distance_to(near) <= float(e.radius) + 19.0:
			var delivery: int = int(floor(float(e.cargo)))
			resources[int(e.owner)]["essence"] = int(resources[int(e.owner)].essence) + delivery
			e["cargo"] = float(e.cargo) - float(delivery)
			e["order"] = "gather"
			_clear_path(e)
		else:
			_move_towards(e, _approach_building(e, base), dt, 3.0)
		return
	var patch_id: int = int(e.target)
	if patch_id < 0 or patch_id >= deposits.size():
		patch_id = _nearest_patch(int(e.owner), e.pos)
		e["target"] = patch_id
	if patch_id < 0:
		return
	var patch: Dictionary = deposits[patch_id]
	if float(patch.amount) < 1.0:
		var replacement: int = _nearest_patch(int(e.owner), e.pos, patch_id)
		if replacement >= 0:
			e["target"] = replacement
			_clear_path(e)
		elif float(e.cargo) >= 1.0:
			e["order"] = "return"
		return
	if Vector2(e.pos).distance_to(patch.pos) > 26.0:
		_move_towards(e, patch.pos, dt)
		return
	var harvested: float = minf(HARVEST_RATE * dt, minf(float(patch.amount), CARRY_CAPACITY - float(e.cargo)))
	patch["amount"] = float(patch.amount) - harvested
	e["cargo"] = float(e.cargo) + harvested

func _nearest_patch(owner: int, pos: Vector2, exclude: int = -1) -> int:
	var best: int = -1
	var distance: float = INF
	for patch: Dictionary in deposits:
		if int(patch.id) == exclude or float(patch.amount) < 1.0 or not is_visible(owner, patch.pos):
			continue
		var d: float = pos.distance_squared_to(patch.pos)
		if d < distance:
			distance = d
			best = int(patch.id)
	return best

func _nearest_dropoff(owner: int, pos: Vector2) -> int:
	var best: int = -1
	var distance: float = INF
	for e: Dictionary in entities.values():
		if int(e.owner) != owner or not bool(e.completed) or str(e.kind) not in ["hq", "refinery"] or float(e.hp) <= 0.0:
			continue
		var d: float = pos.distance_squared_to(e.pos)
		if d < distance:
			distance = d
			best = int(e.id)
	return best

func _approach_building(unit: Dictionary, building: Dictionary) -> Vector2:
	var half: Vector2 = Vector2(entity_spec(building).size) * 0.5
	var near: Vector2 = Vector2(unit.pos).clamp(Vector2(building.pos) - half, Vector2(building.pos) + half)
	var outward: Vector2 = (Vector2(unit.pos) - near).normalized()
	if outward == Vector2.ZERO:
		outward = Vector2.DOWN
	return near + outward * ((float(unit.radius) + 3.0) / maxf(absf(outward.x), absf(outward.y)))

func _ability_active(e: Dictionary) -> bool:
	if float(e.hp) <= 0.0 or not bool(e.completed):
		return false
	var definition: Dictionary = entity_spec(e)
	if bool(definition.building) and int(definition.get("power_demand", DATA.POWER_DEMAND.get(str(e.kind), 0))) > 0:
		var electricity: Dictionary = power(int(e.owner))
		return int(electricity.used) <= int(electricity.produced)
	return true

func _regenerate(e: Dictionary, dt: float) -> void:
	var rate: float = float(entity_spec(e).get("regen", 0.0))
	if rate > 0.0 and elapsed - float(e.get("last_damage_at", -99.0)) >= 3.0 and float(e.hp) > 0.0 and bool(e.completed):
		e["hp"] = minf(float(e.maxhp), float(e.hp) + rate * dt)

func _support_target(e: Dictionary) -> Dictionary:
	var definition: Dictionary = entity_spec(e)
	var reach: float = float(definition.get("heal_range", 0.0))
	var target: Dictionary = {}
	var lowest: float = 1.0
	for ally: Dictionary in _nearby(e.pos, reach + 32.0):
		if int(ally.id) == int(e.id) or int(ally.owner) != int(e.owner) or not bool(ally.completed) or float(ally.hp) <= 0.0:
			continue
		if bool(entity_spec(ally).building) != bool(definition.get("repair", false)):
			continue
		var fraction: float = float(ally.hp) / float(ally.maxhp)
		if fraction < lowest and Vector2(ally.pos).distance_squared_to(e.pos) <= reach * reach:
			lowest = fraction
			target = ally
	return target

func _support(e: Dictionary, dt: float) -> void:
	var rate: float = float(entity_spec(e).get("heal", 0.0))
	if rate <= 0.0:
		return
	var target: Dictionary = _support_target(e)
	if not target.is_empty():
		target["hp"] = minf(float(target.maxhp), float(target.hp) + rate * dt)

func _ward_armor(target: Dictionary) -> float:
	var best: float = 0.0
	for ally: Dictionary in _nearby(target.pos, 632.0):
		if int(ally.owner) != int(target.owner) or float(ally.hp) <= 0.0 or not bool(ally.completed):
			continue
		var definition: Dictionary = entity_spec(ally)
		var ward: float = float(definition.get("ward", 0.0))
		if ward <= best:
			continue
		var reach: float = float(definition.get("ward_range", 0.0))
		if Vector2(ally.pos).distance_squared_to(target.pos) <= reach * reach and _ability_active(ally):
			best = ward
	return best

func damage_for(attacker: Dictionary, target: Dictionary) -> float:
	var definition: Dictionary = entity_spec(attacker)
	var defense: Dictionary = entity_spec(target)
	var target_class: String = str(defense.get("class", "structure" if bool(defense.building) else ("heavy" if str(target.kind) == "tank" else "light")))
	var bonuses: Dictionary = definition.get("bonuses", {})
	var armor: float = maxf(0.0, float(defense.armor) + _ward_armor(target) - float(definition.get("pierce", 0.0)))
	return maxf(1.0, float(definition.damage) * float(bonuses.get(target_class, 1.0)) - armor)

func _hit(attacker: Dictionary, target: Dictionary) -> void:
	if float(target.hp) <= 0.0 or not can_see_entity(int(attacker.owner), target):
		return
	var definition: Dictionary = entity_spec(attacker)
	var damage: float = damage_for(attacker, target)
	var removed: float = minf(float(target.hp), damage)
	target["hp"] = float(target.hp) - damage
	target["last_damage_at"] = elapsed
	var factor: float = float(definition.get("slow", 1.0))
	var duration: float = float(definition.get("slow_time", 0.0))
	if factor < 1.0 and duration > 0.0 and not bool(entity_spec(target).building):
		var slows: Dictionary = target.get("slows", {})
		slows[factor] = maxf(float(slows.get(factor, -1.0)), elapsed + duration)
		target["slows"] = slows
		_movement_factor(target)
	var drain: float = float(definition.get("lifesteal", 0.0))
	if drain > 0.0 and float(attacker.hp) > 0.0:
		attacker["hp"] = minf(float(attacker.maxhp), float(attacker.hp) + removed * drain)
	_player_notice(int(target.owner), "building_under_attack" if bool(entity_spec(target).building) else "unit_under_attack", target)

func _movement_factor(e: Dictionary) -> float:
	var slows: Dictionary = e.get("slows", {})
	var factor: float = 1.0
	var until: float = -1.0
	for value: float in slows.keys():
		if elapsed >= float(slows[value]):
			slows.erase(value)
		elif value < factor:
			factor = value
			until = float(slows[value])
	e["slow_factor"] = factor
	e["slow_until"] = until
	return factor

func _combat_unit(e: Dictionary, dt: float) -> void:
	var definition: Dictionary = entity_spec(e)
	var stationary: bool = bool(definition.building)
	if float(definition.damage) <= 0.0:
		e["target"] = -1
		var supporting: bool = str(e.order) == "attack_move" and not _support_target(e).is_empty()
		if not stationary and not supporting and str(e.order) in ["move", "attack_move"] and _move_towards(e, e.goal, dt):
			e["order"] = "idle"
		return
	var target: int = int(e.target)
	var ordered_attack: bool = str(e.order) == "attack"
	var may_fight: bool = str(e.order) != "move"
	var hold: bool = stationary or str(e.order) == "hold"
	if not entities.has(target) or (entities.has(target) and (int(entities[target].owner) == int(e.owner) or float(entities[target].hp) <= 0.0 or not can_see_entity(int(e.owner), entities[target]))):
		target = -1
		if ordered_attack:
			e["order"] = "attack_move"
	if may_fight and target < 0:
		target = _find_enemy(e, float(definition.range) + (0.0 if hold else 100.0))
	if may_fight and target >= 0:
		var enemy: Dictionary = entities[target]
		e["target"] = target
		var delta: Vector2 = Vector2(enemy.pos) - Vector2(e.pos)
		e["facing"] = delta.normalized()
		if ordered_attack:
			e["goal"] = enemy.pos
		if delta.length() < float(definition.get("min_range", 0.0)):
			if not hold:
				var retreat: Vector2 = (Vector2(e.pos) - delta.normalized() * (float(definition.min_range) - delta.length() + 30.0)).clamp(Vector2(24, 24), map_size - Vector2(24, 24))
				_move_towards(e, retreat, dt)
		elif delta.length() <= float(definition.range) + float(enemy.radius):
			if float(e.cooldown_left) <= 0.0:
				_hit(e, enemy)
				var splash: float = float(definition.get("splash", 0.0))
				if splash > 0.0:
					for other: Dictionary in _nearby(enemy.pos, splash + 32.0):
						if int(other.id) != int(enemy.id) and int(other.owner) != int(e.owner) and Vector2(other.pos).distance_squared_to(enemy.pos) <= splash * splash:
							_hit(e, other)
				e["cooldown_left"] = float(definition.cooldown)
				effects.append({"a": e.pos, "b": enemy.pos, "ttl": 0.24 if str(definition.get("class", "")) == "heavy" or str(e.kind) == "tank" else 0.12, "owner": int(e.owner), "tank": str(definition.get("class", "")) == "heavy" or str(e.kind) == "tank", "splash": splash, "visible_to_player": can_see_entity(0, e)})
				weapon_fired.emit(e, Vector2(enemy.pos))
		elif not hold:
			_move_towards(e, enemy.pos, dt)
		return
	e["target"] = -1
	if not stationary and str(e.order) in ["move", "attack_move", "attack"]:
		if _move_towards(e, e.goal, dt):
			e["order"] = "idle"

func _find_enemy(e: Dictionary, search: float) -> int:
	var best: int = -1
	var distance: float = INF
	for other: Dictionary in _nearby(e.pos, search + 80.0):
		if int(other.owner) == int(e.owner) or float(other.hp) <= 0.0 or not can_see_entity(int(e.owner), other):
			continue
		var d: float = Vector2(e.pos).distance_squared_to(other.pos)
		if d < distance and d <= pow(search + float(other.radius), 2.0):
			distance = d
			best = int(other.id)
	return best

func _rebuild_buckets() -> void:
	_buckets.clear()
	for e: Dictionary in entities.values():
		var key: Vector2i = Vector2i(floor(Vector2(e.pos).x / BUCKET_SIZE), floor(Vector2(e.pos).y / BUCKET_SIZE))
		if not _buckets.has(key):
			_buckets[key] = []
		_buckets[key].append(int(e.id))

func _nearby(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var begin: Vector2i = Vector2i(floor((pos.x - radius) / BUCKET_SIZE), floor((pos.y - radius) / BUCKET_SIZE))
	var end: Vector2i = Vector2i(floor((pos.x + radius) / BUCKET_SIZE), floor((pos.y + radius) / BUCKET_SIZE))
	for y: int in range(begin.y, end.y + 1):
		for x: int in range(begin.x, end.x + 1):
			for id: int in _buckets.get(Vector2i(x, y), []):
				if entities.has(id):
					result.append(entities[id])
	return result

func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / float(DATA.CELL_SIZE)), floor(pos.y / float(DATA.CELL_SIZE)))

func is_visible(owner: int, pos: Vector2) -> bool:
	return owner >= 0 and owner < 2 and visible[owner].has(_cell(pos))

func can_see_entity(owner: int, entity: Dictionary) -> bool:
	if owner < 0 or owner > 1:
		return false
	return int(entity.owner) == owner or is_visible(owner, entity.pos)

func _update_fog() -> void:
	visible = [{}, {}]
	for e: Dictionary in entities.values():
		if float(e.hp) <= 0.0:
			continue
		var sight: float = float(entity_spec(e).sight)
		if not bool(e.completed):
			sight = 96.0
		var cell: Vector2i = _cell(e.pos)
		var extent: int = int(ceil(sight / float(DATA.CELL_SIZE)))
		for y: int in range(maxi(0, cell.y - extent), mini(int(map_size.y / DATA.CELL_SIZE), cell.y + extent + 1)):
			for x: int in range(maxi(0, cell.x - extent), mini(int(map_size.x / DATA.CELL_SIZE), cell.x + extent + 1)):
				var point: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * float(DATA.CELL_SIZE)
				if point.distance_squared_to(e.pos) <= sight * sight:
					var key: Vector2i = Vector2i(x, y)
					visible[int(e.owner)][key] = true
					explored[int(e.owner)][key] = true

func _rebuild_navigation() -> void:
	_solid_rects.clear()
	_solid_rects.append_array(obstacles)
	for e: Dictionary in entities.values():
		var definition: Dictionary = entity_spec(e)
		if bool(definition.building) and float(e.hp) > 0.0:
			_solid_rects.append(Rect2(Vector2(e.pos) - Vector2(definition.size) * 0.5, definition.size))
	_grid.region = Rect2i(Vector2i.ZERO, Vector2i(map_size / DATA.CELL_SIZE))
	_grid.cell_size = Vector2(DATA.CELL_SIZE, DATA.CELL_SIZE)
	_grid.offset = Vector2(16, 16)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for y: int in range(_grid.region.size.y):
		for x: int in range(_grid.region.size.x):
			var pos: Vector2 = Vector2(x * 32 + 16, y * 32 + 16)
			_grid.set_point_solid(Vector2i(x, y), not _walkable(pos, 18.0))
	_navigation_version += 1

func _walkable(pos: Vector2, radius: float) -> bool:
	if pos.x < radius or pos.y < radius or pos.x > map_size.x - radius or pos.y > map_size.y - radius:
		return false
	for obstacle: Rect2 in _solid_rects:
		if obstacle.grow(radius).has_point(pos):
			return false
	return true

func _free_cell(cell: Vector2i) -> Vector2i:
	var clamped: Vector2i = Vector2i(clampi(cell.x, 0, _grid.region.size.x - 1), clampi(cell.y, 0, _grid.region.size.y - 1))
	if not _grid.is_point_solid(clamped):
		return clamped
	for ring: int in range(1, 10):
		for y: int in range(clamped.y - ring, clamped.y + ring + 1):
			for x: int in range(clamped.x - ring, clamped.x + ring + 1):
				var candidate: Vector2i = Vector2i(x, y)
				if _grid.is_in_boundsv(candidate) and not _grid.is_point_solid(candidate):
					return candidate
	return Vector2i(-1, -1)

func _clear_path(e: Dictionary) -> void:
	e["path"] = PackedVector2Array()
	e["path_index"] = 0
	e["path_version"] = -1
	e["repath"] = 0.0
	e["path_partial"] = false

func _move_towards(e: Dictionary, goal: Vector2, dt: float, arrival: float = -1.0) -> bool:
	var pos: Vector2 = e.pos
	if pos.distance_to(goal) <= (12.0 if arrival < 0.0 else arrival):
		return true
	var changed: bool = Vector2(e.path_goal).distance_squared_to(goal) > 48.0 * 48.0
	if int(e.path_version) != _navigation_version or (changed and float(e.repath) <= 0.0) or (e.path.is_empty() and float(e.repath) <= 0.0):
		var start: Vector2i = _free_cell(_cell(pos))
		var end: Vector2i = _free_cell(_cell(goal))
		if start.x < 0 or end.x < 0:
			e["repath"] = 1.0
			_notify(int(e.owner), "Destination unreachable.")
			return true
		var path: PackedVector2Array = _grid.get_point_path(start, end, true)
		e["path"] = path
		e["path_index"] = 1 if path.size() > 1 else 0
		e["path_goal"] = goal
		e["path_version"] = _navigation_version
		e["path_partial"] = path.is_empty() or _cell(path[path.size() - 1]) != end
		e["repath"] = 0.8
	var path: PackedVector2Array = e.path
	var index: int = int(e.path_index)
	while index < path.size() and pos.distance_to(path[index]) <= 14.0:
		index += 1
	e["path_index"] = index
	var destination: Vector2 = goal
	if index < path.size():
		destination = path[index]
	elif bool(e.get("path_partial", false)):
		_notify(int(e.owner), "Destination unreachable.")
		return true
	elif not _walkable(goal, float(e.radius)):
		return true
	var direction: Vector2 = (destination - pos).normalized()
	var separation: Vector2 = Vector2.ZERO
	for other: Dictionary in _nearby(pos, 54.0):
		if int(other.id) == int(e.id) or bool(entity_spec(other).building):
			continue
		var delta: Vector2 = pos - Vector2(other.pos)
		var required: float = float(e.radius) + float(other.radius) + 3.0
		var distance: float = delta.length()
		if distance < required:
			if distance < 0.01:
				delta = Vector2.from_angle(float(int(e.id) % 17) * 0.37)
				distance = 0.01
			separation += delta.normalized() * (required - distance) / required
	var slow: float = _movement_factor(e)
	var velocity: Vector2 = (direction + separation * 1.5).limit_length(1.0) * float(entity_spec(e).speed) * slow
	var next: Vector2 = pos + velocity * dt
	if _walkable(next, float(e.radius)):
		e["pos"] = next
	elif _walkable(Vector2(next.x, pos.y), float(e.radius)):
		e["pos"] = Vector2(next.x, pos.y)
	elif _walkable(Vector2(pos.x, next.y), float(e.radius)):
		e["pos"] = Vector2(pos.x, next.y)
	else:
		e["path_version"] = -1
	e["facing"] = direction
	return Vector2(e.pos).distance_to(goal) <= (14.0 if arrival < 0.0 else arrival)

func _ai_expansion_choice() -> String:
	if elapsed < 60.0 or not _has_building(1, "factory"):
		return ""
	var plan: Array[String] = ["workshop", "reactor", "sanctum", "arsenal", "outpost", "sentry", "bastion", "relay"]
	for index: int in range(plan.size()):
		var kind: String = plan[index]
		var present: bool = false
		for entity: Dictionary in entities.values():
			if int(entity.owner) == 1 and str(entity.kind) == kind and float(entity.hp) > 0.0:
				present = true
				if not bool(entity.completed):
					return ""
		if not present:
			return kind if elapsed >= 60.0 + index * 10.0 and has_requirements(1, kind) else ""
	return ""

func _ai_unit_choice(producer: Dictionary) -> String:
	if elapsed < 60.0:
		return str({"barracks": "infantry", "factory": "tank"}.get(str(producer.kind), ""))
	var counts: Dictionary = {}
	var targets: Dictionary = {"light": 0, "heavy": 0, "structure": 0}
	for entity: Dictionary in entities.values():
		if int(entity.owner) == 1:
			counts[str(entity.kind)] = int(counts.get(str(entity.kind), 0)) + 1
			for item: Dictionary in entity.queue:
				counts[str(item.kind)] = int(counts.get(str(item.kind), 0)) + 1
		elif float(entity.hp) > 0.0 and can_see_entity(1, entity):
			var target_class: String = str(entity_spec(entity).get("class", "structure" if bool(entity_spec(entity).building) else ("heavy" if str(entity.kind) == "tank" else "light")))
			targets[target_class] = int(targets.get(target_class, 0)) + 1
	var dominant: String = "light" if int(targets.light) >= int(targets.heavy) else "heavy"
	var best: String = ""
	var score: float = -INF
	for kind: String in DATA.UNIT_KINDS:
		if kind == "worker" or not can_produce(int(producer.id), kind):
			continue
		var definition: Dictionary = spec_for(kind, 1)
		var bonuses: Dictionary = definition.get("bonuses", {})
		var benefit: float = float(bonuses.get(dominant, 1.0))
		if float(definition.get("heal", 0.0)) > 0.0 or float(definition.get("ward", 0.0)) > 0.0:
			benefit = 0.85
		var candidate: float = benefit / (1.0 + float(counts.get(kind, 0)))
		if candidate > score:
			score = candidate
			best = kind
	return best

func _ai_tick() -> void:
	var profile: Dictionary = AI_PROFILES[ai_difficulty]
	for e: Dictionary in entities.values():
		if int(e.owner) == 0 and can_see_entity(1, e):
			_ai_enemy_memory[int(e.id)] = {"pos": e.pos, "kind": e.kind}
	var army: Array = []
	var worker_count: int = 0
	var has_barracks: bool = false
	var has_factory: bool = false
	var base: Vector2 = map_size - Vector2(320, 320)
	var expansion: String = _ai_expansion_choice()
	var reserve: int = int(spec_for(expansion, 1).cost) if not expansion.is_empty() else 0
	for e: Dictionary in entities.values():
		if int(e.owner) == 1 and str(e.kind) == "worker":
			worker_count += 1
	for e: Dictionary in entities.values():
		if int(e.owner) != 1:
			continue
		var definition: Dictionary = entity_spec(e)
		if str(e.kind) == "worker":
			if str(e.order) == "idle":
				var patch: int = _nearest_patch(1, e.pos)
				if patch >= 0:
					order_gather([int(e.id)], patch)
		elif not bool(definition.building) and not bool(definition.get("repair", false)):
			army.append(int(e.id))
		if str(e.kind) == "barracks": has_barracks = true
		if str(e.kind) == "factory": has_factory = true
		if not bool(e.completed) or not e.queue.is_empty():
			continue
		if str(e.kind) == "hq" and worker_count < int(profile.worker_target):
			queue_unit(int(e.id), "worker")
		elif bool(definition.building) and elapsed < 60.0:
			var choice: String = _ai_unit_choice(e)
			if not choice.is_empty() and int(resources[1].essence) - int(spec_for(choice, 1).cost) >= reserve:
				queue_unit(int(e.id), choice)
	if elapsed >= 60.0:
		var oldest: Dictionary = {}
		var next_kind: String = ""
		for producer: Dictionary in entities.values():
			if int(producer.owner) != 1 or not bool(producer.completed) or float(producer.hp) <= 0.0 or not producer.queue.is_empty():
				continue
			var choice: String = _ai_unit_choice(producer)
			if choice.is_empty():
				continue
			if oldest.is_empty() or float(producer.get("ai_trained_at", -99.0)) < float(oldest.get("ai_trained_at", -99.0)):
				oldest = producer
				next_kind = choice
		if not oldest.is_empty() and int(resources[1].essence) - int(spec_for(next_kind, 1).cost) >= reserve:
			if queue_unit(int(oldest.id), next_kind):
				oldest["ai_trained_at"] = elapsed
	if not has_barracks:
		_ai_build("barracks", base)
	elif not has_factory and _has_building(1, "barracks"):
		_ai_build("factory", base)
	elif not expansion.is_empty():
		_ai_build(expansion, base)
	var electricity: Dictionary = power(1)
	if int(electricity.used) > int(electricity.produced):
		_ai_build("power", base)
	if elapsed < float(profile.first_attack) or army.is_empty() or elapsed < _attack_timer:
		return
	_attack_timer = elapsed + float(profile.attack_interval)
	var target_pos: Vector2 = Vector2(320, 320)
	var found: bool = false
	for remembered: Dictionary in _ai_enemy_memory.values():
		if str(remembered.kind) == "hq":
			target_pos = remembered.pos
			found = true
			break
	if not found:
		var route: Array[Vector2] = [Vector2(2150, 1350), Vector2(1700, 1200), Vector2(1200, 700), Vector2(700, 500), Vector2(320, 320)]
		target_pos = route[mini(_ai_scout_step, route.size() - 1)]
		if _ai_scout_step < route.size() - 1:
			target_pos *= map_size / DATA.MAP_SIZE
		_ai_scout_step += 1
	order_move(army, target_pos, true)

func _ai_build(kind: String, base: Vector2) -> void:
	for row: int in range(4):
		for column: int in range(4):
			var pos: Vector2 = base - Vector2(140 + column * 150, -130 + row * 135)
			if can_build(1, kind, pos):
				start_build(1, kind, pos)
				return
