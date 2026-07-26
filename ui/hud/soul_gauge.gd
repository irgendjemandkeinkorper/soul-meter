class_name SoulGauge
extends Control
## The game's title mechanic and its most valuable pixel (DS: components/hud/SoulGauge).
## Must appear on every screen where magic can be spent. Always the rightmost element
## in the HUD bar. Bronze fill, never violet: the Gauge is ledgered, not magical.
## Bound to GameState.soul_meter; numerals in the mono face, always exact.

## Canon agreement-integrity states (Module 8): constant / skip / feedback / hush.
@export_enum("constant", "skip", "feedback", "hush") var state: String = "constant":
	set(v):
		state = v
		queue_redraw()
## The Crystalline Registry's foreclosure floor (0-100); shown whenever a writ is in force.
## Negative = no writ.
@export_range(-1, 100) var audit: int = -1:
	set(v):
		audit = v
		queue_redraw()

var _value: float = 50.0
var _pulse_time := 0.0

@onready var _label: Label = $Value


func _ready() -> void:
	custom_minimum_size = Vector2(220, DS.METER_H_LG + 22)
	_value = GameState.soul_meter
	GameState.soul_meter_changed.connect(_on_meter_changed)
	_refresh_label()


func _process(delta: float) -> void:
	if state == "feedback":  # feedback pulses (--dur-ambient); other states rest
		_pulse_time += delta
		queue_redraw()


func _on_meter_changed(value: float) -> void:
	_value = value
	_refresh_label()
	queue_redraw()


func _refresh_label() -> void:
	_label.text = "%d%%" % roundi(_value)


func _state_color() -> Color:
	match state:
		"skip": return DS.STATE_SKIP
		"feedback": return DS.STATE_FEEDBACK
		"hush": return DS.STATE_HUSH
		_: return DS.STATE_CONSTANT


func _draw() -> void:
	var bar := Rect2(0, size.y - DS.METER_H_LG, size.x, DS.METER_H_LG)

	# Track: an inset well cut into the void.
	draw_rect(bar, DS.METER_TRACK)
	draw_rect(bar, DS.VOID_0, false, 1.0)

	# Fill: bronze gradient (--meter-soul-a -> --meter-soul-b), left to right.
	var w := bar.size.x * clampf(_value / 100.0, 0.0, 1.0)
	if w > 0.5:
		var pts := PackedVector2Array([
			bar.position, Vector2(bar.position.x + w, bar.position.y),
			Vector2(bar.position.x + w, bar.end.y), Vector2(bar.position.x, bar.end.y),
		])
		var cols := PackedColorArray([
			DS.METER_SOUL_A, DS.METER_SOUL_B, DS.METER_SOUL_B, DS.METER_SOUL_A,
		])
		draw_polygon(pts, cols)

	# State edge: the agreement's condition rims the gauge (pulsing when Feedback).
	var edge := _state_color()
	if state == "feedback":
		edge.a = 0.55 + 0.45 * absf(sin(_pulse_time * TAU / DS.DUR_AMBIENT * 2.0))
	draw_rect(bar.grow(1), edge, false, 1.0)

	# Audit floor: the Registry's mark — precise, and uncomfortable.
	if audit >= 0:
		var ax := bar.position.x + bar.size.x * (audit / 100.0)
		draw_line(Vector2(ax, bar.position.y - 3), Vector2(ax, bar.end.y + 3), DS.GILD_2, 2.0)
