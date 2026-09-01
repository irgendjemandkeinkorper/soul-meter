class_name ConsequenceTimelineController
extends Node
## Debug-only, read-only consequence observer. Disabled builds remain completely inert.

signal timeline_changed

const OVERLAY_SCENE: PackedScene = preload("res://ui/debug/consequence_timeline.tscn")
const TOGGLE_HOTKEY: Key = KEY_F4
const MAX_RETAINED_ROWS: int = 200
const ENVIRONMENT_VARIABLE: String = "SOUL_METER_CONSEQUENCE_TIMELINE"
const REPUTATION_LEDGER: StringName = &"REPUTATION"
const RENOWN_LEDGER: StringName = &"RENOWN"

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _ledger_signals_connected: bool = false
var _overlay_layer: CanvasLayer = null
var _rows: Array[Dictionary] = []
var _next_arrival: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	_shutdown()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != TOGGLE_HOTKEY and key_event.keycode != TOGGLE_HOTKEY:
		return
	if _overlay_layer == null:
		open_overlay()
	else:
		close_overlay()
	get_viewport().set_input_as_handled()


func open_overlay() -> void:
	if not _enabled or _overlay_layer != null:
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "ConsequenceTimelineLayer"
	_overlay_layer.layer = 1050
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	var overlay: ConsequenceTimelinePanel = OVERLAY_SCENE.instantiate() as ConsequenceTimelinePanel
	overlay.name = "ConsequenceTimelineOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.add_child(overlay)
	overlay.configure(self)


func close_overlay() -> void:
	if not _enabled:
		return
	_close_overlay()


func rows() -> Array[Dictionary]:
	if not _enabled:
		return []
	return _rows.duplicate(true)


func summary() -> Dictionary:
	if not _enabled:
		return {}
	return {
		"standings": Reputation.all_standings(),
		"reputation": Renown.reputation(),
		"infamy": Renown.infamy(),
	}


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable: bool = OS.is_debug_build() and (
		OS.get_environment(ENVIRONMENT_VARIABLE) == "1" or force_enabled_for_tests
	)
	if should_enable == _enabled:
		return
	_enabled = should_enable
	set_process_unhandled_key_input(_enabled)
	if _enabled:
		_load_backfill()
		_connect_ledger_signals()
	else:
		_shutdown()


func _connect_ledger_signals() -> void:
	if not _enabled or _ledger_signals_connected:
		return
	Reputation.reputation_changed.connect(_on_reputation_changed)
	Renown.renown_changed.connect(_on_renown_changed)
	# Loading a save (or starting a new game) REPLACES both ledgers wholesale via
	# from_dict(), which emits no change signal — so a purely signal-fed timeline
	# would keep showing the previous game's consequences and never acquire the
	# loaded ones. load_requested fires after both replacements and covers both
	# cases, so it is the resync seam. Same class of bug as a derived statechart
	# guard left stale by a non-signalling restore.
	SaveGame.load_requested.connect(_on_load_requested)
	_ledger_signals_connected = true


func _disconnect_ledger_signals() -> void:
	if not _ledger_signals_connected:
		return
	if Reputation.reputation_changed.is_connected(_on_reputation_changed):
		Reputation.reputation_changed.disconnect(_on_reputation_changed)
	if Renown.renown_changed.is_connected(_on_renown_changed):
		Renown.renown_changed.disconnect(_on_renown_changed)
	if SaveGame.load_requested.is_connected(_on_load_requested):
		SaveGame.load_requested.disconnect(_on_load_requested)
	_ledger_signals_connected = false


## The ledgers were replaced underneath us; rebuild the feed from what they now
## hold rather than showing a previous game's history.
func _on_load_requested(_destination: LoadDestination) -> void:
	if not _enabled:
		return
	# _load_backfill() already emits timeline_changed; emitting again here made an
	# open overlay rebuild twice per load.
	_load_backfill()


func _shutdown() -> void:
	_disconnect_ledger_signals()
	_close_overlay()
	_rows.clear()
	_next_arrival = 0


func _close_overlay() -> void:
	if _overlay_layer == null:
		return
	var layer: CanvasLayer = _overlay_layer
	_overlay_layer = null
	remove_child(layer)
	layer.free()


