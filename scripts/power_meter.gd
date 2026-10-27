extends Control

# Sidebar supply column with a separate demand marker, like a classic RTS gauge.
var used: int = 0
var supplied: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(26, 144)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func set_power(demand: int, supply: int) -> void:
	used = maxi(0, demand)
	supplied = maxi(0, supply)
	tooltip_text = "POWER: %d used / %d supplied\nBars: supply. Line: demand.\n%s" % [used, supplied, "LOW POWER: unit training at half speed" if used > supplied else "Sufficient power"]
	queue_redraw()

func _draw() -> void:
	var low: bool = used > supplied
	var strained: bool = supplied > 0 and float(used) / float(supplied) >= 0.85
	var tint := Color("e98164") if low else (Color("cbb86e") if strained else Color("8fa96b"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1219"))
	draw_rect(Rect2(Vector2(.5, .5), size - Vector2.ONE), Color("46544c"), false)
	# Static lightning icon keeps the narrow column recognizable without text.
	draw_colored_polygon(PackedVector2Array([Vector2(14,4),Vector2(8,13),Vector2(12,13),Vector2(10,20),Vector2(18,10),Vector2(14,10)]), tint)
	var gauge := Rect2(6, 25, size.x - 12, maxf(1, size.y - 31))
	var maximum: float = maxf(100, maxf(used, supplied)) * 1.15
	var filled: float = gauge.size.y * float(supplied) / maximum
	var step: float = gauge.size.y / 16.0
	for segment: int in range(16):
		var bottom: float = gauge.end.y - float(segment) * step
		var slot := Rect2(gauge.position.x, bottom - step + 1, gauge.size.x, step - 2)
		draw_rect(slot, Color("24312c"))
		var amount: float = clampf(filled - float(segment) * step, 0, slot.size.y)
		if amount > 0:
			draw_rect(Rect2(slot.position.x, bottom - 1 - amount, slot.size.x, amount), tint)
	var demand_y: float = gauge.end.y - gauge.size.y * float(used) / maximum
	var marker := Color("ff9f78") if low else Color("ead391")
	draw_line(Vector2(3,demand_y), Vector2(size.x-3,demand_y), Color("080d0d"), 4)
	draw_line(Vector2(3,demand_y), Vector2(size.x-3,demand_y), marker, 2)
	draw_colored_polygon(PackedVector2Array([Vector2(2,demand_y-3),Vector2(6,demand_y),Vector2(2,demand_y+3)]), marker)
