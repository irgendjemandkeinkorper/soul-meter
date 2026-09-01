extends Node
## Opt-in Gate T playtest evidence recorder. Disabled by default and deliberately
## inert until an exported build or test explicitly enables it.

const SCHEMA_VERSION := 1
# PROVISIONAL owner surface: keep the path centralized until Gate T evidence is accepted.
const DEFAULT_SESSION_ROOT := "user://playtest"
const EVENTS_FILE_NAME := "events.jsonl"
const EXPORT_FILE_NAME := "T_.md"
# PROVISIONAL owner surfaces: F8/F9 may move after facilitator playtesting.
const NOTE_HOTKEY := KEY_F8
const EXPORT_HOTKEY := KEY_F9

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

# Test seam: production leaves this blank and writes under DEFAULT_SESSION_ROOT.
var session_root_override: String = ""

var _enabled := false
var _session_directory := ""
var _events_path := ""
var _events_file: FileAccess = null
var _events: Array[Dictionary] = []
var _session_started_msec := 0
var _connections: Array[Dictionary] = []
var _last_soul_meter := 0.0
var _mock_ng_plus_observed := false
var _tile_state_by_cell: Dictionary = {}
var _current_scene: Node = null
var _current_scene_path := ""
var _current_scene_started_msec := 0
var _current_scene_exit_callable := Callable()
var _note_dialog: ConfirmationDialog = null
var _note_line_edit: LineEdit = null
var _paused_before_note := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	if _enabled:
		_finish_current_scene()
		export_now()
	_disconnect_all()
	_close_note_dialog()
	_close_events_file()
	_enabled = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _enabled:
		export_now()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var keycode: Key = key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = key_event.keycode
	match keycode:
		NOTE_HOTKEY:
			open_observation_note()
		EXPORT_HOTKEY:
			export_now()
		_:
			return
	get_viewport().set_input_as_handled()


func get_session_directory() -> String:
	return _session_directory


func get_events_path() -> String:
	return _events_path


func append_event(event_type: StringName, payload: Dictionary = {}) -> bool:
	if not _enabled or _events_file == null:
		return false
	var row: Dictionary = {
		"t": maxi(0, Time.get_ticks_msec() - _session_started_msec),
		"type": String(event_type),
	}
	for key: Variant in payload:
		var resolved_key := str(key)
		if resolved_key == "t" or resolved_key == "type":
			continue
		row[resolved_key] = _json_safe(payload[key])
	_events_file.store_line(JSON.stringify(row))
	_events_file.flush()
	_events.append(row.duplicate(true))
	return true


func export_now() -> String:
	if _session_directory.is_empty():
		return ""
	var export_path := _session_directory.path_join(EXPORT_FILE_NAME)
	var output := FileAccess.open(export_path, FileAccess.WRITE)
	if output == null:
		push_warning("Playtest recorder could not export %s." % export_path)
		return ""
	var duration_msec := maxi(0, Time.get_ticks_msec() - _session_started_msec)
	output.store_string(build_markdown(_events, _read_build_manifest(), duration_msec))
	output.flush()
	output.close()
	append_event(&"exported", {"file": EXPORT_FILE_NAME})
	return export_path


func open_observation_note() -> void:
	if not _enabled or _note_dialog != null:
		return
	_paused_before_note = get_tree().paused
	get_tree().paused = true

	_note_dialog = ConfirmationDialog.new()
	_note_dialog.name = "ObservationNoteDialog"
	_note_dialog.title = "Playtest observation"
	_note_dialog.ok_button_text = "Save"
	_note_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	_note_dialog.confirmed.connect(_save_observation_note)
	_note_dialog.canceled.connect(_close_note_dialog)

	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(560.0, 72.0)
	var prompt := Label.new()
	prompt.text = "Record a gameplay observation. Do not enter personal data."
	content.add_child(prompt)
	_note_line_edit = LineEdit.new()
	_note_line_edit.name = "NoteLineEdit"
	_note_line_edit.placeholder_text = "What did the tester do, expect, or misunderstand?"
	_note_line_edit.process_mode = Node.PROCESS_MODE_ALWAYS
	content.add_child(_note_line_edit)
	_note_dialog.add_child(content)
	add_child(_note_dialog)
	_note_dialog.popup_centered(Vector2i(620, 150))
	_note_line_edit.grab_focus.call_deferred()


