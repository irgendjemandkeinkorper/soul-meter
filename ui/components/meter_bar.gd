class_name MeterBar
extends Control
## Token-driven meter with an optional trailing drain segment.

enum MeterSize { SMALL, BASE, LARGE }

@export_range(0.0, 1.0, 0.01) var value := 1.0:
	set(next_value):
		value = clampf(next_value, 0.0, 1.0)
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var drain := 0.0:
	set(next_drain):
		drain = clampf(next_drain, 0.0, 1.0)
		queue_redraw()
@export var meter_size := MeterSize.BASE:
	set(next_size):
		meter_size = next_size
		custom_minimum_size.y = _height()
		queue_redraw()
@export var fill_start := DS.METER_HEALTH_A:
	set(next_color):
		fill_start = next_color
		queue_redraw()
@export var fill_end := DS.METER_HEALTH_B:
	set(next_color):
		fill_end = next_color
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = _height()


func _height() -> float:
	match meter_size:
		MeterSize.SMALL: return DS.METER_H_SM
		MeterSize.LARGE: return DS.METER_H_LG
		_: return DS.METER_H


func _draw() -> void:
	var track := Rect2(Vector2.ZERO, Vector2(size.x, _height()))
	draw_rect(track, DS.METER_TRACK)
	draw_rect(track, DS.VOID_0, false, DS.BORDER_TRIM_W)
	var fill_width := track.size.x * value
	if fill_width > 0.0:
		var fill := Rect2(track.position, Vector2(fill_width, track.size.y))
		draw_rect(fill, fill_start)
		draw_line(
			Vector2(fill.end.x, fill.position.y), fill.end, fill_end, DS.BORDER_TRIM_W
		)
	var drain_width := track.size.x * drain
	if drain_width > fill_width:
		draw_rect(
			Rect2(Vector2(fill_width, 0.0), Vector2(drain_width - fill_width, track.size.y)),
			DS.ASH_FAINT
		)
