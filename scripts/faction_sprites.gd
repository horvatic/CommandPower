extends RefCounted

# Original lit 3D miniatures, baked into upright isometric sprite atlases.
# Rendering styles and facing frames do not change simulation data.
const DATA = preload("res://scripts/catalog.gd")
const STYLES := ["humans", "iron_synod", "kharuun", "heavenly_host", "infernal_legion", "veyr"]
const UNIT_KINDS := ["worker", "infantry", "tank"]
const BUILDING_KINDS := ["hq", "power", "refinery", "barracks", "factory"]
const EXPANSION_UNIT_KINDS := ["scout", "skirmisher", "sniper", "shock", "breacher", "guardian", "medic", "mechanic", "lancer", "suppressor", "artillery", "mortar", "raider", "destroyer", "juggernaut", "disruptor", "siege_tank", "commander"]
const EXPANSION_BUILDING_KINDS := ["outpost", "sentry", "bastion", "workshop", "sanctum", "arsenal", "reactor", "relay"]
const UNIT_CELL := Vector2(128, 128)
const UNIT_ANCHOR := Vector2(64, 80)
const BUILDING_CELL := Vector2(320, 256)
const BUILDING_ANCHOR := Vector2(160, 165)
const HOVER_AMPLITUDE: float = 2.5
const HOVER_PERIOD: float = 2.6
const HOVER_PHASE_STEP: float = 2.399963
const SHADOW_ALPHA_MAX: int = 92
const TEAM_COLORS := [Color("58e6c2"), Color("ff805b")]
static var _atlases_loaded := false
static var _unit_atlas: Texture2D
static var _building_atlas: Texture2D
static var _expansion_unit_atlases: Dictionary = {}
static var _expansion_building_atlas: Texture2D
static var _sprite_sources: Dictionary = {}
static var _team_sprite_sources: Dictionary = {}
static var _icons: Dictionary = {}
static var _ground_shadow_texture: Texture2D
static var _atlas_prepare_ms: float = 0.0
const PALETTES := {
	"humans": {"body": Color("697963"), "light": Color("a5b094"), "dark": Color("354a43"), "energy": Color("68e9c2"), "trim": Color("cfb77a")},
	"iron_synod": {"body": Color("534264"), "light": Color("89789f"), "dark": Color("26273c"), "energy": Color("f08bce"), "trim": Color("bea1dd")},
	"kharuun": {"body": Color("647d3f"), "light": Color("a1bb61"), "dark": Color("443d2b"), "energy": Color("d5ef81"), "trim": Color("caa96c")},
	"heavenly_host": {"body": Color("d4d7ca"), "light": Color("fff8dc"), "dark": Color("818e91"), "energy": Color("fff1a3"), "trim": Color("d8af59")},
	"infernal_legion": {"body": Color("594147"), "light": Color("a65a4e"), "dark": Color("292c37"), "energy": Color("ff7954"), "trim": Color("c29978")},
	"veyr": {"body": Color("537d96"), "light": Color("b2e5df"), "dark": Color("304463"), "energy": Color("82ecff"), "trim": Color("c0b6f0")}
}

static func style_for(entity: Dictionary) -> String:
	var explicit: String = str(entity.get("faction", ""))
	if STYLES.has(explicit):
		return explicit
	return "humans" if int(entity.get("owner", 0)) == 0 else "iron_synod"

static func team_color(entity: Dictionary) -> Color:
	return entity.get("team_color", TEAM_COLORS[clampi(int(entity.get("owner", 0)), 0, 1)])

static func palette_for(entity: Dictionary) -> Dictionary:
	var palette: Dictionary = PALETTES[style_for(entity)]
	if not entity.has("team_color"):
		return palette
	palette = palette.duplicate()
	palette["energy"] = team_color(entity)
	palette["trim"] = team_color(entity).darkened(0.15)
	return palette

static func _project_delta(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * 0.5)

static func _footprint(dimensions: Vector2) -> PackedVector2Array:
	var half: Vector2 = dimensions * 0.5
	return PackedVector2Array([
		_project_delta(Vector2(-half.x, -half.y)),
		_project_delta(Vector2(half.x, -half.y)),
		_project_delta(Vector2(half.x, half.y)),
		_project_delta(Vector2(-half.x, half.y))
	])

static func _height(kind: String) -> float:
	return float({"hq": 42, "power": 52, "refinery": 36, "barracks": 28, "factory": 38, "outpost": 58, "sentry": 42, "bastion": 50, "workshop": 50, "sanctum": 58, "arsenal": 48, "reactor": 67, "relay": 53}.get(kind, 32))

static func hit_polygon(entity: Dictionary) -> PackedVector2Array:
	var kind: String = str(entity.kind)
	var definition: Dictionary = DATA.spec(kind)
	if bool(definition.get("building", false)):
		var ground: PackedVector2Array = _footprint(Vector2(definition.size))
		var points := PackedVector2Array()
		var height: float = _height(kind) + 19.0
		for corner: Vector2 in ground:
			points.append(corner)
			points.append(corner - Vector2(0, height))
		return Geometry2D.convex_hull(points)
	if kind == "tank" or kind in ["breacher", "suppressor", "artillery", "destroyer", "juggernaut", "siege_tank"]:
		var top: float = float({"kharuun": -69, "heavenly_host": -71, "infernal_legion": -76, "veyr": -64}.get(style_for(entity), -45))
		return PackedVector2Array([Vector2(-40, -24), Vector2(-12, top), Vector2(20, top + 4), Vector2(42, -16), Vector2(29, 9), Vector2(-27, 12)])
	if kind == "worker":
		return PackedVector2Array([Vector2(-25, -18), Vector2(-12, -45), Vector2(15, -43), Vector2(28, -9), Vector2(20, 9), Vector2(-21, 10)])
	return PackedVector2Array([Vector2(-24, -14), Vector2(-12, -46), Vector2(12, -46), Vector2(28, -12), Vector2(13, 7), Vector2(-15, 7)])

static func hover_offset(entity: Dictionary, elapsed: float) -> Vector2:
	if bool(DATA.spec(str(entity.get("kind", ""))).get("building", false)):
		return Vector2.ZERO
	var phase: float = float(entity.get("id", 0)) * HOVER_PHASE_STEP
	return Vector2(0, sin(elapsed * TAU / HOVER_PERIOD + phase) * HOVER_AMPLITUDE)

static func draw_entity(canvas: CanvasItem, entity: Dictionary, p: Vector2, selected: bool, font: Font, elapsed: float = 0.0) -> void:
	var kind: String = str(entity.kind)
	var style: String = style_for(entity)
	var palette: Dictionary = palette_for(entity)
	var building: bool = bool(DATA.spec(kind).get("building", false))
	if not building:
		_draw_ground_shadow(canvas, p, kind)
	# Ownership stays readable even when both commanders choose the same faction.
	var marker_y: float = (Vector2(DATA.spec(kind).size).x + Vector2(DATA.spec(kind).size).y) * 0.25 + 5.0 if building else 13.0
	canvas.draw_line(p + Vector2(-6, marker_y), p + Vector2(6, marker_y), team_color(entity), 2.0)
	# Selection and shadows remain on the ground while the body gently hovers.
	if selected:
		var selection_color: Color = team_color(entity)
		if building:
			_poly(canvas, p, _footprint(Vector2(DATA.spec(kind).size) + Vector2(10, 10)), Color.TRANSPARENT, selection_color, 1.5)
		else:
			_ellipse(canvas, p + Vector2(0, 3), (mobile_shadow_radii(kind) + Vector2(0, 1)) if EXPANSION_UNIT_KINDS.has(kind) else (Vector2(33, 13) if kind == "tank" else Vector2(18, 7)), Color.TRANSPARENT, selection_color)
	var body_p: Vector2 = p + hover_offset(entity, elapsed)
	var cached: bool = _draw_cached_body(canvas, entity, body_p)
	if not cached:
		draw_body(canvas, entity, body_p)
	elif kind == "worker" and style == "humans" and float(entity.get("cargo", 0)) > 0:
		canvas.draw_circle(body_p + Vector2(-9,-22), 3.0, Color("c4a5f2"))
	if building and not bool(entity.get("completed", true)):
		_draw_construction(canvas, entity, body_p)
	_draw_status(canvas, entity, body_p, selected, font, palette)

static func mobile_shadow_radii(kind: String) -> Vector2:
	if EXPANSION_UNIT_KINDS.has(kind):
		var radius: float = float(DATA.spec(kind).radius)
		return Vector2(maxf(12, radius * 1.7), maxf(5, radius * .65))
	return Vector2(33, 12) if kind == "tank" else (Vector2(23, 8) if kind == "worker" else Vector2(10, 4))

static func _draw_ground_shadow(canvas: CanvasItem, p: Vector2, kind: String) -> void:
	if _ground_shadow_texture == null:
		var image := Image.create(65, 65, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y: int in range(65):
			for x: int in range(65):
				var distance: float = (Vector2(x, y) - Vector2(32, 32)).length() / 32.0
				if distance < 1.0:
					image.set_pixel(x, y, Color(0.025, 0.03, 0.035, pow(1.0 - distance, 0.6) * 0.36))
		_ground_shadow_texture = ImageTexture.create_from_image(image)
	var radii: Vector2 = mobile_shadow_radii(kind)
	canvas.draw_texture_rect(_ground_shadow_texture, Rect2(p + Vector2(5, 5) - radii, radii * 2.0), false)

# Vector fallback when an atlas is unavailable. The offline baker uses sprite_models_3d.gd.
static func draw_body(canvas: CanvasItem, entity: Dictionary, p: Vector2) -> void:
	var kind: String = str(entity.kind)
	var style: String = style_for(entity)
	var palette: Dictionary = palette_for(entity)
	var building: bool = bool(DATA.spec(kind).get("building", false))
	if EXPANSION_BUILDING_KINDS.has(kind):
		_expansion_building_body(canvas, entity, p, palette)
	elif EXPANSION_UNIT_KINDS.has(kind):
		_expansion_body(canvas, entity, p, palette)
	elif building:
		_draw_building(canvas, entity, p, style, palette)
	else:
		match style:
			"humans": _human_unit(canvas, entity, p, palette)
			"iron_synod": _synod_unit(canvas, entity, p, palette)
			"kharuun": _plant_unit(canvas, entity, p, palette)
			"heavenly_host": _angel_unit(canvas, entity, p, palette)
			"infernal_legion": _demon_unit(canvas, entity, p, palette)
			"veyr": _crystal_unit(canvas, entity, p, palette)

static func _strip_baked_shadow(source: Image) -> Image:
	# Current baked bodies are fully opaque; only the composited ground shadow is <=92.
	# Work on a copy and keep every RGB byte, so source art and opaque body pixels survive.
	var image: Image = source.duplicate() as Image
	if image.is_compressed():
		if image.decompress() != OK:
			return image
	image.convert(Image.FORMAT_RGBA8)
	image.clear_mipmaps()
	var pixels: PackedByteArray = image.get_data()
	for alpha: int in range(3, pixels.size(), 4):
		if pixels[alpha] <= SHADOW_ALPHA_MAX:
			pixels[alpha] = 0
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)