func _save_observation_note() -> void:
	if _note_line_edit == null:
		_close_note_dialog()
		return
	var note_text := _note_line_edit.text.strip_edges()
	if note_text.is_empty():
		_close_note_dialog()
		return
	var screenshot_name := _capture_note_screenshot()
	append_event(&"note", {"text": note_text, "screenshot": screenshot_name})
	_close_note_dialog()


func _capture_note_screenshot() -> String:
	var elapsed := maxi(0, Time.get_ticks_msec() - _session_started_msec)
	var screenshot_name := "note_%08d.png" % elapsed
	var screenshot_path := _session_directory.path_join(screenshot_name)
	if DisplayServer.get_name() == "headless":
		push_warning("Playtest recorder could not capture a screenshot in headless mode.")
		return ""
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		push_warning("Playtest recorder could not capture a screenshot in this display mode.")
		return ""
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("Playtest recorder could not capture a screenshot in this display mode.")
		return ""
	var error := image.save_png(screenshot_path)
	if error != OK:
		push_warning("Playtest recorder could not save screenshot %s." % screenshot_path)
		return ""
	return screenshot_name


func _close_note_dialog() -> void:
	var had_dialog := _note_dialog != null
	if _note_dialog != null:
		var dialog: ConfirmationDialog = _note_dialog
		_note_dialog = null
		_note_line_edit = null
		if dialog.get_parent() == self:
			remove_child(dialog)
		dialog.queue_free()
	if had_dialog and is_inside_tree():
		get_tree().paused = _paused_before_note


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable := (
		force_enabled_for_tests
		or OS.get_environment("SOUL_METER_PLAYTEST") == "1"
		or OS.get_cmdline_user_args().has("--playtest-record")
	)
	if should_enable == _enabled:
		return
	if should_enable:
		_activate()
	else:
		_deactivate()


func _activate() -> void:
	_session_started_msec = Time.get_ticks_msec()
	_events.clear()
	_mock_ng_plus_observed = false
	_tile_state_by_cell.clear()
	if not _open_events_file():
		return
	_enabled = true
	set_process_unhandled_key_input(true)
	var availability := _connect_sources()
	var captured: Array[String] = availability["captured"]
	var uncaptured: Array[String] = availability["uncaptured"]
	append_event(
		&"session_started",
		{
			"schema": SCHEMA_VERSION,
			"started_at": Time.get_datetime_string_from_system(false, true),
			"captured_categories": captured,
			"uncaptured_categories": uncaptured,
			"privacy": "gameplay telemetry only; no personal data",
		}
	)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		_last_soul_meter = float(game_state.get("soul_meter"))
	_consider_scene(get_tree().current_scene)


func _deactivate() -> void:
	if not _enabled:
		return
	_finish_current_scene()
	export_now()
	_close_note_dialog()
	_disconnect_all()
	set_process_unhandled_key_input(false)
	_close_events_file()
	_enabled = false


func _open_events_file() -> bool:
	var root := session_root_override if not session_root_override.is_empty() else DEFAULT_SESSION_ROOT
	var now := Time.get_datetime_dict_from_system()
	var session_name := "%04d-%02d-%02d_%02d%02d%02d" % [
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0)),
		int(now.get("hour", 0)),
		int(now.get("minute", 0)),
		int(now.get("second", 0)),
	]
	_session_directory = root.path_join(session_name)
	var absolute_directory := ProjectSettings.globalize_path(_session_directory)
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		push_warning("Playtest recorder could not create %s." % _session_directory)
		_session_directory = ""
		return false
	_events_path = _session_directory.path_join(EVENTS_FILE_NAME)
	_events_file = FileAccess.open(_events_path, FileAccess.WRITE)
	if _events_file == null:
		push_warning("Playtest recorder could not open %s." % _events_path)
		_session_directory = ""
		_events_path = ""
		return false
	return true


func _close_events_file() -> void:
	if _events_file != null:
		_events_file.flush()
		_events_file.close()
		_events_file = null


