extends RefCounted

const SPRITES = preload("res://scripts/faction_sprites.gd")
const DATA = preload("res://scripts/catalog.gd")
static var _fire: Texture2D
static var _smoke: Texture2D
static var _glow: Texture2D

static func _noise(seed: int, index: int) -> float:
	return float(posmod(seed * 73856093 ^ index * 19349663, 997)) / 997.0

static func _prepare_textures() -> void:
	if _fire != null:
		return
	var fire := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var smoke := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var glow := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		for x: int in range(64):
			var q := (Vector2(x, y) - Vector2(31.5, 31.5)) / 31.5
			var angle: float = q.angle()
			var grain: float = _noise(x + 41, y + 17)
			var edge: float = 1.0 + sin(angle * 7.0) * 0.065 + cos(angle * 11.0 + 1.2) * 0.045
			var r: float = q.length() / edge
			var fire_alpha: float = (1.0 - smoothstep(0.58, 1.0, r)) * (0.82 + grain * 0.18)
			var fire_color: Color = Color("fff2bc").lerp(Color("f98d29"), smoothstep(0.0, 0.54, r))
			fire_color = fire_color.lerp(Color("9a3318"), smoothstep(0.52, 0.92, r))
			fire_color.a = fire_alpha
			fire.set_pixel(x, y, fire_color)
			var shade: float = clampf(0.35 - q.y * 0.12 + sin(q.x * 13.0 + q.y * 8.0) * 0.025 + grain * 0.04, 0.0, 1.0)
			smoke.set_pixel(x, y, Color(shade * 0.88, shade * 0.91, shade, (1.0 - smoothstep(0.3, 1.0, r)) * (0.75 + grain * 0.25)))
			glow.set_pixel(x, y, Color(1.0, 0.56, 0.18, pow(maxf(0.0, 1.0 - q.length()), 2.0)))
	_fire = ImageTexture.create_from_image(fire)
	_smoke = ImageTexture.create_from_image(smoke)
	_glow = ImageTexture.create_from_image(glow)

static func _puff(canvas: CanvasItem, texture: Texture2D, center: Vector2, size: Vector2, tint: Color) -> void:
	canvas.draw_texture_rect(texture, Rect2(center - size * 0.5, size), false, tint)

static func draw_effect(canvas: CanvasItem, effect: Dictionary, p: Vector2) -> void:
	var duration: float = float(effect.duration)
	var age: float = clampf(duration - float(effect.ttl), 0.0, duration)
	if duration <= 0.0 or age >= duration:
		return
	_prepare_textures()
	var progress: float = age / duration
	var building: bool = bool(effect.get("building", DATA.spec(str(effect.kind)).get("building", false)))
	var seed: int = int(effect.get("seed", effect.get("id", 0)))
	var radius: float = clampf(float(effect.radius), 8.0, 64.0)
	var extent: float = radius * 1.3 if building else (30.0 if str(effect.kind) == "tank" else 19.0)
	var body_p: Vector2 = p if building else p + SPRITES.hover_offset(effect, float(effect.get("elapsed_at_death", 0.0)))
	# Warm ground illumination is an ellipse in the existing projected plane.
	_puff(canvas, _glow, p, Vector2(extent * 5.0, extent * 2.0), Color(1, 1, 1, (1.0 - smoothstep(0.0, 0.48, progress)) * 0.7))
	SPRITES.draw_destruction_body(canvas, effect, body_p, progress)
	# Rear smoke rises behind the hot blast; each puff has a stable, distinct trajectory.
	var smoke_count: int = 9 if building else 5
	for i: int in range(smoke_count):
		var delay: float = float(i) * (0.055 if building else 0.025)
		var t: float = age - delay
		if t < 0.0:
			continue
		var life: float = duration - delay
		var fade: float = smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(life * 0.45, life, t))
		var spread: float = (_noise(seed, i + 4) - 0.5) * extent * 1.8
		var drift: float = (8.0 + _noise(seed, i + 31) * 13.0) * t
		var center := p + Vector2(spread + drift, -extent * 0.25 - t * (23.0 + _noise(seed, i + 22) * 24.0))
		var size: float = extent * (0.7 + _noise(seed, i + 18) * 0.5) + t * 24.0
		_puff(canvas, _smoke, center, Vector2(size * 1.2, size), Color(1, 1, 1, fade * 0.85))
	# Multiple delayed fireballs give large structures a cascading collapse.
	var blast_count: int = 7 if building else 3
	for i: int in range(blast_count):
		var delay: float = float(i) * (0.095 if building else 0.045)
		var t: float = age - delay
		var life: float = 0.68 if building else 0.45
		if t < 0.0 or t >= life:
			continue
		var phase: float = t / life
		var angle: float = _noise(seed, i + 70) * TAU
		var spread := Vector2(cos(angle), sin(angle) * 0.45) * extent * (0.0 if i == 0 else 0.65)
		var center := p + spread - Vector2(0, extent * 0.2 + t * 24.0)
		var size: float = extent * (0.8 + sin(phase * PI * 0.85) * 0.85) * (1.0 if i == 0 else 0.75)
		var tint := Color.WHITE.lerp(Color("9e482c"), smoothstep(0.25, 1.0, phase))
		tint.a = 1.0 - smoothstep(0.35, 1.0, phase)
		_puff(canvas, _fire, center, Vector2(size, size * 1.12), tint)
	# Ballistic panel fragments and short-lived incandescent sparks; fixed work per death.
	var fragments: int = 18 if building else 9
	var palette: Dictionary = SPRITES.PALETTES[SPRITES.style_for(effect)]
	for i: int in range(fragments):
		var life: float = (1.2 if building else 0.85) + _noise(seed, i + 109) * 0.25
		if age >= life:
			continue
		var angle: float = _noise(seed, i + 81) * TAU
		var velocity := Vector2(cos(angle), sin(angle) * 0.48) * (25.0 + _noise(seed, i + 93) * extent * 2.0)
		var lift: float = 40.0 + _noise(seed, i + 127) * 55.0
		var flight_time: float = minf(age, lift / 85.0)
		var flight: Vector2 = velocity * flight_time + Vector2(0, -lift * flight_time + 85.0 * flight_time * flight_time)
		var center: Vector2 = p + flight - Vector2(0, 10)
		var fade: float = 1.0 - smoothstep(life * 0.7, life, age)
		if i % 3 == 0:
			var tint := Color("ffd790")
			tint.a = fade * (1.0 - smoothstep(0.12, 0.65, age))
			canvas.draw_line(center - velocity.normalized() * 5.0, center, tint, 1.5, true)
		else:
			var size: float = (3.5 if building else 2.0) + _noise(seed, i + 141) * 2.0
			var rotation: float = angle + age * (3.0 + _noise(seed, i + 150) * 5.0)
			var points := PackedVector2Array()
			for corner: Vector2 in [Vector2(-1, -0.5), Vector2(0.8, -0.7), Vector2(1, 0.4), Vector2(-0.7, 0.7)]:
				points.append(center + corner.rotated(rotation) * size)
			var tint: Color = Color(palette.body).lerp(Color("443830"), minf(1.0, age * 2.0))
			tint.a = fade
			canvas.draw_colored_polygon(points, tint)
			canvas.draw_line(points[0], points[1], Color(0.68, 0.57, 0.43, fade), 1.0, true)
