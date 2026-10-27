extends SceneTree

const ART = preload("res://scripts/faction_sprites.gd")
const MODELS = preload("res://scripts/sprite_models_3d.gd")
var checks := 0
var failures := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_check(ART.EXPANSION_UNIT_KINDS.size() == 18 and ART.EXPANSION_BUILDING_KINDS.size() == 8, "Every faction must gain 18 unit and 8 building art roles")
	var all_units: Dictionary = {}
	var buildings: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/expansion_buildings.png"))
	_check(buildings != null and buildings.get_size() == Vector2i(2560, 1536), "Expansion building atlas must fit 8 roles and 6 factions")
	for style: String in ART.STYLES:
		var units: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/units_%s.png" % style))
		_check(units != null and units.get_size() == Vector2i(1024, 2304), "Each expansion unit atlas must fit 18 roles and 8 facings: " + style)
		if units == null:
			continue
		for row: int in range(ART.EXPANSION_UNIT_KINDS.size()):
			var kind: String = ART.EXPANSION_UNIT_KINDS[row]
			var facings: Dictionary = {}
			for facing: int in range(8):
				var frame: Image = units.get_region(Rect2i(facing * 128, row * 128, 128, 128))
				_check_frame(frame, style + "/" + kind + "/" + str(facing))
				var digest: String = frame.get_data().hex_encode().sha256_text()
				facings[digest] = true
				if facing == 1:
					_check(not all_units.has(digest), "Every faction-role sprite must be distinct: " + style + "/" + kind)
					all_units[digest] = true
			_check(facings.size() >= 4, "Directional unit equipment must show distinct facing silhouettes: " + style + "/" + kind)
			var model: Node3D = MODELS.build(style, kind)
			_check(model.get_child_count() >= 10, "Expanded units must have complete offline model assemblies: " + style + "/" + kind)
			model.free()
			_check_source(style, kind)
		for column: int in range(ART.EXPANSION_BUILDING_KINDS.size()):
			var kind: String = ART.EXPANSION_BUILDING_KINDS[column]
			if buildings != null:
				_check_frame(buildings.get_region(Rect2i(column * 320, ART.STYLES.find(style) * 256, 320, 256)), style + "/" + kind)
			var model: Node3D = MODELS.build(style, kind)
			_check(model.get_child_count() >= 10, "Expanded buildings must have complete offline model assemblies: " + style + "/" + kind)
			model.free()
			_check_source(style, kind)
	print("%s: %d expansion art checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check_frame(frame: Image, label: String) -> void:
	var pixels: PackedByteArray = frame.get_data()
	var opaque := 0
	for offset: int in range(3, pixels.size(), 4):
		if pixels[offset] > ART.SHADOW_ALPHA_MAX:
			opaque += 1
	_check(opaque > 50, "Each atlas frame must contain a complete opaque body: " + label)
	var clear_border := true
	for x: int in range(frame.get_width()):
		clear_border = clear_border and frame.get_pixel(x, 0).a < .01 and frame.get_pixel(x, frame.get_height() - 1).a < .01
	for y: int in range(frame.get_height()):
		clear_border = clear_border and frame.get_pixel(0, y).a < .01 and frame.get_pixel(frame.get_width() - 1, y).a < .01
	_check(clear_border, "Atlas cell outer borders must remain transparent and unclipped: " + label)

func _check_source(style: String, kind: String) -> void:
	var item: Dictionary = ART.sprite_source({"kind": kind, "faction": style, "facing": Vector2(1, 1)})
	_check(item.texture != null and Rect2(Vector2.ZERO, Vector2(item.texture.get_size())).encloses(item.source), "Runtime and destruction art must resolve a valid frame: " + style + "/" + kind)
	var icon: AtlasTexture = ART.icon_texture(kind, style)
	_check(icon != null and Rect2(Vector2.ZERO, Vector2(icon.atlas.get_size())).encloses(icon.region), "Every expansion role must have a valid faction sidebar icon: " + style + "/" + kind)
