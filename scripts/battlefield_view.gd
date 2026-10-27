extends Node2D

const DATA = preload("res://scripts/catalog.gd")
const PROJ = preload("res://scripts/projection.gd")
const SPRITES = preload("res://scripts/faction_sprites.gd")
const TERRAIN = preload("res://scripts/terrain_art.gd")
const DESTRUCTION = preload("res://scripts/destruction_art.gd")
const INK := Color("151e20")
var world = null
var selected: Array = []
# Camera coordinates live in projected space; simulation coordinates stay unchanged.
var camera_pos: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var viewport_size: Vector2 = Vector2(1000, 768)
var build_kind: String = ""
var cursor_world: Vector2 = Vector2.ZERO
var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO
var command_markers: Array = []
var attack_mode: bool = false
var _font: Font
var _terrain_viewport: SubViewport
var _terrain_texture: Texture2D
var _terrain_bounds: Rect2
var _terrain_map_size := Vector2.ZERO
var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_source: Dictionary = {}

func _map_size() -> Vector2:
	return DATA.MAP_SIZE if world == null else Vector2(world.map_size)

func _ready() -> void:
	_font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_create_terrain_cache()

func _create_terrain_cache() -> void:
	if _terrain_viewport != null and _terrain_map_size == _map_size():
		return
	if _terrain_viewport != null:
		_terrain_viewport.queue_free()
	_terrain_map_size = _map_size()
	# Static terrain commands are rasterized once, not rebuilt for every camera frame.
	_terrain_bounds = PROJ.map_bounds(_map_size()).grow(32)
	_terrain_viewport = SubViewport.new()
	_terrain_viewport.name = "StaticTerrainCache"
	# Keep the largest cache within OpenGL 3.3 hardware texture limits.
	var cache_scale: float = minf(1.0, 8192.0 / _terrain_bounds.size.x)
	_terrain_viewport.size = Vector2i(_terrain_bounds.size * cache_scale)
	_terrain_viewport.disable_3d = true
	_terrain_viewport.transparent_bg = true
	_terrain_viewport.world_2d = World2D.new()
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_terrain_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	add_child(_terrain_viewport)
	var canvas := Node2D.new()
	canvas.scale = Vector2.ONE * cache_scale
	canvas.position = -_terrain_bounds.position * cache_scale
	canvas.draw.connect(_draw_static_terrain.bind(canvas))
	_terrain_viewport.add_child(canvas)
	_terrain_texture = _terrain_viewport.get_texture()

func world_to_screen(pos: Vector2) -> Vector2:
	return (PROJ.project(pos, _map_size()) - camera_pos) * zoom_level

func screen_to_world(pos: Vector2) -> Vector2:
	return PROJ.unproject(pos / zoom_level + camera_pos, _map_size())

func _hash(x: int, y: int) -> float:
	return float(posmod(x * 73856093 ^ y * 19349663, 997)) / 997.0

func _draw() -> void:
	if world == null:
		return
	if _font == null:
		_font = ThemeDB.fallback_font
	draw_set_transform(-camera_pos * zoom_level, 0.0, Vector2.ONE * zoom_level)
	_draw_terrain()
	# Every elevated object shares one depth order, so cliffs occlude troops naturally.
	var ordered: Array = []
	for well in world.wells:
		if _in_view(well.pos, 100.0):
			ordered.append({"depth": well.pos.x + well.pos.y, "type": "well", "data": well})
	for deposit in world.deposits:
		if _in_view(deposit.pos, 70.0):
			ordered.append({"depth": deposit.pos.x + deposit.pos.y, "type": "essence", "data": deposit})
	for rock in world.obstacles:
		if _rect_in_view(rock):
			ordered.append({"depth": rock.get_center().x + rock.get_center().y, "type": "cliff", "data": rock})
	for entity in world.entities.values():
		if not _in_view(entity.pos, 180.0):
			continue
		if int(entity.owner) != 0 and not world.can_see_entity(0, entity):
			continue
		ordered.append({"depth": entity.pos.x + entity.pos.y, "type": "entity", "data": entity})
	for effect: Dictionary in world.destruction_effects:
		if _destruction_visible(effect) and _in_view(effect.pos, 240.0):
			ordered.append({"depth": effect.pos.x + effect.pos.y, "type": "destruction", "data": effect})
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.depth) < float(b.depth))
	for item in ordered:
		match str(item.type):
			"well":
				_draw_well(item.data)
			"essence":
				_draw_essence(item.data)
			"cliff":
				_draw_cliff(item.data)
			"entity":
				var entity: Dictionary = item.data
				SPRITES.draw_entity(self, entity, PROJ.project(entity.pos, _map_size()), selected.has(int(entity.id)), _font, float(world.elapsed))
			"destruction":
				DESTRUCTION.draw_effect(self, item.data, PROJ.project(item.data.pos, _map_size()))
	for effect in world.effects:
		if bool(effect.get("visible_to_player", false)) and (world.is_visible(0, effect.a) or world.is_visible(0, effect.b)):
			var tint: Color = world.color_for(int(effect.owner))
			tint.a = clampf(float(effect.ttl) * 5.0, 0.0, 1.0)
			var start: Vector2 = PROJ.project(effect.a, _map_size()) - Vector2(0, 17)
			var end: Vector2 = PROJ.project(effect.b, _map_size()) - Vector2(0, 14)
			draw_line(start, end, tint, 3.0 if effect.get("tank", false) else 1.4, true)
			draw_circle(end, 5.0 if effect.get("tank", false) else 2.5, Color(tint, tint.a * 0.6))
	_draw_fog()
	_draw_orders()
	if not build_kind.is_empty():
		_draw_build_preview()
	draw_set_transform(Vector2.ZERO)
	if dragging:
		var box := Rect2(drag_start, drag_end - drag_start).abs()
		draw_rect(box, Color(0.35, 0.9, 0.76, 0.10))
		draw_rect(box, Color(0.45, 0.95, 0.8, 0.9), false, 1.0)
	if attack_mode and not dragging:
		var p: Vector2 = world_to_screen(cursor_world)
		draw_arc(p, 11.0, 0, TAU, 24, Color("ffaf6b"), 1.5, true)
		draw_line(p - Vector2(17, 0), p + Vector2(17, 0), Color("ffaf6b"), 1.0)
		draw_line(p - Vector2(0, 17), p + Vector2(0, 17), Color("ffaf6b"), 1.0)

