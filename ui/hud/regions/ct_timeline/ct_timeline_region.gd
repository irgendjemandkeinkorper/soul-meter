class_name CTTimelineRegion
extends PanelContainer
## The turn-order strip: one thin row of small portraits and names in CT order, the active
## actor highlighted (owner 2026-11-01). Every number is the scheduler's or the snapshot's;
## this only formats it.

const UnitPlateScript := preload("res://ui/hud/regions/unit_plate/unit_plate_region.gd")
const FORECAST_DEPTH := 8
const PORTRAIT_SIZE := Vector2(28, 28)
var _scheduler: TurnScheduler
var _snapshot_order: Array[Dictionary] = []
## Roster rows by combat id from the last presented snapshot (portrait and side lookups).
var _rows: Dictionary = {}
var _active_id: StringName = &""
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
	if snapshot.has("allies") or snapshot.has("enemies"):
		_rows.clear()
		for side: String in ["allies", "enemies"]:
			for row: Variant in snapshot.get(side, []):
				if row is Dictionary:
					_rows[StringName(str((row as Dictionary).get("id", "")))] = row
	if snapshot.has("active_actor_id"):
		_active_id = StringName(str(snapshot.get("active_actor_id", "")))
	refresh()


func refresh() -> void:
	var order: Array[Dictionary] = []
	if _scheduler != null or not _snapshot_order.is_empty():
		order = _snapshot_order
		if order.is_empty() and _scheduler != null:
			order = _scheduler.peek_order(FORECAST_DEPTH)
	# Markers are reused in place: a crowded field refreshes this every event, and rebuilding
	# a hundred markers each time was most of the region's cost.
	var markers_now := markers.get_children()
	for index: int in range(order.size(), markers_now.size()):
		markers.remove_child(markers_now[index])
		markers_now[index].queue_free()
	for index: int in order.size():
		var entry: Dictionary = order[index]
		var actor := entry.get("actor") as BattleActor
		var marker: PanelContainer
		if index < markers_now.size():
			marker = markers_now[index] as PanelContainer
		else:
			marker = _make_marker()
			markers.add_child(marker)
		var display_name := actor.display_name if actor != null else str(entry.get("display_name", "?"))
		var status := ""
		if StringName(entry.get("scheduler_mode", &"")) == &"ap_round":
			var remaining := int(entry.get("ap_remaining", entry.get("charge", 0)))
			var maximum := maxi(remaining, int(entry.get("max_ap", remaining)))
			var pips := "●".repeat(remaining) + "○".repeat(maximum - remaining)
			var state := "ACTED" if bool(entry.get("acted", false)) else "PENDING"
			if bool(entry.get("active", false)):
				state = "ACTIVE"
			status = "%s · %s" % [state, pips]
		else:
			var wait_cap := ""
			if (
				actor != null
				and _scheduler != null
				and not bool(_scheduler.can_act(actor).get("allowed", true))
				and _scheduler.charge_of(actor) >= TurnScheduler.READY_AT
			):
				wait_cap = " · WAIT CAP"
			status = "CT %d → 100%s" % [int(entry.get("charge", 0)), wait_cap]
		var intent: Dictionary = entry.get("intent", {})
		if not intent.is_empty():
			status += "\n" + intent_line(intent)
		var active := _entry_is_active(entry, actor)
		marker.theme_type_variation = "HudTurnMarkerActive" if active else "HudTurnMarker"
		var name_label := marker_name_label(index)
		name_label.text = display_name
		name_label.theme_type_variation = "HudTurnNameActive" if active else "HudTurnName"
		marker_status_label(index).text = status
		var portrait := marker_portrait(index)
		portrait.texture = _portrait_for_entry(entry, actor)
		portrait.visible = portrait.texture != null
		marker.tooltip_text = "%s\n%s" % [display_name, status]


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


## The marker's two labels read as one text block (name, then status), as the old single
## label did: "Vex\nACTIVE · ●●○○".
func marker_text(index: int) -> String:
	return "%s\n%s" % [marker_name_label(index).text, marker_status_label(index).text]


func marker_name_label(index: int) -> Label:
	return markers.get_child(index).get_node("Row/Column/Name") as Label


func marker_status_label(index: int) -> Label:
	return markers.get_child(index).get_node("Row/Column/Status") as Label


func marker_portrait(index: int) -> TextureRect:
	return markers.get_child(index).get_node("Row/Portrait") as TextureRect


func marker_is_active(index: int) -> bool:
	return String(markers.get_child(index).theme_type_variation) == "HudTurnMarkerActive"


func _make_marker() -> PanelContainer:
	var marker := PanelContainer.new()
	marker.theme_type_variation = "HudTurnMarker"
	marker.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.name = "Row"
	row.theme_type_variation = "HudBarRow"
	marker.add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.theme_type_variation = "HudBarColumn"
	row.add_child(column)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.theme_type_variation = "HudTurnName"
	column.add_child(name_label)
	var status := Label.new()
	status.name = "Status"
	status.theme_type_variation = "HudTurnStat"
	column.add_child(status)
	return marker


func _entry_is_active(entry: Dictionary, actor: BattleActor) -> bool:
	if entry.has("active"):
		return bool(entry.get("active", false))
	var id := _entry_id(entry, actor)
	return not id.is_empty() and id == _active_id


func _entry_id(entry: Dictionary, actor: BattleActor) -> StringName:
	if actor != null:
		return actor.combat_id
	return StringName(str(entry.get("actor_id", entry.get("id", ""))))


func _portrait_for_entry(entry: Dictionary, actor: BattleActor) -> Texture2D:
	var row: Dictionary = _rows.get(_entry_id(entry, actor), {})
	if row.is_empty() and actor != null:
		row = {
			"display_name": actor.display_name,
			"archetype_id": actor.archetype_id,
			"side": actor.side,
			"portrait_path": (
				actor.source_member.portrait.resource_path
				if actor.source_member != null and actor.source_member.portrait != null else ""
			),
		}
	if row.is_empty():
		return null
	return UnitPlateScript.portrait_for(row)
