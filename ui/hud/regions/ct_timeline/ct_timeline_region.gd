class_name CTTimelineRegion
extends PanelContainer

const FORECAST_DEPTH := 8
var _scheduler: TurnScheduler
@onready var markers: HBoxContainer = %Markers


func bind_scheduler(scheduler: TurnScheduler) -> void:
	_scheduler = scheduler
	refresh()


func consume_event(_event: CombatEvent) -> void:
	refresh()


func refresh() -> void:
	for child: Node in markers.get_children():
		child.queue_free()
	if _scheduler == null:
		return
	for entry: Dictionary in _scheduler.peek_order(FORECAST_DEPTH):
		var actor := entry.get("actor") as BattleActor
		var marker := Label.new()
		marker.theme_type_variation = "StatLabel"
		var wait_cap := " · WAIT CAP" if actor != null and not bool(_scheduler.can_act(actor).get("allowed", true)) and _scheduler.charge_of(actor) >= TurnScheduler.READY_AT else ""
		marker.text = "%s\nCT %d → 100%s" % [actor.display_name if actor != null else "?", int(entry.get("charge", 0)), wait_cap]
		markers.add_child(marker)


func marker_count() -> int:
	return markers.get_child_count()
