class_name CTTimelineRegion
extends PanelContainer

const FORECAST_DEPTH := 8
var _scheduler: TurnScheduler
var _snapshot_order: Array[Dictionary] = []
var _follows_beats := false
@onready var markers: HBoxContainer = %Markers


func bind_scheduler(scheduler: TurnScheduler) -> void:
	_scheduler = scheduler
	refresh()



## #473: read the strip from the battlefield's presented beats instead of the live event
## stream, so during a sequenced enemy phase it never shows an order the field has not
## presented yet. `beat_presented` carries each event once the field presents it.
func follow_presented_beats(beat_presented: Signal) -> void:
	_follows_beats = true
	if not beat_presented.is_connected(present_event):
		beat_presented.connect(present_event)


func consume_event(event: CombatEvent) -> void:
	if _follows_beats:
		return
	present_event(event)


func present_event(event: CombatEvent) -> void:
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
		var intent: Dictionary = entry.get("intent", {})
		if not intent.is_empty():
			marker.text += "\n" + intent_line(intent)


## #285 slice 5: a read enemy's locked intent, e.g. "→ Kero · head · 70% · 9 dmg · 25% injury".
## Every number is the controller's own forecast; this only formats it.
static func intent_line(intent: Dictionary) -> String:
	var parts: PackedStringArray = ["→ %s" % str(intent.get("target_name", "?"))]
	if str(intent.get("kind", "")) != "strike":
		parts.append("advancing")
		return " · ".join(parts + _scan_parts(intent))
	if not str(intent.get("aim_location", "")).is_empty():
		parts.append(str(intent["aim_location"]))
	if intent.has("hit_chance"):
		parts.append("%d%%" % int(intent["hit_chance"]))
		parts.append("%d dmg" % int(intent.get("damage_on_hit", 0)))
		if int(intent.get("injury_chance", 0)) > 0:
			parts.append("%d%% injury" % int(intent["injury_chance"]))
	return " · ".join(parts + _scan_parts(intent))


static func _scan_parts(intent: Dictionary) -> PackedStringArray:
	var parts: PackedStringArray = []
	var weaknesses: PackedStringArray = intent.get("weaknesses", PackedStringArray())
	if not weaknesses.is_empty():
		parts.append("weak: %s" % ", ".join(weaknesses))
	var resists: PackedStringArray = intent.get("resists", PackedStringArray())
	if not resists.is_empty():
		parts.append("resists %s" % ", ".join(resists))
	return parts


func marker_count() -> int:
	return markers.get_child_count()
