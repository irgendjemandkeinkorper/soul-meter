class_name BalanceArcs
extends Control
## Twin mirrored Balance arcs. Side and fill length encode the value without
## relying on the Chaos/Order colours.

var balance := 0


func set_balance(value: int) -> void:
	balance = clampi(value, -100, 100)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x * 0.18, size.y * 0.42)
	if radius <= 1.0:
		return
	var midpoint := size * 0.5
	var left_center := midpoint - Vector2(radius, 0.0)
	var right_center := midpoint + Vector2(radius, 0.0)
	var width := maxf(2.0, radius * 0.12)

	# The inward halves meet on the centre axis.
	draw_arc(left_center, radius, -PI * 0.5, PI * 0.5, 32, DS.IRON_1, width, true)
	draw_arc(right_center, radius, PI * 0.5, PI * 1.5, 32, DS.IRON_1, width, true)
	var magnitude := absf(float(balance)) / 100.0
	if balance < 0:
		draw_arc(
			left_center,
			radius,
			-PI * 0.5 * magnitude,
			PI * 0.5 * magnitude,
			32,
			DS.CINDER_3,
			width,
			true,
		)
	elif balance > 0:
		draw_arc(
			right_center,
			radius,
			PI - PI * 0.5 * magnitude,
			PI + PI * 0.5 * magnitude,
			32,
			DS.BRONZE_3,
			width,
			true,
		)
	draw_line(midpoint - Vector2(0.0, radius * 0.28), midpoint + Vector2(0.0, radius * 0.28), DS.PARCHMENT, 2.0, true)