func _connect_sources() -> Dictionary:
	var captured: Array[String] = []
	var uncaptured: Array[String] = []

	_category_availability(
		"scene_changes",
		_connect_signal(get_tree(), &"node_added", Callable(self, "_on_tree_node_added")),
		captured,
		uncaptured
	)

	var dialogue := get_node_or_null("/root/DialogueManager")
	var dialogue_ok := (
		_connect_signal(dialogue, &"dialogue_started", Callable(self, "_on_dialogue_started"))
		and _connect_signal(dialogue, &"dialogue_ended", Callable(self, "_on_dialogue_ended"))
	)
	_category_availability("dialogue", dialogue_ok, captured, uncaptured)

	var reputation := get_node_or_null("/root/Reputation")
	_category_availability(
		"reputation",
		_connect_signal(
			reputation, &"reputation_changed", Callable(self, "_on_reputation_changed")
		),
		captured,
		uncaptured
	)

	var renown := get_node_or_null("/root/Renown")
	_category_availability(
		"renown",
		_connect_signal(renown, &"renown_changed", Callable(self, "_on_renown_changed")),
		captured,
		uncaptured
	)

	var game_state := get_node_or_null("/root/GameState")
	_category_availability(
		"soul_meter_spends",
		_connect_signal(
			game_state, &"soul_meter_changed", Callable(self, "_on_soul_meter_changed")
		),
		captured,
		uncaptured
	)

	var quests := get_node_or_null("/root/QuestSystem")
	var quests_ok := (
		_connect_signal(quests, &"new_available_quest", Callable(self, "_on_quest_offered"))
		and _connect_signal(quests, &"quest_completed", Callable(self, "_on_quest_resolved"))
	)
	_category_availability("quests", quests_ok, captured, uncaptured)

	var battle := get_node_or_null("/root/Battle")
	var battle_ok := (
		_connect_signal(battle, &"battle_started", Callable(self, "_on_battle_started"))
		and _connect_signal(battle, &"battle_ended", Callable(self, "_on_battle_ended"))
	)
	_category_availability("battle_result", battle_ok, captured, uncaptured)
	_category_availability(
		"tactical_events",
		_connect_signal(battle, &"combat_event", Callable(self, "_on_combat_event")),
		captured,
		uncaptured
	)

	var save_game := get_node_or_null("/root/SaveGame")
	var saves_ok := (
		_connect_signal(save_game, &"saved", Callable(self, "_on_save_performed"))
		and _connect_signal(save_game, &"loaded", Callable(self, "_on_load_performed"))
	)
	_category_availability("save_load", saves_ok, captured, uncaptured)
	_category_availability(
		"mock_ng_plus",
		_connect_signal(
			save_game, &"ng_plus_applied", Callable(self, "_on_mock_ng_plus_applied")
		),
		captured,
		uncaptured
	)

	var world_clock := get_node_or_null("/root/WorldClock")
	_category_availability(
		"world_clock",
		_connect_signal(
			world_clock, &"phase_changed", Callable(self, "_on_world_clock_phase_changed")
		),
		captured,
		uncaptured
	)
	captured.sort()
	uncaptured.sort()
	return {"captured": captured, "uncaptured": uncaptured}


func _connect_signal(emitter: Object, signal_name: StringName, callback: Callable) -> bool:
	if emitter == null or not emitter.has_signal(signal_name):
		return false
	if not emitter.is_connected(signal_name, callback):
		emitter.connect(signal_name, callback)
	_connections.append(
		{"emitter": emitter, "signal_name": signal_name, "callback": callback}
	)
	return true


func _disconnect_all() -> void:
	for connection: Dictionary in _connections:
		var emitter: Object = connection.get("emitter") as Object
		var signal_name := StringName(connection.get("signal_name", &""))
		var callback: Callable = connection.get("callback", Callable())
		if (
			emitter != null
			and is_instance_valid(emitter)
			and emitter.is_connected(signal_name, callback)
		):
			emitter.disconnect(signal_name, callback)
	_connections.clear()
	_disconnect_current_scene()


func _category_availability(
	category: String, available: bool, captured: Array[String], uncaptured: Array[String]
) -> void:
	if available:
		captured.append(category)
	else:
		uncaptured.append(category)


func _on_tree_node_added(node: Node) -> void:
	if not _enabled or node.scene_file_path.is_empty():
		return
	call_deferred("_consider_scene", node)