func _destruction_visible(effect: Dictionary) -> bool:
	# Never reveal an unseen death later when its tile is explored.
	return bool(effect.visible_to_player) and (int(effect.owner) == 0 or world.is_visible(0, effect.pos))

func _in_view(pos: Vector2, margin: float = 32.0) -> bool:
	return Rect2(camera_pos - Vector2.ONE * margin, viewport_size / zoom_level + Vector2.ONE * margin * 2.0).has_point(PROJ.project(pos, _map_size()))

func _rect_in_view(rect: Rect2) -> bool:
	var footprint: PackedVector2Array = PROJ.footprint(rect.get_center(), rect.size, _map_size())
	var bounds := Rect2(footprint[0], Vector2.ZERO)
	for p in footprint:
		bounds = bounds.expand(p)
	return bounds.grow(80).intersects(Rect2(camera_pos, viewport_size / zoom_level))

func _world_view_bounds(margin: float = 64.0) -> Rect2:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]
	var bounds := Rect2(screen_to_world(corners[0]), Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(screen_to_world(corner))
	return bounds.grow(margin).intersection(Rect2(Vector2.ZERO, _map_size()))

func _tile_polygon(origin: Vector2, size: float) -> PackedVector2Array:
	return PROJ.footprint(origin + Vector2.ONE * size / 2.0, Vector2.ONE * size, _map_size())

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	result.append(points[0])
	return result

func _ellipse(center: Vector2, radius: Vector2, color: Color, fill: bool = true, width: float = 1.0) -> void:
	var points := PackedVector2Array()
	for i in range(41):
		var a: float = float(i) * TAU / 40.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	if fill:
		draw_colored_polygon(points, color)
	else:
		draw_polyline(points, color, width, true)

func _draw_terrain() -> void:
	_create_terrain_cache()
	draw_rect(Rect2(camera_pos, viewport_size / zoom_level), Color("172524"))
	if _terrain_texture != null:
		draw_texture_rect(_terrain_texture, _terrain_bounds, false)

func _draw_static_terrain(canvas: Node2D) -> void:
	TERRAIN.ground(canvas, _terrain_map_size)

func _draw_cliff(rect: Rect2) -> void:
	# Cached rock faces remain in the shared elevation/depth pass for correct occlusion.
	TERRAIN.cliff(self, rect, _map_size())

func _draw_well(well: Dictionary) -> void:
	var p: Vector2 = PROJ.project(well.pos, _map_size())
	TERRAIN.well(self, p)
	# Restrained motes animate above the weathered stone without rebuilding its body.
	for i in range(4):
		var t: float = fmod(float(world.elapsed) * 0.32 + float(i) * 0.25, 1.0)
		var q := p + Vector2(sin(t * TAU + i) * 9, -7 - t * 28)
		draw_circle(q, 1.2, Color(0.65, 0.83, 1.0, (1.0 - t) * 0.45))

func _draw_essence(deposit: Dictionary) -> void:
	var fullness: float = clampf(float(deposit.amount) / maxf(1.0, float(deposit.get("capacity", 300))), 0, 1)
	TERRAIN.essence(self, PROJ.project(deposit.pos, _map_size()), fullness)

func _draw_fog() -> void:
	_update_fog_cache()
	# Only this ground overlay is sheared. All upright art uses projected anchors.
	var basis_x := Vector2(zoom_level, zoom_level * 0.5)
	var basis_y := Vector2(-zoom_level, zoom_level * 0.5)
	var origin := (Vector2(_map_size().y, 0) - camera_pos) * zoom_level
	draw_set_transform_matrix(Transform2D(basis_x, basis_y, origin))
	draw_texture_rect(_fog_texture, Rect2(Vector2.ZERO, _map_size()), false)
	draw_set_transform(-camera_pos * zoom_level, 0, Vector2.ONE * zoom_level)

func _update_fog_cache() -> void:
	# Simulation replaces the visible dictionary at each fog update and reset.
	# Identity comparison avoids scanning or hashing thousands of cells per frame.
	if _fog_texture != null and is_same(world.visible[0], _fog_source):
		return
	_fog_source = world.visible[0]
	var dimensions := Vector2i(_map_size() / float(DATA.CELL_SIZE))
	if _fog_image == null or _fog_image.get_size() != dimensions:
		_fog_texture = null
		_fog_image = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color("111e20"))
	for key in world.explored[0]:
		var tile: Vector2i = key
		if tile.x >= 0 and tile.y >= 0 and tile.x < dimensions.x and tile.y < dimensions.y:
			_fog_image.set_pixelv(tile, Color(0.04, 0.075, 0.075, 0.69))
	for key in world.visible[0]:
		var tile: Vector2i = key
		if tile.x >= 0 and tile.y >= 0 and tile.x < dimensions.x and tile.y < dimensions.y:
			_fog_image.set_pixelv(tile, Color.TRANSPARENT)
	if _fog_texture == null:
		_fog_texture = ImageTexture.create_from_image(_fog_image)
	else:
		_fog_texture.update(_fog_image)