func _on_reputation_changed(
	faction: String, standing: float, event: ReputationEvent
) -> void:
	if not _enabled:
		return
	_append_live_row(_reputation_row(event, standing, false))


func _on_renown_changed(kind: StringName, total: float, event: RenownEvent) -> void:
	if not _enabled:
		return
	_append_live_row(_renown_row(event, total, false))


func _append_live_row(row: Dictionary) -> void:
	if not _enabled:
		return
	row["arrival"] = _next_arrival
	_next_arrival += 1
	_rows.push_front(row)
	if _rows.size() > MAX_RETAINED_ROWS:
		_rows.resize(MAX_RETAINED_ROWS)
	timeline_changed.emit()


func _load_backfill() -> void:
	if not _enabled:
		return
	_rows.clear()
	_next_arrival = 0
	var reputation_rows: Array[Dictionary] = _reputation_backfill()
	var renown_rows: Array[Dictionary] = _renown_backfill()
	_rows = _merge_restored_rows(reputation_rows, renown_rows)
	timeline_changed.emit()


func _reputation_backfill() -> Array[Dictionary]:
	var history: Array[ReputationEvent] = Reputation.history(MAX_RETAINED_ROWS)
	var remaining: Dictionary = Reputation.all_standings()
	var restored_rows: Array[Dictionary] = []
	for event: ReputationEvent in history:
		var resulting: float = float(remaining.get(event.faction, 0.0))
		restored_rows.append(_reputation_row(event, resulting, true))
		remaining[event.faction] = resulting - event.delta
	return restored_rows


func _renown_backfill() -> Array[Dictionary]:
	var history: Array[RenownEvent] = Renown.history(MAX_RETAINED_ROWS)
	var remaining: Dictionary = {
		&"reputation": Renown.reputation(),
		&"infamy": Renown.infamy(),
	}
	var restored_rows: Array[Dictionary] = []
	for event: RenownEvent in history:
		var resulting: float = float(remaining.get(event.kind, 0.0))
		restored_rows.append(_renown_row(event, resulting, true))
		remaining[event.kind] = resulting - event.delta
	return restored_rows


func _merge_restored_rows(
	reputation_rows: Array[Dictionary], renown_rows: Array[Dictionary]
) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	var reputation_index: int = 0
	var renown_index: int = 0
	while merged.size() < MAX_RETAINED_ROWS and (
		reputation_index < reputation_rows.size() or renown_index < renown_rows.size()
	):
		if reputation_index >= reputation_rows.size():
			merged.append(renown_rows[renown_index])
			renown_index += 1
			continue
		if renown_index >= renown_rows.size():
			merged.append(reputation_rows[reputation_index])
			reputation_index += 1
			continue
		var reputation_at: int = int(reputation_rows[reputation_index]["at"])
		var renown_at: int = int(renown_rows[renown_index]["at"])
		if reputation_at >= renown_at:
			merged.append(reputation_rows[reputation_index])
			reputation_index += 1
		else:
			merged.append(renown_rows[renown_index])
			renown_index += 1
	return merged


func _reputation_row(
	event: ReputationEvent, resulting: float, restored: bool
) -> Dictionary:
	return {
		"ledger": REPUTATION_LEDGER,
		"subject": event.faction,
		"delta": event.delta,
		"resulting": resulting,
		"cause": event.cause,
		"actor": event.actor,
		"scene": event.scene,
		"at": event.at,
		"source_order": event.order,
		"arrival": -1,
		"restored": restored,
		"debug_injected": event.cause.begins_with(DevConsole.DEBUG_CAUSE_PREFIX),
	}


func _renown_row(event: RenownEvent, resulting: float, restored: bool) -> Dictionary:
	return {
		"ledger": RENOWN_LEDGER,
		"subject": event.kind,
		"delta": event.delta,
		"resulting": resulting,
		"cause": event.cause,
		"actor": event.actor,
		"scene": event.scene,
		"at": event.at,
		"source_order": event.order,
		"arrival": -1,
		"restored": restored,
		"debug_injected": event.cause.begins_with(DevConsole.DEBUG_CAUSE_PREFIX),
	}
