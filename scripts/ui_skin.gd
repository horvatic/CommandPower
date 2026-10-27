extends RefCounted

# Small tiled material plates retain their grain and bevels at every window size.
static func plate(state: String = "panel") -> StyleBoxTexture:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var base := Color("20292b") if state == "panel" else Color("293230")
	if state == "hover": base = Color("3c4640")
	if state == "pressed": base = Color("1e2826")
	if state == "disabled": base = Color("1b2324")
	for y: int in range(48):
		for x: int in range(48):
			var grain: float = float(posmod(x * 127 + y * 311 + x * y * 17, 47)) / 46.0 - 0.5
			var brush: float = 0.007 if y % 3 == 0 else -0.004
			var tint := Color(base.r + grain * 0.020 + brush, base.g + grain * 0.020 + brush, base.b + grain * 0.020 + brush)
			var high := Color("59605a") if state != "disabled" else Color("343e3a")
			var low := Color("0b1113")
			if state == "pressed":
				high = Color("0a1113")
				low = Color("48544a")
			if x == 0 or y == 0: tint = high
			if x == 47 or y == 47: tint = low
			if x == 1 or y == 1: tint = base.lightened(0.055)
			if x == 46 or y == 46: tint = base.darkened(0.3)
			image.set_pixel(x, y, tint)
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.texture_margin_left = 3
	style.texture_margin_right = 3
	style.texture_margin_top = 3
	style.texture_margin_bottom = 3
	style.content_margin_left = 1 if state == "panel" else 8
	style.content_margin_right = 1 if state == "panel" else 8
	style.content_margin_top = 1 if state == "panel" else 6
	style.content_margin_bottom = 1 if state == "panel" else 6
	return style
