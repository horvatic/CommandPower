extends Control

signal navigate(world_position: Vector2)
const DATA = preload("res://scripts/catalog.gd")
const PROJECT = preload("res://scripts/projection.gd")
var world = null
var camera_pos := Vector2.ZERO
var camera_view := Vector2(1000, 800)
var zoom_level := 1.0
var _terrain_image: Image
var _terrain_texture: ImageTexture
var _terrain_map_size := Vector2.ZERO
var _terrain_visible: Dictionary = {}
var _terrain_explored: Dictionary = {}
var _terrain_revision := 0

func _map_size() -> Vector2:
	return DATA.MAP_SIZE if world == null else Vector2(world.map_size)

func _map_rect() -> Rect2:
	var bounds: Rect2 = PROJECT.map_bounds(_map_size())
	var available: Vector2 = (size - Vector2(12, 12)).max(Vector2.ONE)
	var factor: float = minf(available.x / bounds.size.x, available.y / bounds.size.y)
	var dimensions: Vector2 = bounds.size * factor
	return Rect2((size - dimensions) / 2.0, dimensions)

func _projected_to_local(point: Vector2) -> Vector2:
	var rect: Rect2 = _map_rect()
	var bounds: Rect2 = PROJECT.map_bounds(_map_size())
	return rect.position + (point - bounds.position) * (rect.size.x / bounds.size.x)

func map_world_to_local(point: Vector2) -> Vector2:
	return _projected_to_local(PROJECT.project(point, _map_size()))

func map_local_to_world(point: Vector2) -> Vector2:
	var rect: Rect2 = _map_rect()
	var bounds: Rect2 = PROJECT.map_bounds(_map_size())
	var projected: Vector2 = bounds.position + (point - rect.position) * (bounds.size.x / rect.size.x)
	return PROJECT.unproject(projected, _map_size()).clamp(Vector2.ZERO, _map_size())

func _map_polygon() -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in PROJECT.footprint(_map_size() * 0.5, _map_size(), _map_size()):
		polygon.append(_projected_to_local(point))
	return polygon

func contains_map_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _map_polygon())

func _closed(polygon: PackedVector2Array) -> PackedVector2Array:
	var outline: PackedVector2Array = polygon.duplicate()
	if not outline.is_empty():
		outline.append(outline[0])
	return outline

func _update_terrain_cache() -> void:
	# The simulation replaces visibility dictionaries every fog tick and on reset.
	# Exploration changes in the same tick, so unchanged frames need no cell scan.
	if _terrain_texture != null and _terrain_map_size == _map_size() and is_same(_terrain_visible, world.visible[0]) and is_same(_terrain_explored, world.explored[0]):
		return
	_terrain_map_size = _map_size()
	_terrain_visible = world.visible[0]
	_terrain_explored = world.explored[0]
	var dimensions := Vector2i(_terrain_map_size / float(DATA.CELL_SIZE))
	if _terrain_image == null or _terrain_image.get_size() != dimensions:
		_terrain_image = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		_terrain_texture = null
	_terrain_image.fill(Color("111c23"))
	for cell: Vector2i in _terrain_explored:
		if cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y:
			_terrain_image.set_pixelv(cell, Color("364843") if _terrain_visible.has(cell) else Color("212e2e"))
	if _terrain_texture == null:
		_terrain_texture = ImageTexture.create_from_image(_terrain_image)
	else:
		_terrain_texture.update(_terrain_image)
	_terrain_revision += 1

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1219"))
	var map_polygon: PackedVector2Array = _map_polygon()
	draw_colored_polygon(map_polygon, Color("111c23"))
	if world == null:
		draw_polyline(_closed(map_polygon), Color("50716c"), 1.0)
		return
	_update_terrain_cache()
	# One textured diamond replaces a polygon for every explored simulation cell.
	# Each texel retains exactly the same unexplored/explored/visible terrain tone.
	var factor: float = _map_rect().size.x / PROJECT.map_bounds(_map_size()).size.x
	var origin: Vector2 = map_world_to_local(Vector2.ZERO)
	draw_set_transform_matrix(Transform2D(Vector2(factor, factor * 0.5), Vector2(-factor, factor * 0.5), origin))
	draw_texture_rect(_terrain_texture, Rect2(Vector2.ZERO, _map_size()), false)
	draw_set_transform(Vector2.ZERO)
	for well: Dictionary in world.wells:
		var cell: Vector2i = Vector2i(Vector2(well.pos) / DATA.CELL_SIZE)
		if world.explored[0].has(cell):
			draw_circle(map_world_to_local(well.pos), 3.0, Color("a18ae5"))
	for entity: Dictionary in world.entities.values():
		if entity.owner != 0 and not world.can_see_entity(0, entity):
			continue
		var point: Vector2 = map_world_to_local(entity.pos)
		var tint: Color = entity.get("team_color", Color("58e6c2") if entity.owner == 0 else Color("ff805b"))
		var radius: float = 3.0 if DATA.spec(entity.kind).building else 1.8
		draw_rect(Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), tint)
	var camera_rectangle: Rect2 = Rect2(_projected_to_local(camera_pos), camera_view / zoom_level * (_map_rect().size.x / PROJECT.map_bounds(_map_size()).size.x))
	var camera_polygon: PackedVector2Array = PackedVector2Array([camera_rectangle.position, Vector2(camera_rectangle.end.x, camera_rectangle.position.y), camera_rectangle.end, Vector2(camera_rectangle.position.x, camera_rectangle.end.y)])
	for clipped: PackedVector2Array in Geometry2D.intersect_polygons(camera_polygon, map_polygon):
		draw_polyline(_closed(clipped), Color("d9e9c3"), 1.0)
	draw_polyline(_closed(map_polygon), Color("50716c"), 1.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if contains_map_point(event.position):
			navigate.emit(map_local_to_world(event.position))
		accept_event()
