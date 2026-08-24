class_name WheelWidget
extends Control
## FR-604's Wheel widget (#100): draws the ten-element Wheel as a ring in the DS
## visual language and marks a member's major/minor element affinities. Pure
## presentation over `ElementWheel.ORDER` — no element logic lives here.

const RING_COLOR := DS.IRON_2
const SPOKE_COLOR := DS.IRON_1
const NODE_COLOR := DS.IRON_3
const MAJOR_COLOR := DS.BRONZE_3
const MINOR_COLOR := DS.VIOLET_3
const NODE_RADIUS := 7.0
const MARK_RADIUS := 12.0

var _major: StringName = &""
var _minor: StringName = &""


func _init() -> void:
	custom_minimum_size = Vector2(260, 260)


func set_elements(major: Variant, minor: Variant) -> void:
	_major = ElementWheel.normalize(major)
	_minor = ElementWheel.normalize(minor)
	queue_redraw()


func major_element() -> StringName:
	return _major


func minor_element() -> StringName:
	return _minor


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(center.x, center.y) - 28.0
	if radius <= 0.0:
		return
	draw_arc(center, radius, 0.0, TAU, 64, RING_COLOR, 2.0, true)
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size() - 2
	var count := ElementWheel.ORDER.size()
	for index in count:
		var angle := TAU * float(index) / float(count) - PI / 2.0
		var point := center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(center, point, SPOKE_COLOR, 1.0, true)
		var element: StringName = ElementWheel.ORDER[index]
		if element == _major:
			draw_circle(point, MARK_RADIUS, MAJOR_COLOR)
		elif element == _minor:
			draw_circle(point, MARK_RADIUS, MINOR_COLOR)
		draw_circle(point, NODE_RADIUS, NODE_COLOR)
		var label := String(element).capitalize()
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var label_point := center + Vector2(cos(angle), sin(angle)) * (radius + 18.0)
		label_point -= label_size / 2.0
		label_point.y += label_size.y * 0.35
		draw_string(
			font, label_point, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, DS.BRONZE_4
		)