func _consider_scene(node: Node) -> void:
	if not _enabled or node == null or not is_instance_valid(node):
		return
	if node != get_tree().current_scene:
		return
	if node == _current_scene:
		return
	_finish_current_scene()
	_current_scene = node
	_current_scene_path = node.scene_file_path
	_current_scene_started_msec = Time.get_ticks_msec()
	_current_scene_exit_callable = Callable(self, "_on_current_scene_exiting").bind(node)
	if not node.tree_exiting.is_connected(_current_scene_exit_callable):
		node.tree_exiting.connect(_current_scene_exit_callable)
	append_event(&"scene_started", {"scene": _current_scene_path})


func _on_current_scene_exiting(scene: Node) -> void:
	if scene != _current_scene:
		return
	append_event(
		&"scene_ended",
		{
			"scene": _current_scene_path,
			"duration_ms": maxi(0, Time.get_ticks_msec() - _current_scene_started_msec),
		}
	)
	_current_scene = null
	_current_scene_path = ""
	_current_scene_started_msec = 0
	_current_scene_exit_callable = Callable()


func _finish_current_scene() -> void:
	if _current_scene == null:
		return
	append_event(
		&"scene_ended",
		{
			"scene": _current_scene_path,
			"duration_ms": maxi(0, Time.get_ticks_msec() - _current_scene_started_msec),
		}
	)
	_disconnect_current_scene()


func _disconnect_current_scene() -> void:
	if (
		_current_scene != null
		and is_instance_valid(_current_scene)
		and _current_scene_exit_callable.is_valid()
		and _current_scene.tree_exiting.is_connected(_current_scene_exit_callable)
	):
		_current_scene.tree_exiting.disconnect(_current_scene_exit_callable)
	_current_scene = null
	_current_scene_path = ""
	_current_scene_started_msec = 0
	_current_scene_exit_callable = Callable()


func _on_dialogue_started(resource: DialogueResource) -> void:
	append_event(&"dialogue_started", _dialogue_payload(resource))


func _on_dialogue_ended(resource: DialogueResource) -> void:
	append_event(&"dialogue_ended", _dialogue_payload(resource))


func _dialogue_payload(resource: DialogueResource) -> Dictionary:
	if resource == null:
		return {"resource": "", "title": ""}
	return {"resource": resource.resource_path, "title": resource.resource_name}


func _on_reputation_changed(
	_faction: String, standing: float, event: ReputationEvent
) -> void:
	append_event(
		&"reputation_changed",
		{
			"actor": event.actor,
			"faction": event.faction,
			"delta": event.delta,
			"cause": event.cause,
			"standing": standing,
		}
	)


func _on_renown_changed(_kind: StringName, total: float, event: RenownEvent) -> void:
	append_event(
		&"renown_changed",
		{
			"actor": event.actor,
			"kind": String(event.kind),
			"delta": event.delta,
			"cause": event.cause,
			"total": total,
		}
	)


func _on_soul_meter_changed(value: float) -> void:
	if value < _last_soul_meter:
		append_event(
			&"soul_meter_spent",
			{
				"previous": _last_soul_meter,
				"value": value,
				"delta": value - _last_soul_meter,
				"cause": "",
			}
		)
	_last_soul_meter = value


func _on_quest_offered(quest: Resource) -> void:
	append_event(&"quest_offered", _quest_payload(quest))


func _on_quest_resolved(quest: Resource) -> void:
	append_event(&"quest_resolved", _quest_payload(quest))


func _quest_payload(quest: Resource) -> Dictionary:
	if quest == null:
		return {"quest_id": "", "title": ""}
	return {"quest_id": str(quest.get("id")), "title": str(quest.get("quest_name"))}


func _on_battle_started() -> void:
	var battle := get_node_or_null("/root/Battle")
	append_event(
		&"battle_started", {"encounter_id": str(battle.get("encounter_id")) if battle else ""}
	)


func _on_battle_ended(result: BattleResult) -> void:
	append_event(
		&"battle_ended",
		{
			"encounter_id": String(result.encounter_id),
			"result": BattleResult.State.keys()[result.state],
			"outcome_id": String(result.outcome_id),
			"cause": result.cause,
		}
	)


func _on_combat_event(event: CombatEvent) -> void:
	if event.type == &"battle_started":
		_tile_state_by_cell.clear()
	var event_data: Dictionary = _json_safe(event.data) as Dictionary
	var tile_changes := _capture_tile_changes(event.data)
	if not tile_changes.is_empty():
		event_data["tile_changes"] = tile_changes
	append_event(
		&"tactical_event",
		{
			"event_type": String(event.type),
			"actor": String(event.actor_id),
			"target": String(event.target_id),
			"data": event_data,
		}
	)


