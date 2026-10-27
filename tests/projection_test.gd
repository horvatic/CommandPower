extends SceneTree

const PROJECT = preload("res://scripts/projection.gd")
const DATA = preload("res://scripts/catalog.gd")
const ART = preload("res://scripts/faction_sprites.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var corners: Array = [
		{"world": Vector2.ZERO, "screen": Vector2(2048, 0)},
		{"world": Vector2(DATA.MAP_SIZE.x, 0), "screen": Vector2(5120, 1536)},
		{"world": DATA.MAP_SIZE, "screen": Vector2(3072, 2560)},
		{"world": Vector2(0, DATA.MAP_SIZE.y), "screen": Vector2(0, 1024)}
	]
	for corner: Dictionary in corners:
		_check(PROJECT.project(corner.world).distance_to(corner.screen) < 0.001, "Map corner must project to its expected diamond vertex: " + str(corner.world))
		_check(PROJECT.unproject(corner.screen).distance_to(corner.world) < 0.001, "Map diamond vertex must unproject to the correct simulation corner")
	for point: Vector2 in [Vector2(320, 320), Vector2(650, 540), Vector2(2752, 1728), Vector2(1536, 1024), Vector2(-100, 120), Vector2(3120, 2100)]:
		_check(PROJECT.unproject(PROJECT.project(point)).distance_to(point) < 0.001, "Projection inverse must preserve world coordinates, including points beyond the map")
	_check(PROJECT.map_bounds() == Rect2(0, 0, 5120, 2560), "Projected bounds must enclose the complete map diamond")
	var origin: Vector2 = Vector2(900, 700)
	_check((PROJECT.project(origin + Vector2(32, 0)) - PROJECT.project(origin)) == Vector2(32, 16), "World X movement must follow the descending-right isometric axis")
	_check((PROJECT.project(origin + Vector2(0, 32)) - PROJECT.project(origin)) == Vector2(-32, 16), "World Y movement must follow the descending-left isometric axis")
	var footprint: PackedVector2Array = PROJECT.footprint(Vector2(320, 320), Vector2(128, 96))
	_check(footprint.size() == 4, "Building footprints must have four projected corners")
	for expected: Vector2 in [Vector2(2032, 264), Vector2(2160, 328), Vector2(2064, 376), Vector2(1936, 312)]:
		_check(footprint.has(expected), "Building footprint must match the projection of its actual simulation dimensions")
	_check(Geometry2D.is_point_in_polygon(PROJECT.project(Vector2(320, 320)), footprint), "Projected building center must lie inside its footprint")
	var distinct_palettes: Dictionary = {}
	for style: String in ["humans", "iron_synod", "kharuun", "heavenly_host", "infernal_legion", "veyr"]:
		var entity: Dictionary = {"kind": "infantry", "owner": 0, "faction": style}
		var original: Dictionary = entity.duplicate(true)
		_check(ART.style_for(entity) == style, "Each conceptual faction must retain its explicit visual identity: " + style)
		_check(not ART.hit_polygon(entity).is_empty() and entity == original, "Faction sprite geometry must support picking without changing gameplay data")
		distinct_palettes[ART.PALETTES[style].body] = true
	_check(distinct_palettes.size() == 6, "All six faction and subfaction art styles must have distinct palettes")
	for atlas: Dictionary in [
		{"path": "res://assets/sprites/units.png", "cell": Vector2i(128, 128), "columns": 24},
		{"path": "res://assets/sprites/buildings.png", "cell": Vector2i(320, 256), "columns": 5}
	]:
		var texture: Texture2D = load(str(atlas.path)) as Texture2D
		_check(texture != null, "Runtime sprite atlas must be loadable without vector fallback: " + str(atlas.path))
		if texture == null:
			continue
		var expected_size: Vector2i = Vector2i(atlas.cell) * Vector2i(int(atlas.columns), 6)
		_check(Vector2i(texture.get_size()) == expected_size, "Sprite atlas dimensions must include all faction rows and animation directions")
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		var all_cells_visible: bool = true
		for row: int in range(6):
			for column: int in range(int(atlas.columns)):
				var visible: bool = false
				for y: int in range(0, int(atlas.cell.y), 8):
					for x: int in range(0, int(atlas.cell.x), 8):
						if image.get_pixel(column * int(atlas.cell.x) + x, row * int(atlas.cell.y) + y).a > 0.1:
							visible = true
				all_cells_visible = all_cells_visible and visible
		_check(all_cells_visible, "Every faction/frame slot must contain visible sprite artwork: " + str(atlas.path))
	_test_hover_offsets()
	_test_hover_shadow_preparation()
	if failures == 0:
		print("PASS: %d projection checks" % checks)
	else:
		push_error("FAIL: %d of %d projection checks" % [failures, checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _test_hover_offsets() -> void:
	var immutable: bool = true
	for style: String in ART.STYLES:
		for kind: String in ["worker", "infantry", "tank"]:
			var entity: Dictionary = {"id": 13, "kind": kind, "faction": style, "owner": 0, "pos": Vector2(650, 540), "hp": 70.0, "maxhp": 70.0, "order": "gather", "target": 3, "cargo": 19.0, "facing": Vector2.DOWN, "goal": Vector2(748, 540), "queue": []}
			var snapshot: Dictionary = entity.duplicate(true)
			var bounded: bool = true
			var low: float = INF
			var high: float = -INF
			for sample: int in range(53):
				var value: Vector2 = ART.hover_offset(entity, float(sample) * 0.05)
				bounded = bounded and absf(value.x) < 0.001 and absf(value.y) <= 2.501
				low = minf(low, value.y)
				high = maxf(high, value.y)
			var repeats: bool = ART.hover_offset(entity, 0.37).distance_to(ART.hover_offset(entity, 2.97)) < 0.001
			_check(bounded and low < -2.0 and high > 2.0 and repeats, "Mobile hover must move gently up and down within bounds and repeat after its period: " + style + "/" + kind)
			immutable = immutable and entity == snapshot
	_check(immutable, "Visual hover helpers must not mutate positions, health, orders, cargo, facing, or other entity state")
	var first: Dictionary = {"id": 13, "kind": "infantry", "owner": 0}
	var second: Dictionary = {"id": 14, "kind": "infantry", "owner": 0}
	var phased: bool = false
	for time: float in [0.0, 0.4, 0.8]:
		phased = phased or ART.hover_offset(first, time).distance_to(ART.hover_offset(second, time)) > 0.5
	_check(phased, "Different units must hover out of phase rather than moving in synchronization")
	for kind: String in ["hq", "power", "refinery", "barracks", "factory"]:
		var building: Dictionary = {"id": 13, "kind": kind, "owner": 0}
		var fixed: bool = true
		for time: float in [0.0, 0.65, 1.3, 2.6]:
			fixed = fixed and ART.hover_offset(building, time) == Vector2.ZERO
		_check(fixed, "Buildings must remain fixed to their ground footprints: " + kind)

func _test_hover_shadow_preparation() -> void:
	var texture: Texture2D = load("res://assets/sprites/units.png") as Texture2D
	var source: Image = texture.get_image()
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var original: PackedByteArray = source.get_data().duplicate()
	var body: Image = ART._strip_baked_shadow(source)
	var prepared: PackedByteArray = body.get_data()
	_check(not is_same(source, body) and body.get_size() == source.get_size(), "Hover body preparation must create a separate image with unchanged atlas dimensions")
	var shadow_pixels: int = 0
	var shadows_removed: bool = true
	var opaque_pixels: int = 0
	var opaque_preserved: bool = true
	for index: int in range(0, original.size(), 4):
		var alpha: int = int(original[index + 3])
		if alpha > 0 and alpha <= 92:
			shadow_pixels += 1
			shadows_removed = shadows_removed and int(prepared[index + 3]) == 0
		if alpha == 255:
			opaque_pixels += 1
			opaque_preserved = opaque_preserved and original[index] == prepared[index] and original[index + 1] == prepared[index + 1] and original[index + 2] == prepared[index + 2] and original[index + 3] == prepared[index + 3]
	_check(shadow_pixels > 1000 and shadows_removed, "Actual baked translucent ground shadows must be absent from the bobbing body image")
	_check(opaque_pixels > 1000 and opaque_preserved, "Separating shadows must preserve opaque unit colors and silhouettes")
	_check(source.get_data() == original, "Shadow separation must leave the source atlas image unchanged")
	ART._ensure_atlases()
	var unit_atlas: Texture2D = ART._unit_atlas
	var building_atlas: Texture2D = ART._building_atlas
	_check(unit_atlas != null and building_atlas != null and unit_atlas.get_size() == texture.get_size(), "Runtime hover must prepare valid unit and building textures")
	var cached_body: Image = unit_atlas.get_image()
	if cached_body.is_compressed():
		cached_body.decompress()
	cached_body.convert(Image.FORMAT_RGBA8)
	_check(cached_body.get_data() == prepared, "The actual runtime unit atlas must use the shadow-free body image")
	ART._ensure_atlases()
	_check(is_same(unit_atlas, ART._unit_atlas) and is_same(building_atlas, ART._building_atlas), "Repeated render preparation must reuse cached atlas textures")
