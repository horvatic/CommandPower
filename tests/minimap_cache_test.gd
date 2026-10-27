extends SceneTree

const SIM = preload("res://scripts/simulation.gd")
const MAPS = preload("res://scripts/skirmish_maps.gd")
const RADAR = preload("res://scripts/minimap.gd")
const DATA = preload("res://scripts/catalog.gd")
const UNKNOWN := Color("111c23")
const EXPLORED := Color("212e2e")
const VISIBLE := Color("364843")
var checks := 0
var failures := 0
var navigation: Array[Vector2] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _check_cells(radar: Variant, label: String) -> void:
	var dimensions := Vector2i(radar.world.map_size / DATA.CELL_SIZE)
	_check(radar._terrain_image.get_size() == dimensions and Vector2i(radar._terrain_texture.get_size()) == dimensions, "Radar image and GPU texture must cover every map cell: " + label)
	var correct := true
	for y: int in range(dimensions.y):
		for x: int in range(dimensions.x):
			var cell := Vector2i(x, y)
			var expected: Color = UNKNOWN
			if radar.world.explored[0].has(cell):
				expected = VISIBLE if radar.world.visible[0].has(cell) else EXPLORED
			correct = correct and radar._terrain_image.get_pixelv(cell).to_rgba32() == expected.to_rgba32()
	_check(correct, "Every radar texel must obey unexplored/explored/currently visible fog: " + label)

func _check_unchanged(radar: Variant, label: String) -> void:
	var image: Image = radar._terrain_image
	var texture: ImageTexture = radar._terrain_texture
	var revision: int = radar._terrain_revision
	var before: PackedByteArray = image.get_data()
	for frame: int in range(60):
		radar.camera_pos += Vector2(3, 2)
		radar.zoom_level = 0.65 if frame % 2 == 0 else 1.6
		radar._update_terrain_cache()
	_check(radar._terrain_revision == revision, "Unchanged fog must skip all terrain cache rebuilds despite camera and zoom changes: " + label)
	_check(is_same(radar._terrain_image, image) and is_same(radar._terrain_texture, texture) and image.get_data() == before, "Unchanged frames must reuse both radar image and texture: " + label)

func _check_navigation(radar: Variant, label: String) -> void:
	for point: Vector2 in [Vector2(64, 64), radar.world.map_size * 0.5, radar.world.map_size - Vector2(64, 64)]:
		var local: Vector2 = radar.map_world_to_local(point)
		_check(radar.contains_map_point(local) and radar.map_local_to_world(local).distance_to(point) < 0.01, "Cached terrain must preserve radar projection and picking: " + label)
	var destination: Vector2 = radar.world.map_size * Vector2(0.35, 0.6)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = radar.map_world_to_local(destination)
	var previous: int = navigation.size()
	radar._gui_input(click)
	_check(navigation.size() == previous + 1 and navigation[-1].distance_to(destination) < 0.01, "Radar clicks must navigate to the same simulation coordinates: " + label)
	click.position = radar._map_rect().position + Vector2.ONE
	previous = navigation.size()
	radar._gui_input(click)
	_check(navigation.size() == previous, "The radar bounding-box corner outside the diamond must reject navigation: " + label)

func _run() -> void:
	var radar: Variant = RADAR.new()
	radar.size = Vector2(280, 144)
	radar.navigate.connect(func(point: Vector2) -> void: navigation.append(point))
	root.add_child(radar)
	for id: String in MAPS.MAPS:
		var world: Variant = SIM.new()
		world.configure_map(id)
		world.reset()
		world.ai_enabled = false
		radar.world = world
		world.explored.assign([{}, {}])
		world.visible.assign([{}, {}])
		radar._update_terrain_cache()
		_check_cells(radar, id + "/unexplored")
		_check_unchanged(radar, id + "/unexplored")
		var image: Image = radar._terrain_image
		var texture: ImageTexture = radar._terrain_texture
		var revision: int = radar._terrain_revision
		world.explored[0][Vector2i(2, 3)] = true
		world.visible.assign([{Vector2i(2, 3): true}, {}])
		radar._update_terrain_cache()
		_check(radar._terrain_revision == revision + 1 and is_same(radar._terrain_image, image) and is_same(radar._terrain_texture, texture), "A simulation fog tick must update the existing texture exactly once: " + id)
		_check_cells(radar, id + "/newly visible")
		world.visible.assign([{}, {}])
		radar._update_terrain_cache()
		_check(radar._terrain_image.get_pixel(2, 3).to_rgba32() == EXPLORED.to_rgba32(), "Terrain leaving vision must remain explored: " + id)
		world.explored[0][Vector2i(5, 4)] = true
		world.visible.assign([{Vector2i(5, 4): true}, {}])
		radar._update_terrain_cache()
		_check_cells(radar, id + "/new exploration")
		# Equal dictionary counts cannot identify a fog tick: the cell identities differ.
		world.visible.assign([{Vector2i(2, 3): true}, {}])
		radar._update_terrain_cache()
		_check_cells(radar, id + "/same-count visibility swap")
		revision = radar._terrain_revision
		world.explored.assign([{Vector2i(5, 4): true, Vector2i(7, 6): true}, {}])
		radar._update_terrain_cache()
		_check(radar._terrain_revision == revision + 1, "Replacing exploration alone must invalidate the cache even with the same count: " + id)
		_check_cells(radar, id + "/explored replacement")
		_check(radar._terrain_image.get_pixel(2, 3).to_rgba32() == UNKNOWN.to_rgba32(), "Visibility keys alone must not reveal unexplored terrain: " + id)
		var dimensions := Vector2i(world.map_size / DATA.CELL_SIZE)
		world.explored.assign([{}, {}])
		world.visible.assign([{}, {}])
		for y: int in range(dimensions.y):
			for x: int in range(dimensions.x):
				var cell := Vector2i(x, y)
				world.explored[0][cell] = true
				if (x + y) % 7 == 0:
					world.visible[0][cell] = true
		radar._update_terrain_cache()
		_check(world.explored[0].size() == dimensions.x * dimensions.y, "The explored-map fixture must cover the entire selected battlefield: " + id)
		_check_cells(radar, id + "/fully explored")
		_check_unchanged(radar, id + "/fully explored")
		_check_navigation(radar, id)
		revision = radar._terrain_revision
		world.reset()
		radar._update_terrain_cache()
		_check(radar._terrain_revision == revision + 1, "Restarting a fully explored match must invalidate old map knowledge: " + id)
		_check_cells(radar, id + "/reset")
		var other: Variant = SIM.new()
		other.configure_map(id)
		other.reset()
		other.explored.assign([{Vector2i(9, 8): true}, {}])
		other.visible.assign([{Vector2i(9, 8): true}, {}])
		radar.world = other
		revision = radar._terrain_revision
		radar._update_terrain_cache()
		_check(radar._terrain_revision == revision + 1, "A different same-size world must invalidate the previous world's fog: " + id)
		_check_cells(radar, id + "/world switch")
		_check_unchanged(radar, id + "/world switch")
	# Size changes are a separate invalidation input, independent of dictionary identities.
	var revision: int = radar._terrain_revision
	var old_image: Image = radar._terrain_image
	radar.world.map_size = MAPS.MAPS.ashen_crossing.size
	radar._update_terrain_cache()
	_check(radar._terrain_revision == revision + 1 and not is_same(old_image, radar._terrain_image), "Changing only map dimensions must rebuild and resize the terrain cache")
	_check_cells(radar, "size-only change")
	radar.free()
	print("%s: %d minimap cache checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