func _capture_tile_changes(event_data: Dictionary) -> Array[Dictionary]:
	var changes: Array[Dictionary] = []
	var snapshot: Variant = event_data.get("snapshot", {})
	if not snapshot is Dictionary:
		return changes
	var tiles: Variant = (snapshot as Dictionary).get("tiles", [])
	if not tiles is Array:
		return changes
	var next_state: Dictionary = {}
	for tile_value: Variant in tiles:
		if not tile_value is Dictionary:
			continue
		var tile: Dictionary = tile_value as Dictionary
		var cell_key := "%s:%d:%d" % [
			str(tile.get("battle_id", "")), int(tile.get("x", 0)), int(tile.get("y", 0))
		]
		var observed := {
			"charge_element_id": str(tile.get("charge_element_id", "")),
			"charge_level": int(tile.get("charge_level", 0)),
			"hush": bool(tile.get("hush", false)),
		}
		if _tile_state_by_cell.has(cell_key):
			var before: Dictionary = _tile_state_by_cell[cell_key]
			if before != observed:
				changes.append(
					{
						"battle_id": str(tile.get("battle_id", "")),
						"x": int(tile.get("x", 0)),
						"y": int(tile.get("y", 0)),
						"before": before.duplicate(true),
						"after": observed.duplicate(true),
					}
				)
		next_state[cell_key] = observed
	_tile_state_by_cell = next_state
	return changes


func _on_save_performed() -> void:
	append_event(&"save_performed")


func _on_load_performed() -> void:
	append_event(&"load_performed")


func _on_mock_ng_plus_applied(block: Dictionary) -> void:
	if _mock_ng_plus_observed:
		return
	if NGPlus.is_active(block):
		_mock_ng_plus_observed = true
		append_event(&"mock_ng_plus_observed")


func _on_world_clock_phase_changed(
	previous: StringName, current: StringName, cause: String
) -> void:
	append_event(
		&"world_clock_phase_changed",
		{"previous": String(previous), "current": String(current), "cause": cause}
	)


func _read_build_manifest() -> Dictionary:
	var result := {"artifact": "", "commit_sha": "", "export_target": ""}
	var executable_path := OS.get_executable_path()
	var manifest_path := executable_path.get_base_dir().path_join("BUILD-MANIFEST.txt")
	if not FileAccess.file_exists(manifest_path):
		return result
	var fields: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(manifest_path).split("\n"):
		var separator := line.find("=")
		if separator <= 0:
			continue
		fields[line.left(separator).strip_edges()] = line.substr(separator + 1).strip_edges()
	result["artifact"] = str(
		fields.get(
			"artifact",
			fields.get("artifact_name", fields.get("build_artifact", executable_path.get_file()))
		)
	)
	result["commit_sha"] = str(fields.get("commit_sha", ""))
	result["export_target"] = str(fields.get("export_target", fields.get("preset", "")))
	return result


static func derive_subsystem_coverage(events: Array[Dictionary]) -> Dictionary:
	var coverage := {
		"dialogue": false,
		"consequence_write": false,
		"battle_started": false,
		"ct_order": false,
		"weather_balance": false,
		"tile_event": false,
		"tactical_battle": false,
		"save_performed": false,
		"load_performed": false,
		"save_load": false,
		"mock_ng_plus": false,
	}
	for event: Dictionary in events:
		var event_type := str(event.get("type", ""))
		match event_type:
			"dialogue_started", "dialogue_ended":
				coverage["dialogue"] = true
			"reputation_changed", "renown_changed", "soul_meter_spent":
				coverage["consequence_write"] = true
			"battle_started":
				coverage["battle_started"] = true
			"save_performed":
				coverage["save_performed"] = true
			"load_performed":
				coverage["load_performed"] = true
			"mock_ng_plus_observed":
				coverage["mock_ng_plus"] = true
			"tactical_event":
				var tactical_type := str(event.get("event_type", "")).to_lower()
				if tactical_type.contains("turn_started") or tactical_type.contains("ct_"):
					coverage["ct_order"] = true
				if tactical_type.contains("weather") or tactical_type.contains("balance"):
					coverage["weather_balance"] = true
				if _has_tile_evidence(event):
					coverage["tile_event"] = true
	coverage["save_load"] = bool(coverage["save_performed"]) and bool(
		coverage["load_performed"]
	)
	coverage["tactical_battle"] = (
		bool(coverage["battle_started"])
		and bool(coverage["ct_order"])
		and bool(coverage["weather_balance"])
		and bool(coverage["tile_event"])
	)
	return coverage


