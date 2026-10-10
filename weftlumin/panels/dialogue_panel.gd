class_name WeftluminDialoguePanel
extends SoulMeterToolPanel
## Dialogue lab tab (§4.8): the dialogue lab's replay lifecycle behind the panel contract.
## Disk-derived choices, CACHE_MODE_IGNORE hot reload, seeded state applied inside the snapshot,
## and refusal over production battle/dialogue or another lab's session are the model's.
##
## `needs_sandbox`: the shell arms the shared sandbox under this panel's token on activation, and
## the model's replay sessions restart under that same token. Leaving the tab ends the session.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/dialogue_lab.gd")

var file_picker: OptionButton = null
var title_picker: OptionButton = null
var flags_editor: TextEdit = null
var reputation_editor: TextEdit = null
var renown_reputation: LineEdit = null
var renown_infamy: LineEdit = null
var session_label: Label = null


func _init() -> void:
	title = "Dialogue lab"
	needs_sandbox = true
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _attach_model() -> bool:
	return bool(model.call("host_in_panel", _host.sandbox_token(self)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and model != null and not is_visible_in_tree():
		model.call("end_session")


func _build(content: VBoxContainer) -> void:
	var pickers := _row()
	content.add_child(pickers)
	file_picker = _option("DialogueFile")
	file_picker.item_selected.connect(func(_index: int) -> void: _populate_titles())
	pickers.add_child(file_picker)
	title_picker = _option("Title")
	pickers.add_child(title_picker)
	pickers.add_child(_button("Start replay", "Start", start))
	pickers.add_child(_button("Replay same state", "ReplaySame", func() -> void:
		model.call("replay_same_state")
	))
	pickers.add_child(_button("Reload and replay", "Reload", func() -> void:
		model.call("reload_and_replay")
	))
	pickers.add_child(_button("End session", "End", func() -> void: model.call("end_session")))
	session_label = _label("")
	session_label.name = "Session"
	pickers.add_child(session_label)
	var seeds := _row()
	content.add_child(seeds)
	flags_editor = _text_box("Flags", true)
	flags_editor.placeholder_text = "dom_bellhouse_inspected=true\ndom_registry_notice_seen=false"
	seeds.add_child(flags_editor)
	reputation_editor = _text_box("Reputation", true)
	reputation_editor.placeholder_text = "the-registry=21\nmirror-choir=-11"
	seeds.add_child(reputation_editor)
	var renown := _row()
	content.add_child(renown)
	renown_reputation = _line("RenownReputation", "Renown reputation target (optional)")
	renown.add_child(renown_reputation)
	renown_infamy = _line("RenownInfamy", "Renown infamy target (optional)")
	renown.add_child(renown_infamy)
	model.connect("replay_changed", _on_replay_changed)


func refresh(_payload: Dictionary) -> void:
	var previous: Variant = _selected_metadata(file_picker)
	file_picker.clear()
	for path: String in model.call("dialogue_files"):
		file_picker.add_item(path.get_file())
		file_picker.set_item_metadata(file_picker.item_count - 1, path)
		if path == previous:
			file_picker.select(file_picker.item_count - 1)
	if file_picker.item_count == 0:
		_set_status("No .dialogue files found.")
		return
	_populate_titles()
	_show_session(model.call("current_setup"))


func commands() -> Array[Callable]:
	return [
		Callable(model, "start_replay"),
		Callable(model, "replay_same_state"),
		Callable(model, "reload_and_replay"),
		Callable(model, "end_session"),
	]


## Parse the seed editors into the replay setup.
## Returns `{valid, setup}` or `{valid: false, error}`.
func current_setup() -> Dictionary:
	if file_picker.item_count == 0 or title_picker.item_count == 0:
		return {"valid": false, "error": "Choose a dialogue file and title."}
	var flags := parse_flags(flags_editor.text)
	if not bool(flags.get("valid", false)):
		return flags
	var reputation := parse_numbers(reputation_editor.text, "reputation")
	if not bool(reputation.get("valid", false)):
		return reputation
	var setup := {
		"dialogue_path": str(_selected_metadata(file_picker)),
		"title": str(_selected_metadata(title_picker)),
		"flags": flags.get("values", {}),
		"reputation": reputation.get("values", {}),
	}
	for pair: Array in [["renown_reputation", renown_reputation], ["renown_infamy", renown_infamy]]:
		var text := (pair[1] as LineEdit).text.strip_edges()
		if text.is_empty():
			continue
		if not text.is_valid_float():
			return {"valid": false, "error": "%s must be a number or blank." % (
				String(pair[0]).replace("_", " ").capitalize()
			)}
		setup[pair[0]] = text.to_float()
	return {"valid": true, "setup": setup}


func start() -> void:
	var parsed := current_setup()
	if not bool(parsed.get("valid", false)):
		_set_status(str(parsed.get("error", "Invalid setup.")))
		return
	_set_status("")
	if (
		bool(model.call("production_battle_is_live"))
		or bool(model.call("production_dialogue_is_live"))
		or bool(model.call("another_sandbox_is_armed"))
	):
		_set_status(MODEL_SCRIPT.REFUSAL_WARNING)
	model.call("start_replay", parsed["setup"])
	_show_session(model.call("current_setup"), bool(model.call("sandbox_is_armed")))


static func parse_flags(text: String) -> Dictionary:
	var values: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var pair := line.split("=", false, 1)
		if pair.size() != 2 or str(pair[0]).strip_edges().is_empty():
			return {"valid": false, "error": "Flags use flag_key=true or flag_key=false."}
		var value := str(pair[1]).strip_edges().to_lower()
		if value != "true" and value != "false":
			return {"valid": false, "error": "Flag '%s' must be true or false." % pair[0]}
		values[str(pair[0]).strip_edges()] = value == "true"
	return {"valid": true, "values": values}


static func parse_numbers(text: String, label: String) -> Dictionary:
	var values: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue
		var pair := line.split("=", false, 1)
		if pair.size() != 2 or str(pair[0]).strip_edges().is_empty():
			return {"valid": false, "error": "%s uses key=value." % label.capitalize()}
		var value := str(pair[1]).strip_edges()
		if not value.is_valid_float():
			return {"valid": false, "error": "%s value for '%s' must be numeric." % [
				label.capitalize(), str(pair[0]).strip_edges(),
			]}
		values[str(pair[0]).strip_edges()] = value.to_float()
	return {"valid": true, "values": values}


func _populate_titles() -> void:
	title_picker.clear()
	var path := str(_selected_metadata(file_picker))
	for cue: String in model.call("titles_for_file", path):
		title_picker.add_item(cue)
		title_picker.set_item_metadata(title_picker.item_count - 1, cue)
	_set_status("" if title_picker.item_count > 0 else "This resource has no titles.")


func _on_replay_changed(running: bool, setup: Dictionary) -> void:
	_show_session(setup, running)


func _show_session(setup: Dictionary, running: bool = false) -> void:
	if setup.is_empty():
		session_label.text = "No replay session."
		return
	session_label.text = "%s — %s @ %s" % [
		"REPLAYING" if running else "SESSION READY",
		str(setup.get("dialogue_path", "")).get_file(), str(setup.get("title", "")),
	]


static func _line(node_name: String, placeholder: String) -> LineEdit:
	var line := LineEdit.new()
	line.name = node_name
	line.placeholder_text = placeholder
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line
