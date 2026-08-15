class_name RegionMapCanvas
extends Control
## Etched-map presentation only; registry and travel policy remain outside this control.

var marks: Array[Dictionary] = []:
	set(next_marks):
		marks = next_marks
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DS.STONE_0)
	for x: float in range(0, int(size.x), DS.SPACE_9):
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), DS.STONE_2, DS.BORDER_TRIM_W)
	for y: float in range(0, int(size.y), DS.SPACE_9):
		draw_line(Vector2(0.0, y), Vector2(size.x, y), DS.STONE_2, DS.BORDER_TRIM_W)
	if marks.size() > 1:
		for index: int in range(marks.size() - 1):
			var from := normalized_position(index, marks.size()) * size
			var to := normalized_position(index + 1, marks.size()) * size
			_draw_dashed_line(from, to)


func _draw_dashed_line(from: Vector2, to: Vector2) -> void:
	var distance := from.distance_to(to)
	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < distance:
		var end := minf(cursor + DS.SPACE_4, distance)
		draw_line(from + direction * cursor, from + direction * end, DS.IRON_3, DS.BORDER_TRIM_W)
		cursor += DS.SPACE_6


static func normalized_position(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2(0.58, 0.48)
	var fraction := float(index) / float(count - 1)
	return Vector2(0.16 + fraction * 0.68, 0.65 - sin(fraction * PI) * 0.34)
