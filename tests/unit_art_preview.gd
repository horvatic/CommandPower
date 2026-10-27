extends SceneTree

# Full-resolution comparison of every playable mobile role.
# -- --fallback draws procedural bodies; --directions shows all eight atlas facings.
# --capture=/absolute/path.png overrides the default output under /tmp.
var gallery_viewport: SubViewport

class UnitGallery extends Node2D:
	const ART = preload("res://scripts/faction_sprites.gd")
	const DATA = preload("res://scripts/catalog.gd")
	const SUMMARY_SIZE := Vector2i(1600, 1580)
	const DIRECTIONS_SIZE := Vector2i(1600, 3100)
	const ROLES := ["WORKER / HARVEST & CONSTRUCTION", "FRONTLINE / INFANTRY", "HEAVY / ASSAULT"]
	var fallback := false
	var directions := false

	func canvas_size() -> Vector2i:
		return DIRECTIONS_SIZE if directions else SUMMARY_SIZE

	func _center_text(font: Font, point: Vector2, text: String, size: int, color: Color) -> void:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, point - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func _unit(faction: String, kind: String, point: Vector2, scale: float, direction: int = 1) -> void:
		var entity: Dictionary = {"id": ART.STYLES.find(faction) * 3 + ART.UNIT_KINDS.find(kind), "kind": kind, "owner": 0, "faction": faction, "completed": true, "build_progress": 1.0, "hp": DATA.spec(kind).hp, "maxhp": DATA.spec(kind).hp, "cargo": 0.0, "queue": [], "facing": Vector2.from_angle(float(direction) * TAU / 8.0)}
		draw_set_transform(point, 0, Vector2.ONE * scale)
		if fallback:
			ART.draw_body(self, entity, Vector2.ZERO)
		else:
			ART.draw_entity(self, entity, Vector2.ZERO, false, ThemeDB.fallback_font, 0.0)
		draw_set_transform(Vector2.ZERO)

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, Vector2(canvas_size())), Color("0b1418"))
		draw_string(font, Vector2(44, 42), "COMMAND / POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("7ee6c9"))
		var detail := "PROCEDURAL FALLBACKS" if fallback else "PRERENDERED 3D SPRITES"
		detail += "  /  EIGHT FACINGS AT NATIVE SCALE" if directions else "  /  2× DETAIL + NATIVE-SCALE INSET"
		draw_string(font, Vector2(44, 71), "UNIT SILHOUETTES  /  " + detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("cbb87f"))
		if directions:
			_draw_directions(font)
		else:
			_draw_summary(font)

	func _draw_summary(font: Font) -> void:
		for column: int in range(3):
			_center_text(font, Vector2(287 + column * 510, 104), ROLES[column], 13, Color("91aaa6"))
		for row: int in range(ART.STYLES.size()):
			var faction: String = ART.STYLES[row]
			var top: float = 118 + row * 238
			var tint: Color = ART.PALETTES[faction].energy
			draw_rect(Rect2(34, top, 1532, 230), Color("142024") if row % 2 == 0 else Color("101b20"))
			draw_rect(Rect2(34, top, 4, 230), tint)
			draw_string(font, Vector2(51, top + 27), DATA.faction_name(faction).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
			for column: int in range(3):
				var kind: String = ART.UNIT_KINDS[column]
				var left: float = 44 + column * 510
				if column > 0:
					draw_line(Vector2(left - 10, top + 42), Vector2(left - 10, top + 215), Color("25363a"))
				_unit(faction, kind, Vector2(left + 175, top + 166), 2.0)
				draw_rect(Rect2(left + 342, top + 62, 128, 128), Color("0d181d"))
				_unit(faction, kind, Vector2(left + 406, top + 142), 1.0)
				_center_text(font, Vector2(left + 406, top + 193), "NATIVE", 10, Color("718b87"))
				_center_text(font, Vector2(left + 235, top + 218), DATA.faction_title(kind, faction), 16, Color("d5dfd8"))

	func _draw_directions(font: Font) -> void:
		for facing: int in range(8):
			_center_text(font, Vector2(430 + facing * 144, 101), "FACING %d" % facing, 12, Color("91aaa6"))
		for faction_index: int in range(ART.STYLES.size()):
			var faction: String = ART.STYLES[faction_index]
			for role: int in range(3):
				var row: int = faction_index * 3 + role
				var top: float = 112 + row * 164
				var kind: String = ART.UNIT_KINDS[role]
				var tint: Color = ART.PALETTES[faction].energy
				draw_rect(Rect2(34, top, 1532, 158), Color("142024") if faction_index % 2 == 0 else Color("101b20"))
				draw_rect(Rect2(34, top, 4, 158), tint)
				draw_string(font, Vector2(52, top + 37), DATA.faction_name(faction), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
				draw_string(font, Vector2(52, top + 66), DATA.faction_title(kind, faction), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d5dfd8"))
				draw_string(font, Vector2(52, top + 89), ["Worker", "Frontline", "Heavy"][role], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("718b87"))
				for facing: int in range(8):
					_unit(faction, kind, Vector2(430 + facing * 144, top + 104), 1.0, facing)

func _initialize() -> void:
	root.size = Vector2i(1100, 720)
	root.content_scale_size = Vector2i(1100, 720)
	root.title = "CommandPower — Unit art gallery"
	var gallery := UnitGallery.new()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--fallback": gallery.fallback = true
		if argument == "--directions": gallery.directions = true
	gallery_viewport = SubViewport.new()
	gallery_viewport.size = gallery.canvas_size()
	gallery_viewport.world_2d = World2D.new()
	gallery_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery_viewport)
	gallery_viewport.add_child(gallery)
	var preview := TextureRect.new()
	preview.texture = gallery_viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	_capture.call_deferred()

func _capture() -> void:
	var path := "/tmp/commandpower-unit-art.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			path = argument.trim_prefix("--capture=")
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var error: Error = gallery_viewport.get_texture().get_image().save_png(path)
	print("UNIT_ART_CAPTURE ", path, " size=", gallery_viewport.size, " error=", error)
	quit(error)
