class_name AmbientPropMotion
extends Sprite2D
## Deterministic, allocation-free ambient motion for town dressing sprites.

enum MotionKind {
	LANTERN_SWAY,
	BRAZIER_FLICKER,
	WOUND_BREATH,
}

@export var motion_kind: MotionKind = MotionKind.LANTERN_SWAY
@export_range(0.0, 6.283, 0.01) var phase: float = 0.0
@export_range(0.5, 16.0, 0.1) var period: float = 3.6
@export_range(0.0, 2.0, 0.05) var sway_degrees: float = 0.7
@export_range(0.0, 0.2, 0.005) var flicker_strength: float = 0.045
@export_range(0.0, 0.1, 0.005) var breath_strength: float = 0.025

var _elapsed: float = 0.0
var _base_rotation: float
var _base_modulate: Color


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_base_rotation = rotation
	_base_modulate = modulate


func _process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, period)
	var wave := sin((_elapsed / period) * TAU + phase)
	if motion_kind == MotionKind.LANTERN_SWAY:
		rotation = _base_rotation + deg_to_rad(sway_degrees) * wave
		return
	var pulse_strength := flicker_strength
	if motion_kind == MotionKind.WOUND_BREATH:
		pulse_strength = breath_strength
	var brightness := 1.0 + pulse_strength * wave
	modulate = Color(
		_base_modulate.r * brightness,
		_base_modulate.g * brightness,
		_base_modulate.b * brightness,
		_base_modulate.a
	)
