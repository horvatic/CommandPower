extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const MAPS = preload("res://scripts/skirmish_maps.gd")
const PROJ = preload("res://scripts/projection.gd")
const VIEW = preload("res://scripts/battlefield_view.gd")
const RADAR = preload("res://scripts/minimap.gd")
const DATA = preload("res://scripts/catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _find(world: Variant, owner: int, kind: String) -> Dictionary:
	for entity: Dictionary in world.entities.values():
		if entity.owner == owner and entity.kind == kind:
			return entity
	return {}

func _run() -> void:
	var original: Variant = SIM.new()
	_check(original.map_id == "silent_wells" and original.map_size == DATA.MAP_SIZE, "Original map must remain the default")
	_check(original.obstacles == MAPS.MAPS.silent_wells.obstacles and original.wells[0].pos == Vector2(650, 540), "Original obstacles and wells must remain unchanged")
	_check(not original.configure_map("missing") and original.map_id == "silent_wells", "Invalid maps must leave configuration unchanged")
	_check(not original.configure_colors(SIM.PLAYER_COLORS[0], SIM.PLAYER_COLORS[0]), "Identical player colors must be rejected")
	_check(not original.configure_colors(Color.BLACK, SIM.PLAYER_COLORS[1]), "Colors outside the selectable palette must be rejected")
	var view: Variant = VIEW.new()
	view.world = original
	root.add_child(view)
	var radar: Variant = RADAR.new()
	radar.size = Vector2(280, 140)
	radar.world = original
	root.add_child(radar)
	await process_frame
	for id: String in MAPS.MAPS:
		var world: Variant = SIM.new()
		_check(world.configure_map(id), "Each catalog map must be selectable: " + id)
		_check(world.configure_skirmish("humans", "humans") and world.configure_colors(SIM.PLAYER_COLORS[2], SIM.PLAYER_COLORS[4]), "Mirror factions must allow independent player colors")
		world.reset()
		view.world = world
		radar.world = world
		var layout: Dictionary = MAPS.MAPS[id]
		var dimensions := Vector2i(world.map_size / DATA.CELL_SIZE)
		_check(world.map_size == layout.size and world._grid.region.size == dimensions, "Navigation grid must cover the selected map")
		_check(world.entities.size() == 16 and world.resources == [{"essence": 900}, {"essence": 900}], "All maps must preserve starting armies and essence")
		_check(world.wells.size() == layout.wells.size() and world.deposits.size() == layout.wells.size() * 8, "Every map well must have eight harvestable patches")
		_check(_find(world, 0, "hq").pos == Vector2(320, 320) and _find(world, 1, "hq").pos == world.map_size - Vector2(320, 320), "Map bases must use opposite corner starts")
		for entity: Dictionary in world.entities.values():
			_check(entity.team_color == world.color_for(entity.owner), "Starting entities must inherit their commander color")
			if not bool(world.entity_spec(entity).building):
				_check(world._walkable(entity.pos, entity.radius), "Starting units must occupy free ground")
		for patch: Dictionary in world.deposits:
			_check(world._walkable(patch.pos, 10), "Harvestable growth must be in bounds on walkable ground: " + id + " " + str(patch.pos))
		for owner: int in range(2):
			for tile: Vector2i in world.visible[owner]:
				_check(tile.x >= 0 and tile.y >= 0 and tile.x < dimensions.x and tile.y < dimensions.y, "Fog cells must stay inside the selected map")
		var start: Vector2i = world._free_cell(Vector2i(24, 18))
		var end: Vector2i = world._free_cell(dimensions - Vector2i(24, 18))
		var path: PackedVector2Array = world._grid.get_point_path(start, end)
		_check(not path.is_empty() and world._cell(path[-1]) == end, "Both bases must be linked by a navigable path: " + id)
		for well: Dictionary in world.wells:
			var target: Vector2i = world._free_cell(world._cell(well.pos))
			_check(not world._grid.get_point_path(start, target).is_empty(), "Every well must be reachable from either base")
		if id != "silent_wells":
			for well: Dictionary in world.wells:
				_check(layout.wells.has(world.map_size - Vector2(well.pos)), "New maps must have symmetric resource opportunities")
			for obstacle: Rect2 in world.obstacles:
				_check(layout.obstacles.has(Rect2(world.map_size - obstacle.end, obstacle.size)), "New map cliffs must be symmetric")
		for point: Vector2 in [Vector2.ZERO, world.map_size, Vector2(650, 540), world.map_size * 0.5]:
			_check(PROJ.unproject(PROJ.project(point, world.map_size), world.map_size).distance_to(point) < 0.001, "Projection must round-trip selected map coordinates")
			_check(view.screen_to_world(view.world_to_screen(point)).distance_to(point) < 0.001, "Battlefield picking must round-trip coordinates")
			_check(radar.map_local_to_world(radar.map_world_to_local(point)).distance_to(point) < 0.01, "Radar must round-trip selected map coordinates")
		view._create_terrain_cache()
		view._update_fog_cache()
		_check(view._terrain_bounds == PROJ.map_bounds(world.map_size).grow(32) and view._fog_image.get_size() == dimensions, "Terrain and fog caches must resize between maps")
		_check(view._terrain_viewport.size.x <= 8192, "Static terrain caches must fit the texture limit on huge maps")
		var wreck: Dictionary = _find(world, 0, "infantry")
		world._record_destruction(wreck)
		_check(world.destruction_effects[-1].team_color == SIM.PLAYER_COLORS[2], "Destruction snapshots must retain the selected army color")
		var last_cell: Vector2i = dimensions - Vector2i(3, 3)
		var scout: Dictionary = world._spawn("scout", 0, (Vector2(last_cell) + Vector2(0.5, 0.5)) * DATA.CELL_SIZE)
		world._update_fog()
		_check(world.is_visible(0, scout.pos), "Fog must reveal units beyond the original map boundaries")
		world.entities.erase(int(scout.id))
		world.reset()
		_check(world.map_id == id and world.color_for(0) == SIM.PLAYER_COLORS[2] and world.color_for(1) == SIM.PLAYER_COLORS[4], "Reset must retain selected map and colors")
		for tick: int in range(1200):
			world.tick(0.05)
		var ai_workers := 0
		var harvest_started := false
		for entity: Dictionary in world.entities.values():
			if entity.owner == 1 and entity.kind == "worker":
				ai_workers += 1
				_check(entity.team_color == SIM.PLAYER_COLORS[4], "Produced workers must inherit selected color")
		for patch: Dictionary in world.deposits:
			harvest_started = harvest_started or float(patch.amount) < float(patch.capacity)
		_check(ai_workers >= 4 and not _find(world, 1, "barracks").is_empty(), "AI must expand and produce workers on each map: " + id)
		_check(harvest_started, "Workers must harvest normally on every map")
		_check(original.map_size == DATA.MAP_SIZE and original.map_id == "silent_wells", "Configuring another world must not mutate the default instance")
		await process_frame
	view.queue_free()
	radar.queue_free()
	await process_frame
	print("%s: %d skirmish map checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
