extends Node2D
## A class command's flourish at the actor (owner 2026-11-02: "class flourishes"): the class's
## look from CombatLook, in its suggested Major's colours, for one short beat. Reads nothing
## but the class id; never advances combat. Reduced motion never creates one.

const CombatLookScript := preload("res://ui/hud/combat_look.gd")
const LIFETIME := DS.DUR_SLOW * 2.0

var _anchor: Callable
var _look: Array = []
var _color := Color.WHITE
var _glow := Color.WHITE
var _visual_scale := 1.0
var _elapsed := 0.0


## False when the class has no flourish; the caller frees the node then.
func setup(class_id: String, anchor: Callable, visual_scale: float = 1.0) -> bool:
	_look = CombatLookScript.class_look(class_id)
	if _look.is_empty():
		return false
	var colors := CombatLookScript.class_colors(class_id)
	_color = colors[0]
	_glow = colors[1]
	_anchor = anchor
	_visual_scale = maxf(0.1, visual_scale)
	return true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var point: Variant = _anchor.call() if _anchor.is_valid() else null
	if not point is Vector2:
		return
	CombatLookScript.draw(
		self, _look, point, float(DS.SPACE_6) * _visual_scale, clampf(_elapsed / LIFETIME, 0.0, 0.999),
		_color, _glow, _visual_scale
	)