static func _ensure_atlases() -> void:
	if _atlases_loaded:
		return
	var start: int = Time.get_ticks_usec()
	_atlases_loaded = true
	if ResourceLoader.exists("res://assets/sprites/units.png"):
		var source: Texture2D = load("res://assets/sprites/units.png") as Texture2D
		if source != null:
			var image: Image = source.get_image()
			if image != null and not image.is_empty():
				_unit_atlas = ImageTexture.create_from_image(_strip_baked_shadow(image))
	if ResourceLoader.exists("res://assets/sprites/buildings.png"):
		_building_atlas = load("res://assets/sprites/buildings.png") as Texture2D
	_atlas_prepare_ms = float(Time.get_ticks_usec() - start) / 1000.0

# Original atlases remain untouched. New units have eight facing columns and
# one role per row in a separate 1024x2304 texture for each faction.
static func sprite_source(entity: Dictionary) -> Dictionary:
	if entity.has("team_color"):
		var kind: String = str(entity.kind)
		var building: bool = bool(DATA.spec(kind).get("building", false))
		var direction: int = 0 if building else posmod(roundi(Vector2(entity.get("facing", Vector2.DOWN)).angle() / (TAU / 8.0)), 8)
		var key: String = "%s:%s:%d:%s" % [style_for(entity), kind, direction, team_color(entity).to_html()]
		if _team_sprite_sources.has(key):
			return _team_sprite_sources[key]
		var original: Dictionary = {"kind": kind, "faction": style_for(entity), "facing": entity.get("facing", Vector2.DOWN)}
		var item: Dictionary = sprite_source(original)
		if item.texture == null:
			return item
		var image: Image = item.texture.get_image()
		if image.is_compressed():
			image.decompress()
		var frame: Image = image.get_region(Rect2i(item.source))
		var colored: Dictionary = item.duplicate()
		colored["texture"] = ImageTexture.create_from_image(_recolor_body_image(frame, style_for(entity), team_color(entity)))
		colored["source"] = Rect2(Vector2.ZERO, item.cell)
		_team_sprite_sources[key] = colored
		return colored
	_ensure_atlases()
	var kind: String = str(entity.kind)
	var style: String = style_for(entity)
	var building: bool = bool(DATA.spec(kind).get("building", false))
	var direction: int = 0 if building else posmod(roundi(Vector2(entity.get("facing", Vector2.DOWN)).angle() / (TAU / 8.0)), 8)
	var key: String = "%s:%s:%d" % [style, kind, direction]
	if _sprite_sources.has(key):
		return _sprite_sources[key]
	var texture: Texture2D
	var source: Rect2
	var cell: Vector2 = BUILDING_CELL if building else UNIT_CELL
	var anchor: Vector2 = BUILDING_ANCHOR if building else UNIT_ANCHOR
	if EXPANSION_UNIT_KINDS.has(kind):
		if not _expansion_unit_atlases.has(style):
			var path: String = "res://assets/sprites/units_%s.png" % style
			var atlas: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
			_expansion_unit_atlases[style] = ImageTexture.create_from_image(_strip_baked_shadow(atlas.get_image())) if atlas != null else null
		texture = _expansion_unit_atlases[style]
		source = Rect2(Vector2(direction, EXPANSION_UNIT_KINDS.find(kind)) * cell, cell)
	elif EXPANSION_BUILDING_KINDS.has(kind):
		if _expansion_building_atlas == null and ResourceLoader.exists("res://assets/sprites/expansion_buildings.png"):
			_expansion_building_atlas = load("res://assets/sprites/expansion_buildings.png") as Texture2D
		texture = _expansion_building_atlas
		source = Rect2(Vector2(EXPANSION_BUILDING_KINDS.find(kind), STYLES.find(style)) * cell, cell)
	elif building:
		texture = _building_atlas
		source = Rect2(Vector2(BUILDING_KINDS.find(kind), STYLES.find(style)) * cell, cell)
	else:
		texture = _unit_atlas
		source = Rect2(Vector2(UNIT_KINDS.find(kind) * 8 + direction, STYLES.find(style)) * cell, cell)
	var result: Dictionary = {"texture": texture, "source": source, "cell": cell, "anchor": anchor}
	if texture != null:
		_sprite_sources[key] = result
	return result

# Match the offline models' trim/energy hues, retaining each pixel's baked light
# and alpha. Neutral armor, shadows, operator faces, and silhouette stay intact.
# Only requested frame/color combinations are prepared, once and shared by units.
static func _recolor_body_image(source: Image, style: String, color: Color) -> Image:
	var accents: Array = {
		"humans": [Color("4d9c8c"), Color("a99b6e")],
		"iron_synod": [Color("a75d91"), Color("867d91")],
		"kharuun": [Color("acc174"), Color("b7a06b")],
		"heavenly_host": [Color("e1cf8b"), Color("b49d64")],
		"infernal_legion": [Color("c3693d"), Color("a48a67")],
		"veyr": [Color("74b6c5"), Color("8f8fa6")]
	}[style]
	var image: Image = source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var pixels: PackedByteArray = image.get_data()
	for offset: int in range(0, pixels.size(), 4):
		if pixels[offset + 3] <= SHADOW_ALPHA_MAX:
			continue
		var pixel := Color8(pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
		if pixel.s < 0.20 or pixel.v < 0.16:
			continue
		var coverage := 0.0
		for accent: Color in accents:
			var distance: float = absf(wrapf(pixel.h - accent.h, -0.5, 0.5))
			var tolerance: float = 0.075 if style == "humans" and accent == accents[1] else 0.045
			var hue_mask: float = 1.0 - smoothstep(tolerance * 0.6, tolerance, distance)
			var saturation_mask: float = smoothstep(accent.s * 0.50, accent.s * 0.80, pixel.s)
			coverage = maxf(coverage, hue_mask * saturation_mask)
		if coverage <= 0.0:
			continue
		var painted := pixel.lerp(Color.from_hsv(color.h, color.s * 0.85, pixel.v), coverage)
		painted = Color.from_hsv(painted.h, painted.s, pixel.v)
		pixels[offset] = painted.r8
		pixels[offset + 1] = painted.g8
		pixels[offset + 2] = painted.b8
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)

static func icon_texture(kind: String, faction: String) -> AtlasTexture:
	var key: String = faction + ":" + kind
	if _icons.has(key):
		return _icons[key]
	var item: Dictionary = sprite_source({"kind": kind, "faction": faction, "facing": Vector2.from_angle(TAU / 8.0)})
	if item.texture == null:
		return null
	var result := AtlasTexture.new()
	result.atlas = item.texture
	var building: bool = bool(DATA.spec(kind).get("building", false))
	var crop := Rect2(Vector2(46, 34), Vector2(228, 180)) if building else Rect2(Vector2(19, 14), Vector2(90, 94))
	result.region = Rect2(Vector2(item.source.position) + crop.position, crop.size)
	_icons[key] = result
	return result

static func _draw_cached_body(canvas: CanvasItem, entity: Dictionary, p: Vector2) -> bool:
	var item: Dictionary = sprite_source(entity)
	if item.texture == null:
		return false
	canvas.draw_texture_rect_region(item.texture, Rect2(p - Vector2(item.anchor), Vector2(item.cell)), item.source)
	return true

static func draw_destruction_body(canvas: CanvasItem, entity: Dictionary, p: Vector2, progress: float) -> void:
	# Slice the existing artwork into sinking, separating panels; preserve the caller's transform.
	var item: Dictionary = sprite_source(entity)
	var building: bool = bool(DATA.spec(str(entity.kind)).get("building", false))
	var texture: Texture2D = item.texture
	if texture == null:
		return
	var cell: Vector2 = item.cell
	var anchor: Vector2 = item.anchor
	var source: Rect2 = item.source
	var collapse: float = clampf(progress / 0.48, 0.0, 1.0)
	var scale := Vector2(1.0 + collapse * 0.12, 1.0 - collapse * 0.66)
	var tint: Color = Color.WHITE.lerp(Color("41372f"), minf(1.0, progress * 5.0))
	tint.a = 1.0 - smoothstep(0.22, 0.64, progress)
	if tint.a <= 0.0:
		return
	var strips: int = 6 if building else 4
	for i: int in range(strips):
		var offset := Vector2(float(i) * cell.x / float(strips), 0)
		var size := Vector2(cell.x / float(strips), cell.y)
		var separation: float = (float(i) - float(strips - 1) * 0.5) * collapse * (3.5 if building else 2.0)
		var sink := Vector2(separation, collapse * float(posmod(i * 7 + int(entity.get("id", 0)), 9)))
		canvas.draw_texture_rect_region(texture, Rect2(p + (offset - anchor) * scale + sink, size * scale), Rect2(source.position + offset, size), tint)

