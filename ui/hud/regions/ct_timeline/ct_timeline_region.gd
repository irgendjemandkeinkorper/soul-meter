class_name CTTimelineRegion
extends PanelContainer

const FORECAST_DEPTH := 8
var _scheduler: TurnScheduler
var _snapshot_order: Array[Dictionary] = []
@onready var markers: HBoxContainer = %Markers


func bind_scheduler(scheduler: TurnScheduler) -> void:
	_scheduler = scheduler
	refresh()



func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", event.data)
	var authored_order: Variant = snapshot.get("turn_order", [])
	if authored_order is Array:
		_snapshot_order.clear()
		for entry: Variant in authored_order:
			if entry is Dictionary:
				_snapshot_order.append((entry as Dictionary).duplicate(true))
	refresh()


func refresh() -> void:
	var order: Array[Dictionary] = []
	if _scheduler != null or not _snapshot_order.is_empty():
		order = _snapshot_order
		if order.is_empty() and _scheduler != null:
			order = _scheduler.peek_order(FORECAST_DEPTH)
	# Markers are reused in place: a crowded field refreshes this every event, and rebuilding
	# a hundred labels each time was most of the region's cost.
	var markers_now := markers.get_children()
	for index: int in range(order.size(), markers_now.size()):
		markers.remove_child(markers_now[index])
		markers_now[index].queue_free()
	for index: int in order.size():
		var entry: Dictionary = order[index]
		var actor := entry.get("actor") as BattleActor
		var marker: Label
		if index < markers_now.size():
			marker = markers_now[index] as Label
		else:
			marker = Label.new()
			marker.theme_type_variation = "StatLabel"
			markers.add_child(marker)
		var display_name := actor.display_name if actor != null else str(entry.get("display_name", "?"))
		if StringName(entry.get("scheduler_mode", &"")) == &"ap_round":
			var remaining := int(entry.get("ap_remaining", entry.get("charge", 0)))
			var maximum := maxi(remaining, int(entry.get("max_ap", remaining)))
			var pips := "●".repeat(remaining) + "○".repeat(maximum - remaining)
			var state := "ACTED" if bool(entry.get("acted", false)) else "PENDING"
			if bool(entry.get("active", false)):
				state = "ACTIVE"
			marker.text = "%s\n%s · %s" % [display_name, state, pips]
		else:
			var wait_cap := ""
			if (
				actor != null
				and _scheduler != null
				and not bool(_scheduler.can_act(actor).get("allowed", true))
				and _scheduler.charge_of(actor) >= TurnScheduler.READY_AT
			):
				wait_cap = " · WAIT CAP"
			marker.text = "%s\nCT %d → 100%s" % [display_name, int(entry.get("charge", 0)), wait_cap]


func marker_count() -> int:
	return markers.get_child_count()
