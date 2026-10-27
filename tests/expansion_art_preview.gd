extends SceneTree

const ART = preload("res://scripts/faction_sprites.gd")
const DATA = preload("res://scripts/catalog.gd")
var viewport: SubViewport

class Gallery extends Node2D:
	const ART = preload("res://scripts/faction_sprites.gd")
	const DATA = preload("res://scripts/catalog.gd")
	var faction := "humans"
	var fallback := false
	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 1800, 1530), Color("10191b"))
		draw_string(font, Vector2(28, 37), DATA.faction_name(faction).to_upper() + " / EXPANDED ARSENAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, ART.PALETTES[faction].energy)
		draw_string(font, Vector2(28, 63), "ORIGINAL STATIC MODELS / 18 NEW MOBILE ROLES + 8 STRUCTURES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a3b0a2"))
		for index: int in range(ART.EXPANSION_UNIT_KINDS.size()):
			var kind: String = ART.EXPANSION_UNIT_KINDS[index]
			var q := Vector2(150 + (index % 6) * 300, 220 + (index / 6) * 235)
			var e: Dictionary = {"id": index, "kind": kind, "faction": faction, "owner": 0, "hp": DATA.spec(kind, faction).hp, "maxhp": DATA.spec(kind, faction).hp, "completed": true, "facing": Vector2(1, 1)}
			draw_set_transform(q, 0, Vector2(2, 2))
			if fallback: ART.draw_body(self, e, Vector2.ZERO)
			else: ART._draw_cached_body(self, e, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
			var name: String = DATA.faction_title(kind, faction)
			var width: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string(font, q + Vector2(-width * .5, 37), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d4ddd0"))
			draw_string(font, q + Vector2(-width * .5, 56), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("86968b"))
		for index: int in range(ART.EXPANSION_BUILDING_KINDS.size()):
			var kind: String = ART.EXPANSION_BUILDING_KINDS[index]
			var q := Vector2(220 + (index % 4) * 450, 1050 + (index / 4) * 300)
			var e: Dictionary = {"id": index, "kind": kind, "faction": faction, "owner": 0, "hp": DATA.spec(kind, faction).hp, "maxhp": DATA.spec(kind, faction).hp, "completed": true}
			draw_set_transform(q, 0, Vector2(1.3, 1.3))
			if fallback: ART.draw_body(self, e, Vector2.ZERO)
			else: ART._draw_cached_body(self, e, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO)
			var name: String = DATA.faction_title(kind, faction)
			var width: float = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, q + Vector2(-width * .5, 80), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d4ddd0"))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1800, 1530)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gallery := Gallery.new()
	viewport.add_child(gallery)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--fallback": gallery.fallback = true
	for faction: String in ART.STYLES:
		gallery.faction = faction
		gallery.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		viewport.get_texture().get_image().save_png("res://artifacts/expansion-%s%s.png" % [faction, "-fallback" if gallery.fallback else ""])
		print("EXPANSION_GALLERY ", faction)
	quit()