static func _poly(canvas: CanvasItem, p: Vector2, points: PackedVector2Array, fill: Color, outline: Color = Color.TRANSPARENT, width: float = 1.0) -> void:
	var positions := PackedVector2Array()
	for point: Vector2 in points:
		positions.append(p + point)
	if fill.a > 0.0:
		canvas.draw_colored_polygon(positions, fill)
	if outline.a > 0.0:
		positions.append(positions[0])
		canvas.draw_polyline(positions, outline, width, true)

static func _ellipse(canvas: CanvasItem, p: Vector2, radii: Vector2, fill: Color, outline: Color = Color.TRANSPARENT) -> void:
	var points := PackedVector2Array()
	for i: int in range(20):
		points.append(Vector2.from_angle(TAU * float(i) / 20.0) * radii)
	_poly(canvas, p, points, fill, outline)

static func _line(canvas: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	canvas.draw_line(a, b, color, width, true)

static func _box(canvas: CanvasItem, p: Vector2, dimensions: Vector2, height: float, palette: Dictionary) -> void:
	var base: PackedVector2Array = _footprint(dimensions)
	var rise := Vector2(0, -height)
	_poly(canvas, p, PackedVector2Array([base[1], base[2], base[2] + rise, base[1] + rise]), Color(palette.body), Color("1c2c31"))
	_poly(canvas, p, PackedVector2Array([base[2], base[3], base[3] + rise, base[2] + rise]), Color(palette.dark), Color("1c2c31"))
	_poly(canvas, p + rise, base, Color(palette.light), Color("263c3d"))

static func _weapon_direction(entity: Dictionary) -> Vector2:
	var direction: Vector2 = _project_delta(Vector2(entity.get("facing", Vector2.DOWN)))
	return direction.normalized() if direction.length_squared() > 0.001 else Vector2(0.89, 0.45)

static func _human_unit(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	var direction: Vector2 = _weapon_direction(entity)
	if kind == "worker":
		# A squat utility barge: the entire underside is one wheel-free hover hull.
		_poly(canvas,p,PackedVector2Array([Vector2(-24,-18),Vector2(-8,-28),Vector2(20,-20),Vector2(24,-10),Vector2(7,-3),Vector2(-23,-10)]),Color(palette.dark),Color(palette.light))
		_poly(canvas,p,PackedVector2Array([Vector2(-23,-20),Vector2(-8,-29),Vector2(19,-21),Vector2(23,-13),Vector2(5,-7),Vector2(-22,-14)]),Color(palette.body),Color(palette.light))
		# Open rectangular receiving basket, rather than a tank turret.
		_poly(canvas,p,PackedVector2Array([Vector2(-16,-24),Vector2(-4,-30),Vector2(8,-25),Vector2(-4,-19)]),Color(palette.dark),Color(palette.trim),2)
		for x: float in [-12.0,-5.0,2.0]:
			_line(canvas,p+Vector2(x,-24),p+Vector2(x+7,-21),Color(palette.trim),1)
		_box(canvas,p+Vector2(9,-18),Vector2(10,8),8,palette)
		canvas.draw_rect(Rect2(p+Vector2(5,-28),Vector2(8,3)),Color(palette.glass if palette.has("glass") else palette.energy))
		_line(canvas,p+Vector2(-15,-21),p+Vector2(-20,-36),Color(palette.trim),4)
		_line(canvas,p+Vector2(-20,-36),p+Vector2(-5,-39),Color(palette.light),3)
		_line(canvas,p+Vector2(-5,-39),p+Vector2(-4,-30),Color(palette.dark),2)
		_line(canvas,p+Vector2(12,-10),p+Vector2(20,-13),Color(palette.energy),1.5)
		if float(entity.get("cargo",0))>0:
			canvas.draw_circle(p+Vector2(-5,-25),3,Color("c4a5f2"))
		return
	if kind == "infantry":
		# Narrow open skiff, its human operator remains clearly exposed above the rim.
		_poly(canvas,p,PackedVector2Array([Vector2(-13,-16),Vector2(-1,-24),Vector2(13,-15),Vector2(5,-4),Vector2(-4,-3)]),Color(palette.dark),Color(palette.light))
		_poly(canvas,p,PackedVector2Array([Vector2(-12,-18),Vector2(-2,-24),Vector2(11,-17),Vector2(4,-11),Vector2(-6,-12)]),Color(palette.body),Color(palette.light))
		_line(canvas,p+Vector2(7,-17),p+Vector2(7,-17)+direction*15,Color(palette.dark),4)
		_line(canvas,p+Vector2(7,-19),p+Vector2(7,-19)+direction*14,Color(palette.light))
		_poly(canvas,p,PackedVector2Array([Vector2(-5,-31),Vector2(4,-31),Vector2(6,-20),Vector2(-5,-19)]),Color(palette.body),Color(palette.light))
		var skin := Color("c79b77")
		canvas.draw_circle(p+Vector2(0,-36),4.4,skin)
		canvas.draw_arc(p+Vector2(0,-36),4.8,PI,TAU,10,Color(palette.dark),2.5,true)
		_line(canvas,p+Vector2(-2,-36),p+Vector2(2,-36),Color("473c32"),1)
		_line(canvas,p+Vector2(-5,-28),p+Vector2(-8,-21),Color(palette.body),3)
		_line(canvas,p+Vector2(5,-28),p+Vector2(7,-21),Color(palette.body),3)
		canvas.draw_circle(p+Vector2(-7,-21),1.7,skin)
		canvas.draw_circle(p+Vector2(6,-21),1.7,skin)
		_line(canvas,p+Vector2(-8,-19),p+Vector2(9,-18),Color(palette.light),2)
		_line(canvas,p+Vector2(-7,-8),p+Vector2(-3,-5),Color(palette.energy),1)
		return
	# The Paladin is a low broad wedge, with a separate turret and long cannon.
	_poly(canvas,p,PackedVector2Array([Vector2(-31,-22),Vector2(-10,-33),Vector2(24,-25),Vector2(32,-15),Vector2(8,-5),Vector2(-26,-12)]),Color(palette.dark),Color("203536"),1.5)
	_poly(canvas,p,PackedVector2Array([Vector2(-30,-24),Vector2(-10,-35),Vector2(23,-27),Vector2(29,-19),Vector2(7,-10),Vector2(-25,-17)]),Color(palette.body),Color(palette.light))
	_poly(canvas,p,PackedVector2Array([Vector2(7,-10),Vector2(29,-19),Vector2(32,-15),Vector2(8,-5)]),Color(palette.dark),Color(palette.light))
	for side: float in [-1.0,1.0]:
		_line(canvas,p+Vector2(side*20,-16),p+Vector2(side*11,-12),Color(palette.energy),1.5)
	for i: int in range(4):
		_line(canvas,p+Vector2(-20+i*4,-27+i),p+Vector2(-16+i*4,-25+i),Color(palette.dark),1.5)
	_box(canvas,p+Vector2(0,-27),Vector2(20,15),9,palette)
	var muzzle: Vector2 = p+Vector2(0,-33)+direction*29
	_line(canvas,p+Vector2(0,-33),muzzle,Color(palette.dark),7)
	_line(canvas,p+Vector2(0,-35),muzzle-Vector2(0,2),Color(palette.light),2)
	canvas.draw_circle(p+Vector2(-5,-35),3,Color(palette.trim))
	_line(canvas,p+Vector2(6,-35),p+Vector2(9,-44),Color(palette.trim))

static func _synod_unit(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	var direction: Vector2 = _weapon_direction(entity)
	if kind == "worker":
		# A crescent receiving shell wraps around a raised biological reservoir.
		_poly(canvas,p,PackedVector2Array([Vector2(-24,-13),Vector2(-21,-27),Vector2(-12,-33),Vector2(-13,-20),Vector2(0,-14),Vector2(12,-20),Vector2(13,-32),Vector2(22,-26),Vector2(25,-12),Vector2(13,-6),Vector2(-12,-6)]),Color(palette.body),Color(palette.light))
		_ellipse(canvas,p+Vector2(0,-24),Vector2(7,13),Color(palette.dark),Color(palette.trim))
		_ellipse(canvas,p+Vector2(0,-29),Vector2(5,7),Color(palette.light),Color(palette.dark))
		_line(canvas,p+Vector2(-4,-25),p+Vector2(4,-25),Color(palette.energy),2)
		for side: float in [-1.0,1.0]:
			_line(canvas,p+Vector2(side*17,-17),p+Vector2(side*23,-8),Color(palette.trim),2.5)
			_line(canvas,p+Vector2(side*23,-8),p+Vector2(side*17,-5),Color(palette.light),2)
		return
	if kind == "infantry":
		# Tall armored sentinel, tapered below its shell instead of a vehicle hull.
		_poly(canvas,p,PackedVector2Array([Vector2(-7,-32),Vector2(6,-35),Vector2(11,-24),Vector2(5,-8),Vector2(0,-4),Vector2(-7,-12),Vector2(-11,-25)]),Color(palette.body),Color(palette.light))
		_poly(canvas,p,PackedVector2Array([Vector2(-7,-32),Vector2(0,-30),Vector2(0,-10),Vector2(-7,-12),Vector2(-11,-25)]),Color(palette.dark))
		_ellipse(canvas,p+Vector2(0,-36),Vector2(5,5),Color(palette.trim),Color(palette.dark))
		_line(canvas,p+Vector2(-3,-36),p+Vector2(3,-36),Color(palette.energy),1.5)
		for side: float in [-1.0,1.0]:
			_line(canvas,p+Vector2(side*5,-32),p+Vector2(side*10,-43),Color(palette.trim),2)
		_line(canvas,p+Vector2(7,-25),p+Vector2(7,-25)+direction*17,Color(palette.dark),6)
		_line(canvas,p+Vector2(7,-26),p+Vector2(7,-26)+direction*17,Color(palette.trim),1)
		return
	# Broad living armor and crystalline shoulders surround an organic gun turret.
	_poly(canvas,p,PackedVector2Array([Vector2(-34,-21),Vector2(-23,-34),Vector2(7,-39),Vector2(31,-29),Vector2(35,-15),Vector2(13,-7),Vector2(-23,-9)]),Color(palette.dark),Color(palette.light),1.5)
	_ellipse(canvas,p+Vector2(0,-23),Vector2(27,12),Color(palette.body),Color(palette.dark))
	for rib: int in range(4):
		_line(canvas,p+Vector2(-22+rib*6,-29),p+Vector2(-13+rib*6,-17),Color(palette.trim),2)
	for side: float in [-1.0,1.0]:
		_poly(canvas,p,PackedVector2Array([Vector2(side*18,-28),Vector2(side*23,-48),Vector2(side*30,-27),Vector2(side*24,-18)]),Color(palette.body),Color(palette.trim))
	_ellipse(canvas,p+Vector2(1,-32),Vector2(11,8),Color(palette.light),Color(palette.dark))
	_line(canvas,p+Vector2(0,-34),p+Vector2(0,-34)+direction*27,Color(palette.dark),8)
	_line(canvas,p+Vector2(0,-35),p+Vector2(0,-35)+direction*27,Color(palette.trim),2)
	canvas.draw_circle(p+Vector2(2,-34),3,Color(palette.energy))

static func _plant_unit(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	if kind == "worker":
		# Rounded carrying gourd with a wide basket rim and flexible gathering vines.
		_poly(canvas,p,PackedVector2Array([Vector2(-12,-28),Vector2(11,-28),Vector2(15,-18),Vector2(9,-7),Vector2(0,-4),Vector2(-11,-10),Vector2(-15,-19)]),Color(palette.body),Color(palette.dark),2)
		_ellipse(canvas,p+Vector2(0,-27),Vector2(14,6),Color(palette.dark),Color(palette.trim))
		for x: float in [-8.0,0.0,8.0]:
			_line(canvas,p+Vector2(x,-23),p+Vector2(x*.6,-9),Color(palette.trim),1.3)
		_poly(canvas,p,PackedVector2Array([Vector2(-1,-28),Vector2(-12,-37),Vector2(1,-35),Vector2(9,-40),Vector2(11,-31)]),Color(palette.light),Color(palette.dark))
		for side: float in [-1.0,1.0]:
			_line(canvas,p+Vector2(side*12,-20),p+Vector2(side*23,-23),Color(palette.dark),3)
			_line(canvas,p+Vector2(side*23,-23),p+Vector2(side*20,-13),Color(palette.body),2)
		return
	if kind == "infantry":
		# A dense upright bark shield, its thorn crest is unlike the carrying gourd.
		_poly(canvas,p,PackedVector2Array([Vector2(-13,-30),Vector2(-7,-39),Vector2(8,-38),Vector2(14,-27),Vector2(9,-10),Vector2(0,-5),Vector2(-10,-12)]),Color(palette.dark),Color(palette.trim),1.5)
		_poly(canvas,p,PackedVector2Array([Vector2(-9,-31),Vector2(1,-36),Vector2(9,-28),Vector2(6,-13),Vector2(0,-9),Vector2(-5,-15)]),Color(palette.body),Color(palette.light))
		for x: float in [-8.0,0.0,8.0]:
			_poly(canvas,p,PackedVector2Array([Vector2(x-3,-35),Vector2(x,-44),Vector2(x+3,-35)]),Color(palette.trim))
		_line(canvas,p+Vector2(-3,-29),p+Vector2(3,-29),Color(palette.energy),2)
		_line(canvas,p+Vector2(10,-23),p+Vector2(23,-33),Color(palette.dark),4)
		_poly(canvas,p,PackedVector2Array([Vector2(19,-30),Vector2(25,-37),Vector2(24,-26)]),Color(palette.trim))
		return
	# A horizontal pinecone artillery body, with seed scales and a trumpet muzzle.
	_ellipse(canvas,p+Vector2(0,-22),Vector2(31,15),Color(palette.dark),Color(palette.trim))
	for row: int in range(3):
		for i: int in range(5):
			var center := Vector2(-23+i*10+float(row%2)*3,-30+row*8)
			_poly(canvas,p+center,PackedVector2Array([Vector2(-5,0),Vector2(0,-6),Vector2(7,0),Vector2(0,6)]),Color(palette.body),Color(palette.light))
	for side: float in [-1.0,1.0]:
		_poly(canvas,p,PackedVector2Array([Vector2(side*22,-26),Vector2(side*34,-40),Vector2(side*30,-20)]),Color(palette.trim),Color(palette.dark))
	var direction: Vector2 = _weapon_direction(entity)
	var base := p+Vector2(0,-29)
	var muzzle := base+direction*27
	_line(canvas,base,muzzle,Color(palette.dark),10)
	_line(canvas,base-Vector2(0,2),muzzle-Vector2(0,2),Color(palette.trim),3)
	_ellipse(canvas,muzzle,Vector2(7,5),Color(palette.dark),Color(palette.light))

static func _angel_unit(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	if kind == "worker":
		# A modest bell-shaped spirit robe and tool staff, without combat wings.
		_poly(canvas,p,PackedVector2Array([Vector2(-5,-29),Vector2(5,-29),Vector2(7,-14),Vector2(12,-7),Vector2(0,-4),Vector2(-11,-8),Vector2(-7,-16)]),Color(palette.body),Color(palette.trim))
		_line(canvas,p+Vector2(0,-26),p+Vector2(0,-9),Color(palette.trim),2)
		canvas.draw_circle(p+Vector2(0,-33),4,Color(palette.light))
		_ellipse(canvas,p+Vector2(0,-39),Vector2(7,2.5),Color.TRANSPARENT,Color(palette.trim))
		_line(canvas,p+Vector2(6,-25),p+Vector2(15,-20),Color(palette.body),3)
		_line(canvas,p+Vector2(16,-31),p+Vector2(16,-8),Color(palette.trim),2)
		_ellipse(canvas,p+Vector2(16,-32),Vector2(4,3),Color.TRANSPARENT,Color(palette.trim))
		canvas.draw_circle(p+Vector2(16,-32),1.5,Color(palette.energy))
		return
	if kind == "infantry":
		# Fixed swept wings frame a tall armored spirit with a shield and spear.
		for side: float in [-1.0,1.0]:
			_poly(canvas,p,PackedVector2Array([Vector2(side*5,-28),Vector2(side*25,-39),Vector2(side*18,-22),Vector2(side*9,-18)]),Color(palette.light),Color(palette.trim))
			_line(canvas,p+Vector2(side*8,-27),p+Vector2(side*20,-33),Color(palette.trim),1)
		_poly(canvas,p,PackedVector2Array([Vector2(-6,-31),Vector2(6,-31),Vector2(9,-19),Vector2(0,-5),Vector2(-8,-18)]),Color(palette.body),Color(palette.trim))
		_poly(canvas,p,PackedVector2Array([Vector2(-5,-30),Vector2(0,-34),Vector2(6,-29),Vector2(4,-21),Vector2(-4,-21)]),Color(palette.light),Color(palette.trim))
		canvas.draw_circle(p+Vector2(0,-37),3.8,Color(palette.light))
		_ellipse(canvas,p+Vector2(0,-43),Vector2(7,2),Color.TRANSPARENT,Color(palette.trim))
		_poly(canvas,p,PackedVector2Array([Vector2(-16,-29),Vector2(-9,-25),Vector2(-10,-14),Vector2(-15,-11),Vector2(-20,-18)]),Color(palette.light),Color(palette.trim))
		_line(canvas,p+Vector2(18,-38),p+Vector2(18,-9),Color(palette.trim),2)
		_poly(canvas,p,PackedVector2Array([Vector2(15,-37),Vector2(18,-45),Vector2(21,-37)]),Color(palette.light),Color(palette.trim))
		return
	# The Colossus is a broad reliquary/altar construct rather than a giant person.
	for side: float in [-1.0,1.0]:
		_poly(canvas,p,PackedVector2Array([Vector2(side*13,-30),Vector2(side*36,-49),Vector2(side*32,-25),Vector2(side*17,-16)]),Color(palette.light),Color(palette.trim),1.5)
		for i: int in range(3):
			_line(canvas,p+Vector2(side*(19+i*4),-29-i*3),p+Vector2(side*(27+i*3),-34-i*4),Color(palette.trim),1)
	_box(canvas,p+Vector2(0,-11),Vector2(32,21),12,palette)
	_box(canvas,p+Vector2(0,-26),Vector2(25,17),12,palette)
	_poly(canvas,p,PackedVector2Array([Vector2(-11,-40),Vector2(0,-47),Vector2(12,-39),Vector2(9,-24),Vector2(-8,-24)]),Color(palette.trim),Color(palette.light))
	canvas.draw_circle(p+Vector2(0,-35),6,Color(palette.energy))
	_ellipse(canvas,p+Vector2(0,-51),Vector2(13,4),Color.TRANSPARENT,Color(palette.trim))
	var direction: Vector2 = _weapon_direction(entity)
	_line(canvas,p+Vector2(0,-33),p+Vector2(0,-33)+direction*23,Color(palette.trim),5)

static func _demon_unit(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	if kind == "worker":
		# A round ash urn with small horns and gathering tongs, no combat torso.
		_ellipse(canvas,p+Vector2(0,-19),Vector2(12,13),Color(palette.body),Color(palette.dark))
		_ellipse(canvas,p+Vector2(0,-28),Vector2(12,5),Color(palette.dark),Color(palette.trim))
		_ellipse(canvas,p+Vector2(0,-28),Vector2(7,2.5),Color(palette.energy))
		for side: float in [-1.0,1.0]:
			_poly(canvas,p,PackedVector2Array([Vector2(side*7,-29),Vector2(side*13,-37),Vector2(side*12,-25)]),Color(palette.trim))
			_line(canvas,p+Vector2(side*10,-20),p+Vector2(side*22,-25),Color(palette.dark),3)
			_line(canvas,p+Vector2(side*22,-25),p+Vector2(side*23,-14),Color(palette.trim),2)
			_line(canvas,p+Vector2(side*23,-14),p+Vector2(side*18,-16),Color(palette.trim),2)
		_line(canvas,p+Vector2(-4,-18),p+Vector2(4,-18),Color(palette.trim),1.5)
		return
	if kind == "infantry":
		# A narrow bladed spirit warrior, ending in one uninterrupted taper.
		_poly(canvas,p,PackedVector2Array([Vector2(-8,-29),Vector2(7,-31),Vector2(10,-21),Vector2(5,-11),Vector2(0,-5),Vector2(-6,-13)]),Color(palette.body),Color(palette.dark),1.5)
		_poly(canvas,p,PackedVector2Array([Vector2(-8,-28),Vector2(-14,-33),Vector2(-11,-20),Vector2(-4,-21)]),Color(palette.dark),Color(palette.trim))
		canvas.draw_circle(p+Vector2(0,-35),4.5,Color(palette.dark))
		for side: float in [-1.0,1.0]:
			_poly(canvas,p,PackedVector2Array([Vector2(side*3,-37),Vector2(side*10,-45),Vector2(side*7,-33)]),Color(palette.trim))
			canvas.draw_circle(p+Vector2(side*2,-35),1,Color(palette.energy))
		_line(canvas,p+Vector2(0,-27),p+Vector2(0,-18),Color(palette.energy),1.5)
		_line(canvas,p+Vector2(12,-12),p+Vector2(17,-36),Color(palette.trim),2.5)
		_poly(canvas,p,PackedVector2Array([Vector2(17,-37),Vector2(25,-33),Vector2(19,-23)]),Color(palette.body),Color(palette.trim))
		return
	# A huge armored jaw and shoulder mass ride one broad suspended furnace hull.
	_poly(canvas,p,PackedVector2Array([Vector2(-32,-20),Vector2(-20,-34),Vector2(19,-34),Vector2(33,-20),Vector2(23,-8),Vector2(-22,-8)]),Color(palette.dark),Color(palette.trim),1.5)
	for side: float in [-1.0,1.0]:
		_poly(canvas,p,PackedVector2Array([Vector2(side*13,-34),Vector2(side*30,-43),Vector2(side*37,-25),Vector2(side*21,-18)]),Color(palette.body),Color(palette.dark),1.5)
		_poly(canvas,p,PackedVector2Array([Vector2(side*17,-40),Vector2(side*29,-58),Vector2(side*24,-35)]),Color(palette.trim))
	_poly(canvas,p,PackedVector2Array([Vector2(-15,-42),Vector2(0,-49),Vector2(15,-42),Vector2(16,-29),Vector2(8,-22),Vector2(-10,-24)]),Color(palette.body),Color(palette.dark),2)
	_poly(canvas,p,PackedVector2Array([Vector2(-11,-34),Vector2(11,-34),Vector2(7,-26),Vector2(-7,-26)]),Color(palette.dark),Color(palette.trim))
	for x: float in [-7.0,0.0,7.0]:
		_poly(canvas,p,PackedVector2Array([Vector2(x-2,-34),Vector2(x+2,-34),Vector2(x,-29)]),Color(palette.trim))
	for side: float in [-1.0,1.0]:
		_line(canvas,p+Vector2(side*4,-39),p+Vector2(side*10,-39),Color(palette.energy),2)
	_line(canvas,p+Vector2(-12,-17),p+Vector2(12,-17),Color(palette.energy),2)
	for x: float in [-8.0,0.0,8.0]:
		_line(canvas,p+Vector2(x,-22),p+Vector2(x,-13),Color(palette.dark),2)

static func _unit_shard(canvas: CanvasItem, p: Vector2, width: float, height: float, palette: Dictionary) -> void:
	_poly(canvas,p,PackedVector2Array([Vector2(0,-height*.5),Vector2(width*.5,0),Vector2(0,height*.5),Vector2(-width*.5,0)]),Color(palette.body),Color(palette.light))
	_poly(canvas,p,PackedVector2Array([Vector2(0,-height*.5),Vector2(width*.5,0),Vector2(0,height*.5)]),Color(palette.trim))

static func _crystal_unit(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	if kind == "worker":
		# Compact asymmetric crystal tools form an open collection ring.
		_ellipse(canvas,p+Vector2(0,-21),Vector2(13,8),Color.TRANSPARENT,Color(palette.trim))
		_unit_shard(canvas,p+Vector2(-6,-27),11,24,palette)
		_unit_shard(canvas,p+Vector2(12,-21),8,15,palette)
		_unit_shard(canvas,p+Vector2(0,-11),6,10,palette)
		_line(canvas,p+Vector2(-2,-20),p+Vector2(21,-16),Color(palette.dark),2)
		_line(canvas,p+Vector2(21,-16),p+Vector2(25,-21),Color(palette.trim),2)
		canvas.draw_circle(p+Vector2(1,-23),2,Color(palette.energy))
		return
	if kind == "infantry":
		# A tall flat shield prism with separated rear fins and a side emitter.
		for side: float in [-1.0,1.0]:
			_poly(canvas,p,PackedVector2Array([Vector2(side*6,-28),Vector2(side*17,-39),Vector2(side*14,-15),Vector2(side*7,-10)]),Color(palette.dark),Color(palette.trim))
		_unit_shard(canvas,p+Vector2(0,-25),19,35,palette)
		_line(canvas,p+Vector2(0,-35),p+Vector2(0,-18),Color(palette.energy),1.5)
		var direction: Vector2 = _weapon_direction(entity)
		_line(canvas,p+Vector2(8,-25),p+Vector2(8,-25)+direction*16,Color(palette.dark),4)
		_unit_shard(canvas,p+Vector2(8,-25)+direction*16,5,7,palette)
		return
	# A low hexagonal monolith chassis protects its core; it is not a taller guard.
	_poly(canvas,p,PackedVector2Array([Vector2(-33,-24),Vector2(-12,-37),Vector2(23,-32),Vector2(35,-19),Vector2(14,-7),Vector2(-24,-11)]),Color(palette.dark),Color(palette.light),1.5)
	_poly(canvas,p,PackedVector2Array([Vector2(-30,-27),Vector2(-12,-39),Vector2(21,-34),Vector2(31,-24),Vector2(11,-14),Vector2(-23,-17)]),Color(palette.body),Color(palette.trim))
	_unit_shard(canvas,p+Vector2(-2,-34),18,27,palette)
	for side: float in [-1.0,1.0]:
		_poly(canvas,p,PackedVector2Array([Vector2(side*15,-28),Vector2(side*26,-37),Vector2(side*29,-22),Vector2(side*21,-16)]),Color(palette.body),Color(palette.light))
	var direction: Vector2 = _weapon_direction(entity)
	_line(canvas,p+Vector2(1,-30),p+Vector2(1,-30)+direction*27,Color(palette.dark),7)
	_line(canvas,p+Vector2(1,-31),p+Vector2(1,-31)+direction*27,Color(palette.energy),1.5)

static func _draw_building(canvas: CanvasItem, entity: Dictionary, p: Vector2, style: String, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	var size: Vector2 = Vector2(DATA.spec(kind).size)
	_ellipse(canvas, p + Vector2(7, 9), Vector2((size.x + size.y) * .50, (size.x + size.y) * .23), Color(0.01, 0.02, 0.025, .3))
	match style:
		"humans": _human_building_fallback(canvas, p, kind, palette)
		"iron_synod": _synod_building_fallback(canvas, p, kind, palette)
		"kharuun": _plant_building_fallback(canvas, p, kind, palette)
		"heavenly_host": _host_building_fallback(canvas, p, kind, palette)
		"infernal_legion": _infernal_building_fallback(canvas, p, kind, palette)
		"veyr": _veyr_building_fallback(canvas, p, kind, palette)

static func _building_silo(canvas: CanvasItem, p: Vector2, width: float, height: float, palette: Dictionary) -> void:
	_poly(canvas, p, PackedVector2Array([Vector2(-width, 0), Vector2(-width, -height), Vector2(width, -height), Vector2(width, 0)]), Color(palette.body), Color(palette.dark))
	_ellipse(canvas, p, Vector2(width, width * .45), Color(palette.dark), Color(palette.light))
	_ellipse(canvas, p - Vector2(0, height), Vector2(width, width * .45), Color(palette.light), Color(palette.trim))
	_line(canvas, p + Vector2(width * .6, -3), p + Vector2(width * .6, -height + 3), Color(palette.dark), 2)

static func _building_dome(canvas: CanvasItem, p: Vector2, radii: Vector2, palette: Dictionary) -> void:
	_ellipse(canvas, p, radii, Color(palette.dark), Color(palette.light))
	_ellipse(canvas, p - Vector2(0, radii.y * .38), radii * Vector2(.9, .85), Color(palette.body), Color(palette.light))
	_ellipse(canvas, p - radii * Vector2(.23, .52), radii * Vector2(.38, .24), Color(palette.light))

static func _building_shard(canvas: CanvasItem, p: Vector2, width: float, height: float, palette: Dictionary) -> void:
	_poly(canvas, p, PackedVector2Array([Vector2(-width, -height * .3), Vector2(0, -height), Vector2(width, -height * .3), Vector2(0, 4)]), Color(palette.body), Color(palette.light))
	_poly(canvas, p, PackedVector2Array([Vector2(0, -height), Vector2(width, -height * .3), Vector2(0, 4)]), Color(palette.dark), Color(palette.trim))
	_line(canvas, p - Vector2(0, height * .86), p - Vector2(0, 4), Color(palette.energy), 2)

static func _building_arch(canvas: CanvasItem, p: Vector2, width: float, height: float, palette: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		_box(canvas, p + Vector2(side * width, 0), Vector2(12, 12), height, palette)
	_line(canvas, p + Vector2(-width, -height), p + Vector2(0, -height - 8), Color(palette.light), 7)
	_line(canvas, p + Vector2(0, -height - 8), p + Vector2(width, -height), Color(palette.body), 7)

static func _human_building_fallback(canvas: CanvasItem, p: Vector2, kind: String, palette: Dictionary) -> void:
	match kind:
		"hq":
			for side: float in [-1.0, 1.0]:
				_box(canvas, p + Vector2(side * 40, 0), Vector2(32, 41), 19, palette)
			_box(canvas, p, Vector2(51, 44), 37, palette)
			_box(canvas, p - Vector2(0, 37), Vector2(24, 21), 20, palette)
			_line(canvas, p + Vector2(-8, -58), p + Vector2(-8, -78), Color(palette.trim), 2)
			_ellipse(canvas, p + Vector2(13, -62), Vector2(12, 5), Color(palette.dark), Color(palette.light))
			_line(canvas, p + Vector2(-22, -30), p + Vector2(20, -10), Color(palette.energy), 2)
		"power":
			_box(canvas, p, Vector2(43, 40), 10, palette)
			for side: float in [-1.0, 1.0]:
				var q := p + Vector2(side * 18, -8)
				_building_silo(canvas, q, 13, 39, palette)
				for y: int in range(3): _ellipse(canvas, q - Vector2(0, 9 + y * 10), Vector2(14, 6), Color.TRANSPARENT, Color(palette.dark))
				_line(canvas, q + Vector2(-8, -34), q + Vector2(8, -34), Color(palette.energy), 2)
		"refinery":
			_box(canvas, p + Vector2(-25, -5), Vector2(27, 37), 30, palette)
			_building_silo(canvas, p + Vector2(16, -12), 15, 36, palette)
			_building_silo(canvas, p + Vector2(41, 5), 11, 27, palette)
			_line(canvas, p + Vector2(-10, -24), p + Vector2(29, -24), Color(palette.trim), 5)
			_box(canvas, p + Vector2(-4, 24), Vector2(46, 18), 9, palette)
			_line(canvas, p + Vector2(-24, 19), p + Vector2(11, 36), Color(palette.dark), 6)
		"barracks":
			_box(canvas, p, Vector2(76, 33), 18, palette)
			for i: int in range(5):
				var q := p + _project_delta(Vector2(-28 + i * 14, 0))
				_box(canvas, q - Vector2(0, 18), Vector2(10, 27), 3, palette)
				canvas.draw_circle(q + Vector2(14, -4), 2, Color(palette.energy))
			_line(canvas, p + Vector2(-35, -29), p + Vector2(-35, -45), Color(palette.trim), 2)
			_box(canvas, p + Vector2(25, 21), Vector2(9, 9), 9, palette)
		"factory":
			_box(canvas, p + Vector2(-27, -7), Vector2(39, 60), 30, palette)
			_box(canvas, p + Vector2(25, 7), Vector2(49, 52), 13, palette)
			_building_arch(canvas, p + Vector2(11, 18), 35, 46, palette)
			_line(canvas, p + Vector2(11, -35), p + Vector2(11, -12), Color(palette.trim), 2)
			_line(canvas, p + Vector2(-18, 22), p + Vector2(28, 44), Color(palette.dark), 8)
			for i: int in range(4): _line(canvas, p + Vector2(-13 + i * 11, 19 + i * 5), p + Vector2(-8 + i * 11, 21 + i * 5), Color(palette.trim), 2)

static func _synod_building_fallback(canvas: CanvasItem, p: Vector2, kind: String, palette: Dictionary) -> void:
	match kind:
		"hq":
			_building_dome(canvas, p - Vector2(0, 24), Vector2(57, 29), palette)
			for side: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					var foot := p + Vector2(side * 54, z * 18)
					_line(canvas, foot, p + Vector2(side * 18, -36), Color(palette.light), 7)
					_building_dome(canvas, foot, Vector2(12, 9), palette)
			canvas.draw_circle(p + Vector2(0, -53), 8, Color(palette.energy))
		"power":
			for q: Vector2 in [Vector2(-23, 0), Vector2(21, 3), Vector2(0, -13)]:
				_building_silo(canvas, p + q, 10, 42, palette)
				for y: int in range(4): _ellipse(canvas, p + q - Vector2(0, 8 + y * 9), Vector2(12, 5), Color.TRANSPARENT, Color(palette.trim))
				canvas.draw_circle(p + q - Vector2(0, 44), 4, Color(palette.energy))
		"refinery":
			for q: Vector2 in [Vector2(-25, -10), Vector2(25, 0)]:
				_building_dome(canvas, p + q - Vector2(0, 18), Vector2(24, 29), palette)
				_line(canvas, p + q - Vector2(0, 28), p + Vector2(0, -4), Color(palette.trim), 5)
			_building_dome(canvas, p + Vector2(0, 20), Vector2(32, 15), palette)
			_ellipse(canvas, p + Vector2(0, 22), Vector2(19, 9), Color(palette.dark), Color(palette.energy))
		"barracks":
			_box(canvas, p, Vector2(75, 24), 6, palette)
			for i: int in range(4):
				var q := p + _project_delta(Vector2(-27 + i * 18, 0))
				_building_dome(canvas, q - Vector2(0, 14), Vector2(12, 19), palette)
				_line(canvas, q + Vector2(-5, -26), q + Vector2(-5, -7), Color(palette.trim), 2)
				canvas.draw_circle(q + Vector2(3, -17), 3, Color(palette.energy))
		"factory":
			_ellipse(canvas, p, Vector2(72, 31), Color(palette.dark), Color(palette.trim))
			for i: int in range(5):
				var q := p + _project_delta(Vector2(-35 + i * 17, 0))
				_line(canvas, q + Vector2(-23, 8), q + Vector2(0, -34), Color(palette.light), 5)
				_line(canvas, q + Vector2(0, -34), q + Vector2(24, 12), Color(palette.body), 6)
			_building_dome(canvas, p + Vector2(8, 17), Vector2(25, 9), palette)
			_line(canvas, p + Vector2(-61, -1), p + Vector2(-45, -43), Color(palette.trim), 5)
			_line(canvas, p + Vector2(-45, -43), p + Vector2(-22, -29), Color(palette.light), 4)

static func _plant_building_fallback(canvas: CanvasItem, p: Vector2, kind: String, palette: Dictionary) -> void:
	match kind:
		"hq":
			_poly(canvas, p, PackedVector2Array([Vector2(-41, 12), Vector2(-20, -20), Vector2(-17, -58), Vector2(13, -65), Vector2(23, -20), Vector2(44, 15), Vector2(0, 31)]), Color(palette.dark), Color(palette.trim), 2)
			for side: float in [-1.0, 1.0]:
				_line(canvas, p + Vector2(side * 10, -30), p + Vector2(side * 35, -49), Color(palette.body), 9)
				_building_dome(canvas, p + Vector2(side * 28, -51), Vector2(27, 11), palette)
			_ellipse(canvas, p + Vector2(0, -7), Vector2(12, 20), Color(palette.dark), Color(palette.energy))
		"power":
			_line(canvas, p + Vector2(0, 12), p + Vector2(0, -45), Color(palette.dark), 10)
			for i: int in range(7):
				var v := Vector2.from_angle(TAU * i / 7.0)
				_poly(canvas, p - Vector2(0, 42), PackedVector2Array([v * 5, v * Vector2(35, 23), v.rotated(.45) * Vector2(25, 17)]), Color(palette.body), Color(palette.light))
			canvas.draw_circle(p - Vector2(0, 42), 10, Color(palette.energy))
			for side: float in [-1.0, 1.0]: _line(canvas, p + Vector2(side * 25, 12), p - Vector2(0, 14), Color(palette.body), 6)
		"refinery":
			for q: Vector2 in [Vector2(-25, -7), Vector2(23, -3), Vector2(0, -23)]:
				_building_dome(canvas, p + q - Vector2(0, 7), Vector2(19, 23), palette)
				_line(canvas, p + q, p + Vector2(0, 22), Color(palette.trim), 5)
			_ellipse(canvas, p + Vector2(-34, -30), Vector2(14, 7), Color(palette.dark), Color(palette.light))
			_ellipse(canvas, p + Vector2(0, 23), Vector2(30, 9), Color(palette.dark), Color(palette.energy))
		"barracks":
			for i: int in range(5):
				var q := p + _project_delta(Vector2(-30 + i * 15, 0))
				_building_dome(canvas, q, Vector2(14, 15), palette)
				_poly(canvas, q - Vector2(0, 14), PackedVector2Array([Vector2(-17, 0), Vector2(0, -17), Vector2(19, -2), Vector2(0, 4)]), Color(palette.body), Color(palette.light))
				canvas.draw_circle(q + Vector2(0, -5), 3, Color(palette.energy))
		"factory":
			_building_dome(canvas, p - Vector2(0, 13), Vector2(68, 32), palette)
			_ellipse(canvas, p + Vector2(18, 8), Vector2(28, 24), Color(palette.dark), Color(palette.trim))
			for i: int in range(4):
				var q := p + Vector2(-43 + i * 22, -20 + i * 4)
				_line(canvas, q + Vector2(-7, 30), q + Vector2(0, -13), Color(palette.dark), 5)
			_building_dome(canvas, p + Vector2(16, 14), Vector2(17, 12), palette)
			for side: float in [-1.0, 1.0]: _line(canvas, p + Vector2(side * 59, 8), p + Vector2(side * 29, -41), Color(palette.body), 7)

static func _host_building_fallback(canvas: CanvasItem, p: Vector2, kind: String, palette: Dictionary) -> void:
	match kind:
		"hq":
			_box(canvas, p, Vector2(87, 63), 13, palette)
			_box(canvas, p - Vector2(0, 13), Vector2(57, 43), 18, palette)
			_building_shard(canvas, p - Vector2(0, 31), 17, 43, palette)
			for side: float in [-1.0, 1.0]: _building_shard(canvas, p + Vector2(side * 41, -10), 9, 35, palette)
		"power":
			_box(canvas, p, Vector2(35, 30), 7, palette)
			for side: float in [-1.0, 1.0]: _box(canvas, p + Vector2(side * 24, 0), Vector2(8, 9), 37, palette)
			_ellipse(canvas, p - Vector2(0, 36), Vector2(26, 23), Color.TRANSPARENT, Color(palette.trim))
			_ellipse(canvas, p - Vector2(0, 36), Vector2(22, 19), Color.TRANSPARENT, Color(palette.light))
			canvas.draw_circle(p - Vector2(0, 36), 8, Color(palette.energy))
		"refinery":
			_box(canvas, p, Vector2(63, 54), 6, palette)
			for q: Vector2 in [Vector2(-28, -7), Vector2(20, 4)]:
				_box(canvas, p + q, Vector2(9, 9), 15, palette)
				_poly(canvas, p + q - Vector2(0, 15), PackedVector2Array([Vector2(-20, -13), Vector2(20, -13), Vector2(10, 0), Vector2(-9, 0)]), Color(palette.body), Color(palette.trim))
				_ellipse(canvas, p + q - Vector2(0, 28), Vector2(20, 8), Color(palette.dark), Color(palette.light))
			_line(canvas, p + Vector2(-25, 7), p + Vector2(24, 23), Color(palette.energy), 3)
		"barracks":
			_box(canvas, p, Vector2(74, 27), 5, palette)
			for i: int in range(4):
				var q := p + _project_delta(Vector2(-28 + i * 18, 0))
				_box(canvas, q, Vector2(5, 17), 23, palette)
				_box(canvas, q - Vector2(0, 23), Vector2(14, 23), 4, palette)
				_line(canvas, q + Vector2(3, -10), q + Vector2(3, -20), Color(palette.trim), 2)
		"factory":
			_box(canvas, p, Vector2(81, 62), 9, palette)
			_building_arch(canvas, p + Vector2(0, 6), 40, 40, palette)
			for side: float in [-1.0, 1.0]:
				_poly(canvas, p, PackedVector2Array([Vector2(side * 24, -32), Vector2(side * 67, -48), Vector2(side * 53, -20), Vector2(side * 39, -6)]), Color(palette.body), Color(palette.trim))
			_box(canvas, p + Vector2(0, 12), Vector2(34, 28), 14, palette)
			canvas.draw_circle(p - Vector2(0, 30), 6, Color(palette.energy))

static func _infernal_building_fallback(canvas: CanvasItem, p: Vector2, kind: String, palette: Dictionary) -> void:
	match kind:
		"hq":
			_box(canvas, p, Vector2(87, 60), 17, palette)
			_box(canvas, p - Vector2(0, 17), Vector2(49, 39), 27, palette)
			for side: float in [-1.0, 1.0]:
				_poly(canvas, p, PackedVector2Array([Vector2(side * 19, -32), Vector2(side * 38, -72), Vector2(side * 40, -26)]), Color(palette.dark), Color(palette.trim), 2)
			_line(canvas, p + Vector2(-17, -24), p + Vector2(18, -7), Color(palette.energy), 3)
		"power":
			_building_silo(canvas, p, 20, 49, palette)
			_ellipse(canvas, p - Vector2(0, 49), Vector2(19, 8), Color(palette.dark), Color(palette.trim))
			_ellipse(canvas, p - Vector2(0, 49), Vector2(11, 5), Color(palette.energy))
			for side: float in [-1.0, 1.0]: _line(canvas, p + Vector2(side * 28, 9), p + Vector2(side * 13, -33), Color(palette.dark), 7)
		"refinery":
			for q: Vector2 in [Vector2(-27, -8), Vector2(24, 5)]:
				_building_dome(canvas, p + q - Vector2(0, 9), Vector2(23, 17), palette)
				_ellipse(canvas, p + q - Vector2(0, 20), Vector2(20, 8), Color(palette.dark), Color(palette.trim))
				_ellipse(canvas, p + q - Vector2(0, 20), Vector2(12, 4), Color(palette.energy))
			_box(canvas, p + Vector2(0, 22), Vector2(58, 14), 5, palette)
			_line(canvas, p + Vector2(-24, 10), p + Vector2(22, 30), Color(palette.trim), 3)
		"barracks":
			_box(canvas, p, Vector2(74, 34), 16, palette)
			for i: int in range(5):
				var q := p + _project_delta(Vector2(-30 + i * 15, 0))
				_poly(canvas, q - Vector2(0, 16), PackedVector2Array([Vector2(-7, 0), Vector2(0, -14), Vector2(8, 0)]), Color(palette.dark), Color(palette.trim))
				_line(canvas, q + Vector2(12, 0), q + Vector2(12, -6), Color(palette.energy), 3)
		"factory":
			_box(canvas, p, Vector2(86, 62), 8, palette)
			_box(canvas, p - Vector2(0, 8), Vector2(35, 27), 18, palette)
			_poly(canvas, p - Vector2(0, 26), PackedVector2Array([Vector2(-34, -7), Vector2(31, -7), Vector2(20, 7), Vector2(-19, 7)]), Color(palette.light), Color(palette.trim))
			for side: float in [-1.0, 1.0]:
				_line(canvas, p + Vector2(side * 53, 10), p + Vector2(side * 48, -43), Color(palette.dark), 7)
				_line(canvas, p + Vector2(side * 48, -43), p + Vector2(side * 19, -33), Color(palette.trim), 5)
			_line(canvas, p + Vector2(-31, 14), p + Vector2(32, 42), Color(palette.energy), 3)

static func _veyr_building_fallback(canvas: CanvasItem, p: Vector2, kind: String, palette: Dictionary) -> void:
	match kind:
		"hq":
			_box(canvas, p, Vector2(83, 61), 9, palette)
			for q: Vector2 in [Vector2(-32, -3), Vector2(33, 8)]: _building_shard(canvas, p + q, 20, 45, palette)
			_building_shard(canvas, p - Vector2(0, 10), 27, 65, palette)
		"power":
			_ellipse(canvas, p, Vector2(34, 15), Color(palette.dark), Color(palette.trim))
			_ellipse(canvas, p - Vector2(0, 34), Vector2(28, 23), Color.TRANSPARENT, Color(palette.light))
			_building_shard(canvas, p - Vector2(0, 17), 12, 39, palette)
			for side: float in [-1.0, 1.0]: _building_shard(canvas, p + Vector2(side * 27, 3), 8, 20, palette)
		"refinery":
			_poly(canvas, p, PackedVector2Array([Vector2(-49, -3), Vector2(-22, -23), Vector2(26, -23), Vector2(49, -1), Vector2(25, 24), Vector2(-23, 24)]), Color(palette.dark), Color(palette.light), 2)
			_ellipse(canvas, p, Vector2(29, 13), Color(palette.body), Color(palette.energy))
			for q: Vector2 in [Vector2(-31, -6), Vector2(2, -19), Vector2(34, 3)]: _building_shard(canvas, p + q, 9, 28, palette)
		"barracks":
			for z: float in [-10.0, 12.0]:
				_line(canvas, p + Vector2(-40, z - 12), p + Vector2(37, z + 24), Color(palette.dark), 7)
				for i: int in range(4):
					_building_shard(canvas, p + Vector2(-28 + i * 18, z + i * 8), 8, 26, palette)
		"factory":
			_box(canvas, p, Vector2(84, 60), 5, palette)
			for side: float in [-1.0, 1.0]:
				_building_shard(canvas, p + Vector2(side * 47, 4), 16, 43, palette)
				_poly(canvas, p, PackedVector2Array([Vector2(side * 47, -36), Vector2(0, -56), Vector2(0, -41), Vector2(side * 40, -19)]), Color(palette.body), Color(palette.light))
			_building_shard(canvas, p + Vector2(0, 3), 20, 27, palette)
			_line(canvas, p + Vector2(-33, 22), p + Vector2(27, 47), Color(palette.trim), 3)

static func _draw_construction(canvas: CanvasItem, entity: Dictionary, p: Vector2) -> void:
	var size: Vector2 = Vector2(DATA.spec(str(entity.kind)).size)
	var height: float = _height(str(entity.kind))
	var built: float = float(entity.get("build_progress", 1.0))
	var ground: PackedVector2Array = _footprint(size)
	for corner: Vector2 in ground:
		_line(canvas,p+corner,p+corner-Vector2(0,height),Color("d0ba70"),1.2)
	_poly(canvas,p,ground,Color(0.05,.08,.09,.25),Color("d0ba70"))
	canvas.draw_rect(Rect2(p+Vector2(-31,10),Vector2(62,5)),Color("19282c"))
	canvas.draw_rect(Rect2(p+Vector2(-30,11),Vector2(60*built,3)),Color("d0ba70"))

static func _draw_status(canvas: CanvasItem, entity: Dictionary, p: Vector2, selected: bool, font: Font, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	var building: bool = bool(DATA.spec(kind).get("building",false))
	var max_hp: float = float(entity.get("maxhp",DATA.spec(kind).hp))
	var hp: float = float(entity.get("hp",max_hp))
	if selected or building or hp<max_hp:
		var width: float = 66.0 if building else (36.0 if kind=="tank" else 24.0)
		var top: float = -_height(kind)-((Vector2(DATA.spec(kind).size).x+Vector2(DATA.spec(kind).size).y)*.25)-8 if building else (-51.0 if kind=="tank" else -43.0)
		var anchor: Vector2 = p+Vector2(-width*.5,top)
		canvas.draw_rect(Rect2(anchor-Vector2.ONE,Vector2(width+2,5)),Color("102025"))
		canvas.draw_rect(Rect2(anchor,Vector2(width*clampf(hp/max_hp,0,1),3)),Color(palette.energy) if hp/max_hp>.35 else Color("e8a17b"))
	if building:
		var label: String = DATA.faction_title(kind, style_for(entity))
		var label_width: float = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
		var y: float = (Vector2(DATA.spec(kind).size).x+Vector2(DATA.spec(kind).size).y)*.25+17
		canvas.draw_rect(Rect2(p+Vector2(-label_width*.5-4,y-11),Vector2(label_width+8,14)),Color(0.025,.045,.05,.68))
		canvas.draw_string(font,p+Vector2(-label_width*.5,y),label,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("dce4cf"))
		var queue: Array = entity.get("queue",[])
		if not queue.is_empty():
			var item: Dictionary = queue[0]
			var ratio: float = clampf(1.0-float(item.remaining)/maxf(.001,float(item.total)),0,1)
			canvas.draw_rect(Rect2(p+Vector2(-30,y+5),Vector2(60,3)),Color("16282d"))
			canvas.draw_rect(Rect2(p+Vector2(-30,y+5),Vector2(60*ratio,3)),Color("d0bb7e"))

static func _expansion_body(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	var style: String = style_for(entity)
	var index: int = EXPANSION_UNIT_KINDS.find(kind)
	var heavy: bool = kind in ["breacher", "suppressor", "artillery", "destroyer", "juggernaut", "siege_tank"]
	var width: float = 24.0 if heavy else 16.0
	var top: float = -24.0 if heavy else -29.0
	match style:
		"humans":
			_poly(canvas, p, PackedVector2Array([Vector2(-width, -16), Vector2(-width * .5, -27), Vector2(width * .75, -24), Vector2(width, -10), Vector2(0, -4)]), Color(palette.body), Color(palette.light), 1.3)
			_box(canvas, p + Vector2(0, -23), Vector2(width * .8, 10), 8, palette)
			_line(canvas, p + Vector2(-width * .65, -13), p + Vector2(-width * .18, -9), Color(palette.energy), 1.0)
		"iron_synod":
			_ellipse(canvas, p + Vector2(0, -17), Vector2(width, 12), Color(palette.dark), Color(palette.light))
			for side: float in [-1.0, 1.0]:
				_ellipse(canvas, p + Vector2(side * width * .4, -23), Vector2(width * .58, 11), Color(palette.body), Color(palette.light))
				for rib: int in range(3): _line(canvas, p + Vector2(side * 2, -29 + rib * 6), p + Vector2(side * width * .8, -25 + rib * 5), Color(palette.trim))
			canvas.draw_circle(p + Vector2(0, -29), 4.0, Color(palette.energy))
		"kharuun":
			_ellipse(canvas, p + Vector2(0, -17), Vector2(width, 12), Color(palette.dark), Color(palette.trim))
			for leaf: int in range(3):
				var x: float = (leaf - 1) * width * .5
				_poly(canvas, p + Vector2(x, -22), PackedVector2Array([Vector2(-9, 3), Vector2(-5, -11), Vector2(5, -9), Vector2(9, 6)]), Color(palette.body), Color(palette.light))
			canvas.draw_circle(p + Vector2(0, -28), 4, Color(palette.energy))
		"heavenly_host":
			_poly(canvas, p, PackedVector2Array([Vector2(-width * .5, -33), Vector2(width * .5, -33), Vector2(width * .7, -15), Vector2(0, -6), Vector2(-width * .6, -16)]), Color(palette.body), Color(palette.light))
			for side: float in [-1.0, 1.0]: _poly(canvas, p, PackedVector2Array([Vector2(side * 5, -29), Vector2(side * (width + 7), -34), Vector2(side * width, -18), Vector2(side * 5, -17)]), Color(palette.light), Color(palette.trim))
			_ellipse(canvas, p - Vector2(0, 39), Vector2(10, 4), Color.TRANSPARENT, Color(palette.trim))
		"infernal_legion":
			_poly(canvas, p, PackedVector2Array([Vector2(-width, -31), Vector2(width, -29), Vector2(width * .7, -13), Vector2(0, -4), Vector2(-width * .6, -15)]), Color(palette.dark), Color(palette.body), 2)
			for side: float in [-1.0, 1.0]: _poly(canvas, p, PackedVector2Array([Vector2(side * 8, -28), Vector2(side * 14, -42), Vector2(side * 5, -35)]), Color(palette.trim), Color(palette.light))
			canvas.draw_rect(Rect2(p + Vector2(-5, -24), Vector2(10, 5)), Color(palette.energy))
		"veyr":
			_building_shard(canvas, p - Vector2(0, 5), width * .7, 34, palette)
			for side: float in [-1.0, 1.0]: _building_shard(canvas, p + Vector2(side * width * .7, -5), 7, 22, palette)
	var direction: Vector2 = _weapon_direction(entity)
	if kind in ["guardian", "breacher"]:
		_poly(canvas, p + Vector2(0, -17), PackedVector2Array([Vector2(-width * .7, -13), Vector2(width * .7, -10), Vector2(width * .5, 8), Vector2(0, 13), Vector2(-width * .6, 6)]), Color(palette.body), Color(palette.trim), 2)
	elif kind in ["medic", "disruptor", "commander"]:
		_ellipse(canvas, p + Vector2(0, -35), Vector2(9 + index % 3, 9), Color.TRANSPARENT, Color(palette.trim))
		canvas.draw_circle(p + Vector2(0, -35), 3.2, Color(palette.energy))
		if kind == "commander":
			for side: float in [-1.0, 1.0]: _line(canvas, p + Vector2(side * 9, -24), p + Vector2(side * 11, -45), Color(palette.trim), 1.5)
	elif kind == "mechanic":
		for side: float in [-1.0, 1.0]:
			_line(canvas, p + Vector2(side * 11, -20), p + Vector2(side * 19, -31), Color(palette.trim), 3)
			_line(canvas, p + Vector2(side * 19, -31), p + Vector2(side * 14, -37), Color(palette.light), 2)
	elif kind == "scout":
		_line(canvas, p + Vector2(0, -25), p + Vector2(0, -41), Color(palette.trim), 1.5)
		_ellipse(canvas, p - Vector2(0, 40), Vector2(7, 3), Color(palette.light), Color(palette.trim))
	else:
		var count: int = 2 if kind in ["skirmisher", "lancer", "destroyer", "mortar"] else (3 if kind in ["suppressor", "juggernaut", "siege_tank"] else 1)
		var length: float = 26.0 if kind in ["sniper", "artillery", "siege_tank"] else 16.0
		for barrel: int in range(count):
			var start: Vector2 = p + Vector2((barrel - (count - 1) * .5) * 5, top)
			_line(canvas, start, start + direction * length, Color(palette.dark), 4)
			_line(canvas, start - Vector2(0, 1), start + direction * length - Vector2(0, 1), Color(palette.light), 1.2)
			if style in ["kharuun", "veyr"]: canvas.draw_circle(start + direction * length * .7, 2.2, Color(palette.energy))

static func _expansion_building_body(canvas: CanvasItem, entity: Dictionary, p: Vector2, palette: Dictionary) -> void:
	var kind: String = str(entity.kind)
	var style: String = style_for(entity)
	var small: bool = kind in ["outpost", "sentry", "bastion", "relay"]
	var width: float = 46.0 if small else 72.0
	var depth: float = 38.0 if small else 58.0
	match style:
		"humans":
			_box(canvas, p, Vector2(width, depth), 24, palette)
			for side: float in [-1.0, 1.0]: _box(canvas, p + Vector2(side * width * .35, 0), Vector2(8, depth), 29, palette)
		"iron_synod":
			_ellipse(canvas, p - Vector2(0, 13), Vector2(width * .74, depth * .6), Color(palette.body), Color(palette.light))
			for i: int in range(5): _line(canvas, p + Vector2(-width * .5 + i * width * .25, 4), p + Vector2(-width * .35 + i * width * .2, -34), Color(palette.trim), 2.5)
		"kharuun":
			for i: int in range(5):
				var q := Vector2(-width * .4 + i * width * .2, -12 + absf(i - 2) * 3)
				_ellipse(canvas, p + q, Vector2(width * .28, 21), Color(palette.body), Color(palette.light))
		"heavenly_host":
			_box(canvas, p, Vector2(width, depth), 25, palette)
			for side: float in [-1.0, 1.0]: _building_shard(canvas, p + Vector2(side * width * .55, 3), 7, 44, palette)
			_ellipse(canvas, p - Vector2(0, 35), Vector2(width * .5, 8), Color.TRANSPARENT, Color(palette.trim))
		"infernal_legion":
			_box(canvas, p, Vector2(width, depth), 24, palette)
			for side: float in [-1.0, 1.0]: _poly(canvas, p, PackedVector2Array([Vector2(side * width * .5, 0), Vector2(side * width * .5, -47), Vector2(side * width * .22, -34)]), Color(palette.dark), Color(palette.trim), 2)
		"veyr":
			for side: float in [-1.0, 1.0]: _building_shard(canvas, p + Vector2(side * width * .45, 3), width * .23, 40, palette)
			_building_shard(canvas, p - Vector2(0, 5), width * .33, 48, palette)
	match kind:
		"outpost":
			_line(canvas, p - Vector2(0, 22), p - Vector2(0, 65), Color(palette.trim), 3)
			_ellipse(canvas, p - Vector2(0, 58), Vector2(16, 7), Color(palette.light), Color(palette.trim))
		"sentry", "bastion":
			_box(canvas, p - Vector2(0, 28), Vector2(23, 18), 10, palette)
			for side: float in [-1.0, 1.0]:
				_line(canvas, p + Vector2(side * 6, -36), p + Vector2(side * 6 + 27, -49), Color(palette.dark), 6 if kind == "bastion" else 3)
				_line(canvas, p + Vector2(side * 6, -38), p + Vector2(side * 6 + 27, -51), Color(palette.light), 1.5)
		"workshop":
			for side: float in [-1.0, 1.0]:
				_line(canvas, p + Vector2(side * 25, -20), p + Vector2(side * 25, -59), Color(palette.trim), 4)
				_line(canvas, p + Vector2(side * 25, -59), p + Vector2(side * 5, -62), Color(palette.light), 3)
		"arsenal":
			for i: int in range(5): _line(canvas, p + Vector2(-20 + i * 9, -32), p + Vector2(-12 + i * 9, -57), Color(palette.light), 4)
		"reactor":
			for side: float in [-1.0, 1.0]:
				_box(canvas, p + Vector2(side * 20, -24), Vector2(18, 18), 38, palette)
				_ellipse(canvas, p + Vector2(side * 20, -62), Vector2(11, 5), Color(palette.energy), Color(palette.trim))
		"sanctum", "relay":
			_ellipse(canvas, p - Vector2(0, 45), Vector2(22, 22), Color.TRANSPARENT, Color(palette.trim))
			_ellipse(canvas, p - Vector2(0, 45), Vector2(14, 14), Color.TRANSPARENT, Color(palette.light))
			canvas.draw_circle(p - Vector2(0, 45), 6, Color(palette.energy))