static func _has_tile_evidence(event: Dictionary) -> bool:
	var tactical_type := str(event.get("event_type", "")).to_lower()
	for term: String in ["tile_", "residue", "deton", "hush"]:
		if tactical_type.contains(term):
			return true
	var data: Variant = event.get("data", {})
	if not data is Dictionary:
		return false
	var payload: Dictionary = data as Dictionary
	var tile_changes: Variant = payload.get("tile_changes", [])
	if tile_changes is Array and not (tile_changes as Array).is_empty():
		return true
	if tactical_type.contains("weather"):
		for key: String in ["charged_tiles", "drained_tiles", "clash_drained_tiles"]:
			if int(payload.get(key, 0)) > 0:
				return true
	var writes: Variant = payload.get("writes", [])
	if writes is Array:
		for write_value: Variant in writes:
			if not write_value is Dictionary:
				continue
			var kind := str((write_value as Dictionary).get("kind", "")).to_lower()
			if kind in ["residue", "detonation", "tile_charge", "tile_hush"]:
				return true
	var tile_payload: Variant = payload.get("tile", {})
	if tile_payload is Dictionary:
		for key: Variant in tile_payload:
			var normalized_key := str(key).to_lower()
			if (
				normalized_key.contains("residue")
				or normalized_key.contains("deton")
				or normalized_key.contains("charge")
				or normalized_key.contains("hush")
			):
				return true
	return false


static func build_markdown(
	events: Array[Dictionary], manifest: Dictionary, duration_msec: int
) -> String:
	var coverage := derive_subsystem_coverage(events)
	var lines: Array[String] = []
	lines.append("# Gate T criterion 6 — playtest session record")
	lines.append("")
	lines.append("## Build and session record")
	lines.append("")
	lines.append("| Field | Value |")
	lines.append("|---|---|")
	lines.append("| Build artifact / filename | %s |" % _markdown_cell(manifest.get("artifact", "")))
	lines.append("| Commit SHA | %s |" % _markdown_cell(manifest.get("commit_sha", "")))
	lines.append("| Export target | %s |" % _markdown_cell(manifest.get("export_target", "")))
	lines.append("| Godot version | 4.7.1 |")
	lines.append("| Build prepared by | |")
	lines.append("| Test dates | |")
	lines.append("| Evidence directory | `test/manual/gate-t/` |")
	lines.append("")
	lines.append("## Per-tester observation form")
	lines.append("")
	lines.append("### Tester ID: T__")
	lines.append("")
	lines.append("| Field | Value |")
	lines.append("|---|---|")
	lines.append("| Date | |")
	lines.append("| Build artifact / SHA verified | yes / no |")
	lines.append("| Outside tester, no prior exposure | yes / no |")
	lines.append("| Start time | |")
	lines.append("| End time | |")
	lines.append("| Duration (45–90 minutes required) | %s |" % _format_duration(duration_msec))
	lines.append("| Completed unaided | yes / no |")
	lines.append("| Session valid | yes / no |")
	lines.append("| Recording consent | none / notes only / audio-video opt-in |")
	lines.append("")
	lines.append("### Subsystem coverage")
	lines.append("")
	lines.append(_checklist_line(bool(coverage["dialogue"]), "Dialogue"))
	lines.append(_checklist_line(bool(coverage["consequence_write"]), "Consequence write"))
	lines.append(
		_checklist_line(
			bool(coverage["tactical_battle"]),
			"Tactical battle (CT + weather/Balance + tile event)"
		)
	)
	lines.append(_checklist_line(bool(coverage["save_load"]), "Save/load"))
	lines.append(_checklist_line(bool(coverage["mock_ng_plus"]), "Mock NG+ flag"))
	lines.append("")
	_append_gate_questions(lines)
	lines.append("### Save/load comparison")
	lines.append("")
	lines.append("| State | Before save | After load | Match? |")
	lines.append("|---|---|---|---|")
	lines.append("| Location and position | | | |")
	lines.append("| Party and HP | | | |")
	lines.append("| Quest/consequence flags | | | |")
	lines.append("| Soul and Balance-related state | | | |")
	lines.append("| Visible tactical state tested | | | |")
	lines.append("")
	lines.append("### Mock NG+ comparison")
	lines.append("")
	lines.append("| Carry-over | Before rollover | Fresh-save result | Correct? |")
	lines.append("|---|---|---|---|")
	lines.append("| Style points | | | |")
	lines.append("| Mirror Shop purchase(s) | | | |")
	lines.append("| Expected reset state | | | |")
	lines.append("")
	lines.append("### Observations")
	lines.append("")
	lines.append("| Time | Area | Tester action / verbatim comment | Expected | Actual | Severity |")
	lines.append("|---|---|---|---|---|---|")
	var note_count := 0
	for event: Dictionary in events:
		if str(event.get("type", "")) != "note":
			continue
		note_count += 1
		lines.append(
			"| %s | | %s | | | |"
			% [
				_format_event_time(int(event.get("t", 0))),
				_markdown_cell(event.get("text", "")),
			]
		)
	if note_count == 0:
		lines.append("| | | | | | |")
	lines.append("")
	lines.append("### Facilitator interventions")
	lines.append("")
	lines.append("| Time | Intervention | Control-only? | Session still valid? |")
	lines.append("|---|---|---|---|")
	lines.append("| | | yes / no | yes / no |")
	lines.append("")
	return "\n".join(lines)


