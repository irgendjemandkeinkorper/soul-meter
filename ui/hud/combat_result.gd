extends PanelContainer
## Transient committed outcome at HUD scale in either board or field coordinates.
## This timer never participates in combat input locks or animation completion.

const Feedback := preload("res://ui/hud/hit_pulse.gd")
const DISPLAY_SECONDS := 1.8
var target_id: StringName
var anchor: Callable
var bounds: Callable


func setup(event: CombatEvent, anchor_position: Callable, screen_bounds: Callable) -> void:
	target_id = event.target_id
	set_meta("result_target", target_id)
	anchor = anchor_position
	bounds = screen_bounds
	var target := Feedback.target_snapshot(event)
	var target_name := get_node("Column/TargetName") as Label
	target_name.text = str(target.get("display_name", ""))
	target_name.visible = not target_name.text.is_empty()
	(get_node("Column/Outcome") as Label).text = Feedback.result_text(event)
	var injury := get_node("Column/Injury") as Label
	injury.text = Feedback.injury_text(event)
	injury.visible = not injury.text.is_empty()
	reset_size()
	_process(0.0)
	var lifetime := create_tween()
	lifetime.tween_interval(DISPLAY_SECONDS)
	lifetime.tween_property(self, "modulate:a", 0.0, DS.DUR_BASE)
	lifetime.tween_callback(queue_free)


func _process(_delta: float) -> void:
	if not anchor.is_valid() or not bounds.is_valid():
		queue_free()
		return
	var point: Variant = anchor.call()
	if point == null:
		queue_free()
		return
	var parent := get_parent() as CanvasItem
	var transform := parent.get_global_transform_with_canvas()
	# Wrapped labels settle after the container receives its width. Follow their new
	# minimum instead of retaining the oversized pre-layout height for the whole beat.
	reset_size()
	# Field zoom must not magnify the UI or shrink its readable font size.
	scale = Vector2.ONE / transform.get_scale()
	var screen_point: Vector2 = transform * (point as Vector2)
	var area: Rect2 = bounds.call()
	var margin := Vector2.ONE * DS.SPACE_4
	var desired := screen_point + Vector2(DS.SPACE_8, -size.y - DS.SPACE_8)
	if desired.x + size.x > area.end.x - margin.x:
		desired.x = screen_point.x - size.x - DS.SPACE_8
	desired = desired.clamp(area.position + margin, (area.end - size - margin).max(area.position + margin))
	position = transform.affine_inverse() * desired
