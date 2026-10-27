extends SceneTree

class ArtGallery extends Node2D:
	const ART = preload("res://scripts/faction_sprites.gd")
	const DATA = preload("res://scripts/catalog.gd")
	const NAMES := ["HUMAN EMPIRE", "IRON SYNOD", "KHARUUN BROOD", "HEAVENLY HOST", "INFERNAL LEGION", "VEYR DOMINION"]
	const DETAILS := ["Industrial armor / arcane circuitry", "Alien anatomy / cybernetic carapace", "Bark / vines / cultivated warforms", "Ivory / gold / radiant spirit cores", "Obsidian / horns / infernal embers", "Faceted crystal / resonance cores"]
	const LABELS := [
		["Prospector", "Vanguard", "Paladin Tank"],
		["Synapse Harvester", "Convergent Legionary", "Chimera Tank"],
		["Root Tender", "Barkguard", "Seedspine"],
		["Sanctifier", "Seraph Guard", "Sanctum Colossus"],
		["Ashshaper", "Hellblade", "Infernal Behemoth"],
		["Shard Tender", "Crystal Guard", "Monolith"]
	]

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1440,1000),Color("0a151c"))
		draw_string(font,Vector2(28,39),"COMMAND / POWER",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("7ee6c9"))
		draw_string(font,Vector2(28,66),"ISOMETRIC FACTION ART  /  ORIGINAL PRERENDERED 3D SPRITES",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("cbb87f"))
		for entry: Dictionary in [{"x":398,"name":"WORKER"},{"x":620,"name":"LINE UNIT"},{"x":850,"name":"HEAVY UNIT"},{"x":1190,"name":"BASE ARCHITECTURE"}]:
			draw_string(font,Vector2(entry.x-60,96),entry.name,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8ea9ad"))
		for row: int in range(6):
			var top: float = 108.0+float(row)*145.0
			var style: String = ART.STYLES[row]
			var palette: Dictionary = ART.PALETTES[style]
			draw_rect(Rect2(18,top,1404,137),Color("11212a") if row%2==0 else Color("0e1c24"))
			draw_rect(Rect2(18,top,4,137),Color(palette.energy))
			draw_string(font,Vector2(39,top+42),NAMES[row],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(palette.energy))
			draw_string(font,Vector2(39,top+64),DETAILS[row],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("8ea4a8"))
			for column: int in range(3):
				var kind: String = ["worker","infantry","tank"][column]
				var point := Vector2([400,625,865][column],top+98)
				var entity: Dictionary = {"kind":kind,"owner":0,"faction":style,"pos":Vector2.ZERO,"hp":DATA.spec(kind).hp,"maxhp":DATA.spec(kind).hp,"facing":Vector2(1,.4),"completed":true,"build_progress":1.0,"queue":[],"cargo":20}
				var preview_scale: float = 1.1 if kind == "tank" else 1.55
				draw_set_transform(point,0,Vector2.ONE * preview_scale)
				ART.draw_entity(self,entity,Vector2.ZERO,false,font)
				draw_set_transform(Vector2.ZERO)
				var title: String = LABELS[row][column]
				var title_width: float = font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
				draw_string(font,point+Vector2(-title_width*.5,27),title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("d5dfd8"))
			var base: Dictionary = {"kind":"hq","owner":0,"faction":style,"pos":Vector2.ZERO,"hp":1800,"maxhp":1800,"completed":true,"build_progress":1.0,"queue":[]}
			draw_set_transform(Vector2(1220,top+77),0,Vector2(.72,.72))
			ART.draw_entity(self,base,Vector2.ZERO,false,font)
			draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	root.size = Vector2i(1440,1000)
	root.content_scale_size = Vector2i(1440,1000)
	root.title = "CommandPower — Faction art gallery"
	root.add_child(ArtGallery.new())
	_capture.call_deferred()

func _capture() -> void:
	var path := "/tmp/commandpower-faction-art.png"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			path=argument.trim_prefix("--capture=")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(path)
	print("FACTION_ART_CAPTURE ",path," error=",error)
	quit(error)