static func _append_gate_questions(lines: Array[String]) -> void:
	var questions: Array[Dictionary] = [
		{
			"heading": "### Gate question 1 — cast refusal",
			"prompt": "**“Why did that cast fail?”**",
			"columns": "| Verbatim answer | Actual `blocked_by` reason and unblock condition | Correct? |",
		},
		{
			"heading": "### Gate question 2 — Balance",
			"prompt": "**“What does this gauge do?”**",
			"columns": "| Verbatim answer | Actual board/weather function observed | Correct? |",
		},
		{
			"heading": "### Gate question 3 — CT order",
			"prompt": "**“Who acts next, and why?”**",
			"columns": "| Verbatim answer | Actual next actor and CT/speed/cost reason | Correct? |",
		},
		{
			"heading": "### Gate question 4 — tile state",
			"prompt": "**“Explain what just happened on that tile.”**",
			"columns": "| Verbatim answer | Actual charge/residue/weather/hush/detonation cause | Correct? |",
		},
	]
	for question: Dictionary in questions:
		lines.append(str(question["heading"]))
		lines.append("")
		lines.append("Prompt: %s" % question["prompt"])
		lines.append("")
		lines.append(str(question["columns"]))
		lines.append("|---|---|---|")
		lines.append("| | | PASS / FAIL |")
		lines.append("")


static func _checklist_line(checked: bool, label: String) -> String:
	return "- [%s] %s" % ["x" if checked else " ", label]


static func _format_duration(duration_msec: int) -> String:
	var total_seconds := maxi(0, floori(float(duration_msec) / 1000.0))
	var hours := floori(float(total_seconds) / 3600.0)
	var minutes := floori(float(total_seconds % 3600) / 60.0)
	var seconds := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


static func _format_event_time(event_msec: int) -> String:
	var total_seconds := maxi(0, floori(float(event_msec) / 1000.0))
	return "%02d:%02d:%02d" % [
		floori(float(total_seconds) / 3600.0),
		floori(float(total_seconds % 3600) / 60.0),
		total_seconds % 60,
	]


static func _markdown_cell(value: Variant) -> String:
	return str(value).replace("|", "\\|").replace("\r", " ").replace("\n", " ")


static func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [value.x, value.y]
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [value.x, value.y, value.z]
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var output: Array[Variant] = []
			for item: Variant in value:
				output.append(_json_safe(item))
			return output
		TYPE_DICTIONARY:
			var output: Dictionary = {}
			for key: Variant in value:
				output[str(key)] = _json_safe(value[key])
			return output
		TYPE_OBJECT:
			if value is Resource:
				return (value as Resource).resource_path
			return null
		_:
			return str(value)
