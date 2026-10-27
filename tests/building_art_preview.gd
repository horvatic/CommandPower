extends SceneTree

# Render all 30 building variants at their runtime sprite scale.
# -- --fallback uses procedural bodies; --capture=/absolute/path.png changes output.
var gallery_viewport: SubViewport

class BuildingGallery extends Node2D:
	const ART = preload("res://scripts/faction_sprites.gd")
	const DATA = preload("res://scripts/catalog.gd")
	const CANVAS := Vector2(1720, 1600)
	var fallback := false
	var atlas: Texture2D

	func _ready() -> void:
		if not fallback:
			atlas = load("res://assets/sprites/buildings.png")

	func _center_text(font: Font, point: Vector2, text: String, size: int, color: Color) -> void:
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, point - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, CANVAS), Color("0b1418"))
		draw_string(font, Vector2(60, 44), "COMMAND / POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("7ee6c9"))
		draw_string(font, Vector2(60, 72), "BUILDING SILHOUETTES  /  " + ("PROCEDURAL FALLBACKS" if fallback else "PRERENDERED 3D SPRITES") + "  /  NATIVE SCALE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("cbb87f"))
		for column: int in range(ART.BUILDING_KINDS.size()):
			var point := Vector2(220 + column * 320, 105)
			_center_text(font, point, DATA.title(ART.BUILDING_KINDS[column]).to_upper(), 13, Color("8ea4a8"))
		for row: int in range(ART.STYLES.size()):
			var faction: String = ART.STYLES[row]
			var top: float = 116 + row * 240
			var tint: Color = ART.PALETTES[faction].energy
			draw_rect(Rect2(44, top, 1632, 234), Color("142024") if row % 2 == 0 else Color("101b20"))
			draw_rect(Rect2(44, top, 4, 234), tint)
			draw_string(font, Vector2(62, top + 25), DATA.faction_name(faction).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, tint)
			for column: int in range(ART.BUILDING_KINDS.size()):
				var kind: String = ART.BUILDING_KINDS[column]
				var point := Vector2(220 + column * 320, top + 152)
				if column > 0:
					draw_line(Vector2(point.x - 160, top + 38), Vector2(point.x - 160, top + 220), Color("203034"))
				if fallback:
					var entity: Dictionary = {"kind": kind, "owner": 0, "faction": faction, "completed": true}
					ART.draw_body(self, entity, point)
				else:
					var source := Rect2(Vector2(column, row) * ART.BUILDING_CELL, ART.BUILDING_CELL)
					draw_texture_rect_region(atlas, Rect2(point - ART.BUILDING_ANCHOR, ART.BUILDING_CELL), source)
				_center_text(font, Vector2(point.x, top + 222), DATA.title(kind), 14, Color("d5dfd8"))

func _initialize() -> void:
	# Capture an explicit offscreen canvas so desktop window limits never shrink art.
	root.size = Vector2i(1100, 720)
	root.content_scale_size = Vector2i(1100, 720)
	root.title = "CommandPower — Building art gallery"
	gallery_viewport = SubViewport.new()
	gallery_viewport.size = Vector2i(BuildingGallery.CANVAS)
	gallery_viewport.world_2d = World2D.new()
	gallery_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(gallery_viewport)
	var gallery := BuildingGallery.new()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--fallback":
			gallery.fallback = true
	gallery_viewport.add_child(gallery)
	var preview := TextureRect.new()
	preview.texture = gallery_viewport.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	_capture.call_deferred()

func _capture() -> void:
	var path := "/tmp/commandpower-buildings.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			path = argument.trim_prefix("--capture=")
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var error: Error = gallery_viewport.get_texture().get_image().save_png(path)
	print("BUILDING_ART_CAPTURE ", path, " error=", error)
	quit(error)