func _draw_orders() -> void:
	for id in selected:
		if not world.entities.has(id):
			continue
		var entity: Dictionary = world.entities[id]
		if not DATA.spec(entity.kind).get("building", false) or not entity.completed:
			continue
		var rally: Vector2 = entity.get("rally", entity.pos)
		if rally.distance_to(entity.pos) <= 5:
			continue
		var start: Vector2 = PROJ.project(entity.pos, _map_size())
		var end: Vector2 = PROJ.project(rally, _map_size())
		draw_dashed_line(start, end, Color(world.color_for(0), 0.5), 1, 5)
		draw_line(end, end + Vector2(0,-24), world.color_for(0), 1.5)
		draw_colored_polygon(PackedVector2Array([end + Vector2(0,-24), end + Vector2(14,-20), end + Vector2(0,-15)]), world.color_for(0))
	for marker in command_markers:
		var point: Vector2 = PROJ.project(marker.get("pos", Vector2.ZERO), _map_size())
		var life: float = float(marker.get("ttl",marker.get("life",0.7)))
		var tint: Color = marker.get("color",world.color_for(0))
		tint.a *= clampf(life*2.0,0,1)
		var radius: float = 10.0 + (1.0-clampf(life,0,1))*18.0
		_ellipse(point, Vector2(radius * 1.3, radius * 0.65), tint, false, 1.5)
		for i in range(4):
			var v := Vector2.RIGHT.rotated(float(i) * PI / 2.0)
			v.y *= 0.5
			draw_line(point + v*(radius+4), point + v*(radius+8), tint, 1.5)

func _draw_build_preview() -> void:
	var spec: Dictionary = DATA.spec(build_kind)
	var size: Vector2 = spec.get("size",Vector2(80,64))
	var valid: bool = world.can_build(0,build_kind,cursor_world)
	var tint := Color("68e0b5") if valid else Color("f08372")
	var footprint: PackedVector2Array = PROJ.footprint(cursor_world, size, _map_size())
	draw_colored_polygon(footprint, Color(tint,0.17))
	draw_polyline(_closed(footprint), tint, 2, true)
	# An upright wireframe previews height while retaining the exact ground footprint.
	var roof := PackedVector2Array()
	for corner in footprint:
		roof.append(corner - Vector2(0, 32))
	draw_colored_polygon(roof, Color(tint, 0.06))
	draw_polyline(_closed(roof), Color(tint, 0.65), 1, true)
	for corner in footprint:
		draw_line(corner, corner - Vector2(0, 32), Color(tint, 0.6), 1)
	var point: Vector2 = PROJ.project(cursor_world, _map_size())
	var label: String = DATA.faction_title(build_kind, world.faction_for(0))
	var text_size: Vector2 = _font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
	draw_string(_font, point + Vector2(-text_size.x/2.0,-(size.x+size.y)/4.0-45), label, HORIZONTAL_ALIGNMENT_LEFT,-1,12,tint)
