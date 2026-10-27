extends RefCounted

const DATA = preload("res://scripts/catalog.gd")

# Render coordinates only. Economy, paths, targeting, and fog stay on the simulation grid.
static func project(point: Vector2, map_size: Vector2 = DATA.MAP_SIZE) -> Vector2:
	return Vector2(point.x - point.y + map_size.y, (point.x + point.y) * 0.5)

static func unproject(point: Vector2, map_size: Vector2 = DATA.MAP_SIZE) -> Vector2:
	var horizontal: float = point.x - map_size.y
	return Vector2(point.y + horizontal * 0.5, point.y - horizontal * 0.5)

static func map_bounds(map_size: Vector2 = DATA.MAP_SIZE) -> Rect2:
	var span: float = map_size.x + map_size.y
	return Rect2(Vector2.ZERO, Vector2(span, span * 0.5))

static func footprint(center: Vector2, dimensions: Vector2, map_size: Vector2 = DATA.MAP_SIZE) -> PackedVector2Array:
	var half: Vector2 = dimensions * 0.5
	return PackedVector2Array([
		project(center + Vector2(-half.x, -half.y), map_size),
		project(center + Vector2(half.x, -half.y), map_size),
		project(center + Vector2(half.x, half.y), map_size),
		project(center + Vector2(-half.x, half.y), map_size)
	])

static func clamp_camera(camera: Vector2, visible_size: Vector2, map_size: Vector2 = DATA.MAP_SIZE) -> Vector2:
	var maximum: Vector2 = (map_bounds(map_size).size - visible_size).max(Vector2.ZERO)
	var candidate: Vector2 = camera.clamp(Vector2.ZERO, maximum)
	# Keep the view centered on the diamond rather than allowing an entirely empty corner.
	var center: Vector2 = unproject(candidate + visible_size * 0.5, map_size).clamp(Vector2.ZERO, map_size)
	return (project(center, map_size) - visible_size * 0.5).clamp(Vector2.ZERO, maximum)
