extends Control
## Quiet scored stone and an eclipse engraving, behind opaque reading surfaces.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DS.VOID_1)
	var random := RandomNumberGenerator.new()
	random.seed = 731
	for index: int in 280:
		var start := Vector2(random.randf_range(0, size.x), random.randf_range(0, size.y))
		draw_line(start, start + Vector2(random.randf_range(DS.SPACE_4, DS.SPACE_9), 1), Color(DS.IRON_1, 0.16), 1)
	var inset := float(DS.SPACE_6)
	draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2), DS.IRON_0, false, 1)
	for x: float in [inset, size.x - inset]:
		for y: float in [inset, size.y - inset]:
			var direction := Vector2(1 if x < size.x * 0.5 else -1, 1 if y < size.y * 0.5 else -1)
			draw_line(Vector2(x, y), Vector2(x + direction.x * DS.SPACE_9, y), DS.IRON_3, DS.BORDER_TRIM_W)
			draw_line(Vector2(x, y), Vector2(x, y + direction.y * DS.SPACE_9), DS.IRON_3, DS.BORDER_TRIM_W)
	var center := Vector2(size.x * 0.5, DS.SPACE_9 * 2)
	for radius: float in [float(DS.SPACE_7), float(DS.SPACE_8)]:
		draw_arc(center, radius, 0, TAU, 64, DS.IRON_1, 1, true)
	draw_circle(center + Vector2(DS.SPACE_4, -DS.SPACE_3), DS.SPACE_7, DS.VOID_1)
	draw_line(Vector2(DS.SPACE_9, DS.SPACE_9 * 3), Vector2(size.x - DS.SPACE_9, DS.SPACE_9 * 3), DS.IRON_1, 1)
