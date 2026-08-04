class_name EclipsePips
extends Control
## Eclipse-phase AP pips. Availability is encoded by fill as well as colour.

var current_ap := 0
var maximum_ap := 0


func set_ap(current: int, maximum: int) -> void:
	maximum_ap = maxi(0, maximum)
	current_ap = clampi(current, 0, maximum_ap)
	queue_redraw()


func _draw() -> void:
	if maximum_ap <= 0:
		return
	var gap := float(DS.SPACE_3)
	var available_width := maxf(0.0, size.x - gap * float(maximum_ap - 1))
	var radius := minf(size.y * 0.38, available_width / float(maximum_ap) * 0.38)
	var diameter := radius * 2.0
	var total_width := diameter * float(maximum_ap) + gap * float(maximum_ap - 1)
	var start_x := (size.x - total_width) * 0.5 + radius
	for index in maximum_ap:
		var center := Vector2(start_x + float(index) * (diameter + gap), size.y * 0.5)
		draw_circle(center, radius, DS.METER_TRACK)
		if index < current_ap:
			draw_circle(center, radius * 0.78, DS.BRONZE_3)
		else:
			# An occluded disc remains outlined, so state never depends on hue.
			draw_circle(center + Vector2(radius * 0.3, 0.0), radius * 0.72, DS.STONE_2)
		draw_arc(center, radius, 0.0, TAU, 24, DS.IRON_3, 1.5, true)
