extends SceneTree

const ART = preload("res://scripts/faction_sprites.gd")
var checks := 0
var failures := 0

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_check(ART.team_color({"owner": 0}) == ART.TEAM_COLORS[0] and ART.team_color({"owner": 1}) == ART.TEAM_COLORS[1], "Legacy ownership colors must remain available")
	for faction: String in ART.STYLES:
		for kind: String in ["worker", "infantry", "tank", "scout", "hq", "outpost"]:
			var entity: Dictionary = {"kind": kind, "faction": faction, "owner": 0, "facing": Vector2.DOWN}
			var original: Dictionary = ART.sprite_source(entity)
			var source: Image = original.texture.get_image()
			if source.is_compressed():
				source.decompress()
			var frame: Image = source.get_region(Rect2i(original.source))
			var original_pixels: PackedByteArray = frame.get_data().duplicate()
			entity["team_color"] = Color("5388ff")
			_check(ART.team_color(entity) == Color("5388ff"), "Chosen ownership color must override the owner default")
			var blue: Dictionary = ART.sprite_source(entity)
			var blue_image: Image = blue.texture.get_image()
			var blue_pixels: PackedByteArray = blue_image.get_data()
			var changed := 0
			var alpha_preserved := true
			var shade_preserved := true
			for offset: int in range(0, original_pixels.size(), 4):
				alpha_preserved = alpha_preserved and original_pixels[offset + 3] == blue_pixels[offset + 3]
				if original_pixels[offset] != blue_pixels[offset] or original_pixels[offset + 1] != blue_pixels[offset + 1] or original_pixels[offset + 2] != blue_pixels[offset + 2]:
					changed += 1
					var before: int = maxi(original_pixels[offset], maxi(original_pixels[offset + 1], original_pixels[offset + 2]))
					var after: int = maxi(blue_pixels[offset], maxi(blue_pixels[offset + 1], blue_pixels[offset + 2]))
					shade_preserved = shade_preserved and absi(before - after) <= 1
			_check(changed >= 8, "Team paint must visibly affect baked body accents: %s/%s (%d pixels)" % [faction, kind, changed])
			_check(alpha_preserved and shade_preserved, "Team paint must preserve silhouette, shadows, and baked shading: %s/%s" % [faction, kind])
			_check(frame.get_data() == original_pixels, "Team paint must not mutate source art")
			_check(is_same(ART.sprite_source(entity).texture, blue.texture), "Identical unit colors and facings must reuse a shared prepared frame")
			entity["owner"] = 1
			_check(is_same(ART.sprite_source(entity).texture, blue.texture), "Prepared team paint must be shared across ownership slots")
			entity["team_color"] = Color("ff625b")
			var red: Dictionary = ART.sprite_source(entity)
			_check(red.texture.get_image().get_data() != blue_pixels, "Mirror factions must receive visibly different body paint")
			var palette: Dictionary = ART.palette_for(entity)
			_check(palette.energy == entity.team_color and palette.body == ART.PALETTES[faction].body and palette.trim != ART.PALETTES[faction].trim, "Fallback drawing must use chosen accents and preserve faction body materials")
			_check(not ART.PALETTES[faction].has("team_color") and ART.palette_for({"faction": faction}) == ART.PALETTES[faction], "Fallback palette overrides must leave catalog art unchanged")
			var icon: AtlasTexture = ART.icon_texture(kind, faction)
			_check(icon != null and is_same(icon.atlas, original.texture), "Faction icons must retain original cached atlas art")
	print("%s: %d team color checks" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
