class_name WeftluminQuestPanel
extends SoulMeterToolPanel
## Quest editor tab (§4.8): the quest editor model behind the panel contract — validate in
## memory, transactional write, reload through the same loader, register, and refuse to reset
## live progress without explicit authorisation. All of that is the model's.
##
## Two views over one draft. The guided form (#474) edits campaign fields, one quest at a time
## and its outcome rows, and shows each loader error beside the field it names. The JSON view
## edits the exact documents CampaignQuestLoader consumes (`campaign.json` and the quest files),
## so it can express every field the package format carries; the form keeps any field it does
## not show. Switching views carries the draft across.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/quest_editor.gd")
const VIEW_FORM := &"form"
const VIEW_JSON := &"json"
const QUEST_LINE_FIELDS: Array[Array] = [
	["quest_id", "Quest ID", "quest-id"], ["name", "Name", "Quest name"],
]
const QUEST_TEXT_FIELDS: Array[Array] = [
	["decision_prompt", "Decision prompt", "What does the player decide?"],
	["resolution_flag", "Resolution flag", "quest_resolution_flag"],
]
const OUTCOME_LINE_FIELDS: Array[Array] = [
	["id", "ID"], ["label", "Label"], ["cause", "Cause"], ["readback", "Readback"],
]
const OUTCOME_MINIMUM := 2

var campaign_picker: OptionButton = null
var campaign_editor: TextEdit = null
var quests_editor: TextEdit = null
var errors_label: Label = null
var registered_label: Label = null
var authorize_button: Button = null
var last_result: Dictionary = {}
## Guided form (#474).
var view: StringName = VIEW_FORM
var form_view: VBoxContainer = null
var json_view: HBoxContainer = null
var quest_picker: OptionButton = null
var quest_fields: VBoxContainer = null
var no_quest_label: Label = null
var outcome_requirement: Label = null
var outcomes_container: VBoxContainer = null
## One row per outcome: `{panel, heading, remove, controls, errors, source}`.
var outcome_rows: Array[Dictionary] = []
var _form_button: Button = null
var _json_button: Button = null
var _field_controls: Dictionary = {}
var _field_errors: Dictionary = {}
var _campaign_data: Dictionary = {}
var _quests: Array[Dictionary] = []
var _selected_quest: int = -1
var _loading: bool = false
var _pending_action: StringName = &""
var _pending_identities: Array[String] = []


func _init() -> void:
	title = "Quest editor"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


## The dock is short and the form scrolls, so the status line sits under the action bar.
func configure(host: WeftluminShell) -> void:
	super.configure(host)
	if _status != null and authorize_button != null:
		var bar := authorize_button.get_parent()
		_status.get_parent().move_child(_status, bar.get_index() + 1)


func _build(content: VBoxContainer) -> void:
	content.add_child(_label(
		"Authors user://campaigns packages. It never offers or resolves quests.",
		&"EditorLabel", true
	))
	var bar := _row()
	content.add_child(bar)
	campaign_picker = _option("Campaign")
	bar.add_child(campaign_picker)
	bar.add_child(_button("Load", "Load", func() -> void:
		load_campaign(str(_selected_metadata(campaign_picker)))
	))
	bar.add_child(_button("New draft", "NewDraft", new_draft))
	bar.add_child(_button("Validate", "Validate", func() -> void: validate()))
	bar.add_child(_button("Save", "Save", func() -> void: save()))
	bar.add_child(_button("Reload", "Reload", func() -> void: reload()))
	authorize_button = _button("Authorize reset of listed live quests", "Authorize", func() -> void:
		authorize()
	)
	authorize_button.visible = false
	bar.add_child(authorize_button)
	var views := ButtonGroup.new()
	_form_button = _button("Form", "FormView", func() -> void: show_form())
	_json_button = _button("JSON", "JsonView", func() -> void: show_json())
	for toggle: Button in [_form_button, _json_button]:
		toggle.toggle_mode = true
		toggle.button_group = views
		bar.add_child(toggle)

	form_view = VBoxContainer.new()
	form_view.name = "Form"
	form_view.theme_type_variation = &"EditorColumn"
	content.add_child(form_view)
	_build_form(form_view)

	json_view = _row()
	json_view.name = "Json"
	content.add_child(json_view)
	campaign_editor = _text_box("CampaignJson", true)
	campaign_editor.placeholder_text = "campaign.json"
	json_view.add_child(campaign_editor)
	quests_editor = _text_box("QuestsJson", true)
	quests_editor.placeholder_text = "[ quest documents ]"
	json_view.add_child(quests_editor)

	errors_label = _label("", &"EditorLabel", true)
	errors_label.name = "Errors"
	content.add_child(errors_label)
	registered_label = _label("", &"EditorLabel", true)
	registered_label.name = "Registered"
	content.add_child(registered_label)
	_reset_draft()
	_set_view(VIEW_FORM)


func _build_form(parent: VBoxContainer) -> void:
	var campaign_row := _row()
	parent.add_child(campaign_row)
	campaign_row.add_child(_line_field("campaign.id", "Campaign ID", "my-campaign"))
	campaign_row.add_child(_line_field("campaign.title", "Title", "Campaign title"))
	campaign_row.add_child(_option_field("campaign.entry_location", "Entry location"))

	var quest_row := _row()
	parent.add_child(quest_row)
	quest_row.add_child(_label("Quest", &"EditorHeading"))
	quest_picker = _option("Quest")
	quest_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_picker.item_selected.connect(_on_quest_selected)
	quest_row.add_child(quest_picker)
	quest_row.add_child(_button("New quest", "NewQuest", create_new_quest))
	quest_row.add_child(_button("Remove quest from draft", "RemoveQuest", remove_selected_quest))
	no_quest_label = _label("No quest in this draft. Add one with New quest.", &"EditorLabel", true)
	no_quest_label.name = "NoQuest"
	parent.add_child(no_quest_label)

	quest_fields = VBoxContainer.new()
	quest_fields.name = "QuestFields"
	quest_fields.theme_type_variation = &"EditorColumn"
	parent.add_child(quest_fields)
	var identity_row := _row()
	quest_fields.add_child(identity_row)
	for field: Array in QUEST_LINE_FIELDS:
		identity_row.add_child(_line_field(str(field[0]), str(field[1]), str(field[2])))
	identity_row.add_child(_option_field("giver_actor_id", "Giver"))
	identity_row.add_child(_option_field("dialogue_title", "Dialogue"))
	var decision_row := _row()
	quest_fields.add_child(decision_row)
	for field: Array in QUEST_TEXT_FIELDS:
		decision_row.add_child(_line_field(str(field[0]), str(field[1]), str(field[2])))

	var outcomes_header := _row()
	quest_fields.add_child(outcomes_header)
	outcomes_header.add_child(_label("Outcomes", &"EditorHeading"))
	outcome_requirement = _label("")
	outcome_requirement.name = "OutcomeRequirement"
	outcome_requirement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcomes_header.add_child(outcome_requirement)
	outcomes_header.add_child(_button("Add outcome", "AddOutcome", add_outcome_row))
	var outcomes_error := _error_label()
	outcomes_error.name = "OutcomesError"
	quest_fields.add_child(outcomes_error)
	_field_errors["outcomes"] = outcomes_error
	outcomes_container = VBoxContainer.new()
	outcomes_container.name = "Outcomes"
	outcomes_container.theme_type_variation = &"EditorColumn"
	quest_fields.add_child(outcomes_container)


func refresh(_payload: Dictionary) -> void:
	_refresh_campaigns(str(_selected_metadata(campaign_picker)))
	_render_registered()


func commands() -> Array[Callable]:
	return [
		Callable(model, "validate_draft"),
		Callable(model, "save_campaign"),
		Callable(model, "reload_campaign"),
	]


func new_draft() -> void:
	_clear_authorization()
	_reset_draft()
	errors_label.text = ""
	_set_status("NEW CAMPAIGN DRAFT · Add quests, then validate and save.")


func load_campaign(campaign_id: String) -> void:
	_clear_authorization()
	var draft: Dictionary = model.call("campaign_draft", campaign_id)
	if draft.is_empty():
		_set_status("No campaign '%s'." % campaign_id)
		return
	_campaign_data = (draft.get("campaign", {}) as Dictionary).duplicate(true)
	_quests.clear()
	for quest: Dictionary in draft.get("quests", []):
		_quests.append(quest.duplicate(true))
	_selected_quest = 0 if not _quests.is_empty() else -1
	_load_form()
	_write_json()
	_render_errors(draft.get("errors", []))
	_set_status("Loaded %s." % campaign_id)


## Switch to the guided form. A JSON draft that does not parse keeps the JSON view open.
func show_form() -> bool:
	if view == VIEW_JSON:
		var draft := _parse_json()
		if not bool(draft.get("valid", false)):
			_set_view(VIEW_JSON)
			_set_status("Fix the JSON before returning to the form: %s" % str(draft["error"]))
			return false
		_campaign_data = draft["campaign"]
		_quests = draft["quests"]
		_selected_quest = clampi(_selected_quest, -1, _quests.size() - 1)
		if _selected_quest < 0 and not _quests.is_empty():
			_selected_quest = 0
		_load_form()
	_set_view(VIEW_FORM)
	return true


## Switch to the raw JSON documents, carrying the form's draft across.
func show_json() -> void:
	if view == VIEW_FORM:
		_store_form()
		_write_json()
	_set_view(VIEW_JSON)


## Start a quest with the two outcome rows the loader requires at minimum.
func create_new_quest() -> void:
	_store_form()
	_quests.append({
		"schema": CampaignQuestLoader.QUEST_SCHEMA,
		"kind": "side_quest",
		"quest_id": "",
		"name": "",
		"giver_actor_id": "",
		"dialogue_title": "",
		"decision_prompt": "",
		"resolution_flag": "",
		"outcomes": [_empty_outcome(), _empty_outcome()],
	})
	_selected_quest = _quests.size() - 1
	_load_form()
	_clear_errors()


func remove_selected_quest() -> void:
	if _selected_quest < 0 or _selected_quest >= _quests.size():
		return
	_quests.remove_at(_selected_quest)
	_selected_quest = mini(_selected_quest, _quests.size() - 1)
	_load_form()
	_clear_errors()
	_set_status("QUEST REMOVED FROM DRAFT · Save to delete its package file.")


func add_outcome_row() -> void:
	_add_outcome_row(_empty_outcome())
	_refresh_outcome_labels()


## Rows may go below the loader minimum; validation then names the requirement inline.
func remove_outcome_row(row: Dictionary) -> void:
	var index := outcome_rows.find(row)
	if index < 0:
		return
	outcome_rows.remove_at(index)
	var panel := row["panel"] as Control
	outcomes_container.remove_child(panel)
	panel.queue_free()
	_refresh_outcome_labels()


## Inline error shown beside a form field (`campaign.<field>`, a quest field, or `outcomes`).
func field_error(key: String) -> String:
	var label := _field_errors.get(key) as Label
	return label.text if label != null else ""


func outcome_field_error(index: int, key: String) -> String:
	if index < 0 or index >= outcome_rows.size():
		return ""
	var label := (outcome_rows[index]["errors"] as Dictionary).get(key) as Label
	return label.text if label != null else ""


## Set a form field by key, as an author typing or picking would.
func set_field(key: String, value: String) -> void:
	var control: Control = _field_controls.get(key)
	if control is LineEdit:
		(control as LineEdit).text = value
	elif control is OptionButton:
		_select_value(control as OptionButton, value)


func set_outcome_field(index: int, key: String, value: Variant) -> void:
	var control: Control = (outcome_rows[index]["controls"] as Dictionary).get(key)
	if control is LineEdit:
		(control as LineEdit).text = str(value)
	elif control is SpinBox:
		(control as SpinBox).value = float(value)
	elif control is OptionButton:
		_select_value(control as OptionButton, str(value))


## The draft as `{valid, campaign, quests}` or `{valid: false, error}`, from the active view.
func current_draft() -> Dictionary:
	if view == VIEW_JSON:
		return _parse_json()
	_store_form()
	var quests: Array[Dictionary] = []
	for quest: Dictionary in _quests:
		quests.append(quest.duplicate(true))
	return {"valid": true, "campaign": _collect_campaign(), "quests": quests}


func validate() -> Dictionary:
	_clear_authorization()
	var draft := current_draft()
	if not bool(draft.get("valid", false)):
		_set_status(str(draft["error"]))
		return {}
	var quests: Array[Dictionary] = draft["quests"]
	last_result = model.call("validate_draft", draft["campaign"], quests)
	_render_errors(last_result.get("errors", []))
	_set_status(
		"VALID · CampaignQuestLoader accepts this draft."
		if (last_result.get("errors", []) as Array).is_empty()
		else "NOT VALID · Fix the loader errors listed below."
	)
	return last_result


func save(force: bool = false, authorized: Array[String] = []) -> Dictionary:
	_clear_authorization()
	var draft := current_draft()
	if not bool(draft.get("valid", false)):
		_set_status(str(draft["error"]))
		return {}
	var quests: Array[Dictionary] = draft["quests"]
	last_result = model.call("save_campaign", draft["campaign"], quests, force, authorized)
	_render_errors(last_result.get("errors", []))
	_render_registered()
	var saved := bool(last_result.get("saved", false))
	if saved:
		_campaign_data = (draft["campaign"] as Dictionary).duplicate(true)
		_refresh_campaigns(str(_campaign_data.get("id", "")))
	if not (last_result.get("registration_conflicts", []) as Array).is_empty():
		_offer_authorization(&"save", saved)
	elif saved:
		_set_status("SAVED · RELOADED THROUGH CAMPAIGNQUESTLOADER · REGISTERED")
	else:
		_set_status("NOT SAVED · Loader errors must be resolved.")
	return last_result


func reload(force: bool = false, authorized: Array[String] = []) -> Dictionary:
	_clear_authorization()
	var campaign_id := ""
	var draft := current_draft()
	if bool(draft.get("valid", false)):
		campaign_id = str((draft["campaign"] as Dictionary).get("id", ""))
	if campaign_id.is_empty():
		campaign_id = str(_selected_metadata(campaign_picker))
	last_result = model.call("reload_campaign", campaign_id, force, authorized)
	_render_errors(last_result.get("errors", []))
	_render_registered()
	if not (last_result.get("registration_conflicts", []) as Array).is_empty():
		_offer_authorization(&"reload", false)
	elif (last_result.get("errors", []) as Array).is_empty() and not last_result.is_empty():
		_set_status("RELOADED THROUGH CAMPAIGNQUESTLOADER · REGISTERED")
	else:
		_set_status("RELOAD REJECTED · Loader errors are listed below.")
	return last_result


## Retry the refused action with explicit authorisation for exactly the listed quests.
func authorize() -> Dictionary:
	var action := _pending_action
	var identities: Array[String] = _pending_identities.duplicate()
	_clear_authorization()
	if action == &"save":
		return save(true, identities)
	if action == &"reload":
		return reload(true, identities)
	return {}


func _offer_authorization(action: StringName, saved_to_disk: bool) -> void:
	var names: PackedStringArray = []
	for conflict: Dictionary in last_result.get("registration_conflicts", []):
		var identity := str(conflict.get("identity", "unknown quest"))
		names.append("%s (%s, %s)" % [
			str(conflict.get("name", identity)), identity, str(conflict.get("state", "live")),
		])
		_pending_identities.append(identity)
	_pending_action = action
	authorize_button.visible = true
	_set_status(
		("SAVED TO DISK · " if saved_to_disk else "")
		+ "REGISTRATION REFUSED · Would reset live progress for: %s" % ", ".join(names)
	)


func _clear_authorization() -> void:
	_pending_action = &""
	_pending_identities.clear()
	if authorize_button != null:
		authorize_button.visible = false


func _refresh_campaigns(selected_id: String) -> void:
	campaign_picker.clear()
	for summary: Dictionary in model.call("campaign_summaries"):
		var campaign_id := str(summary.get("id", ""))
		campaign_picker.add_item("%s — %s" % [campaign_id, str(summary.get("title", campaign_id))])
		campaign_picker.set_item_metadata(campaign_picker.item_count - 1, campaign_id)
		if campaign_id == selected_id:
			campaign_picker.select(campaign_picker.item_count - 1)


func _render_errors(errors: Array) -> void:
	_clear_errors()
	var lines: PackedStringArray = []
	for error: Dictionary in errors:
		var file_path := str(error.get("file", ""))
		var field := str(error.get("field", "$"))
		var expected := str(error.get("expected", ""))
		var message := str(error.get("message", ""))
		lines.append("%s · %s · expected %s · %s" % [file_path, field, expected, message])
		# The full loader line is listed below; beside the field its message is enough.
		var inline := message if not message.is_empty() else "Expected %s." % expected
		if file_path.ends_with("campaign.json"):
			_set_error_text(_field_errors.get("campaign." + field) as Label, inline)
		elif _quest_index_for_file(file_path) == _selected_quest and _selected_quest >= 0:
			_set_quest_error(field, inline)
	errors_label.text = "No loader errors." if lines.is_empty() else "\n".join(lines)


func _render_registered() -> void:
	var rows: Array = model.call("registered_view")
	var lines: PackedStringArray = []
	for row: Dictionary in rows:
		lines.append("%s — %s" % [str(row.get("identity", "")), str(row.get("name", ""))])
	registered_label.text = "REGISTERED: %s" % ("none" if lines.is_empty() else ", ".join(lines))


# --- Guided form ---------------------------------------------------------------------------

func _set_view(next: StringName) -> void:
	view = next
	form_view.visible = view == VIEW_FORM
	json_view.visible = view == VIEW_JSON
	(_form_button if view == VIEW_FORM else _json_button).set_pressed_no_signal(true)


func _reset_draft() -> void:
	_campaign_data = {}
	_quests.clear()
	_selected_quest = -1
	_load_form()
	campaign_editor.text = "{}"
	quests_editor.text = "[]"
	_clear_errors()


## Field group: caption and control on one line, the field's loader error underneath.
func _field(key: String, caption: String, control: Control) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = "Field_" + key.replace(".", "_")
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := _row()
	group.add_child(line)
	line.add_child(_label(caption))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(control)
	var error := _error_label()
	group.add_child(error)
	_field_controls[key] = control
	_field_errors[key] = error
	return group


func _line_field(key: String, caption: String, placeholder: String) -> VBoxContainer:
	var edit := LineEdit.new()
	edit.name = key.replace(".", "_")
	edit.placeholder_text = placeholder
	return _field(key, caption, edit)


func _option_field(key: String, caption: String) -> VBoxContainer:
	return _field(key, caption, _option(key.replace(".", "_")))


func _error_label() -> Label:
	var label := _label("", &"DangerLabel", true)
	label.visible = false
	return label


static func _set_error_text(label: Label, text: String) -> void:
	if label == null:
		return
	label.text = text
	label.visible = not text.is_empty()


func _load_form() -> void:
	_loading = true
	_line("campaign.id").text = str(_campaign_data.get("id", ""))
	_line("campaign.title").text = str(_campaign_data.get("title", ""))
	_populate_option(
		_field_controls["campaign.entry_location"], _source_values(&"location_ids"),
		str(_campaign_data.get("entry_location", ""))
	)
	quest_picker.clear()
	for index: int in _quests.size():
		var quest: Dictionary = _quests[index]
		var quest_id := str(quest.get("quest_id", ""))
		quest_picker.add_item("%s — %s" % [
			quest_id if not quest_id.is_empty() else "<new quest>", str(quest.get("name", "")),
		])
	var has_quest := _selected_quest >= 0 and _selected_quest < _quests.size()
	quest_fields.visible = has_quest
	no_quest_label.visible = not has_quest
	var quest: Dictionary = _quests[_selected_quest] if has_quest else {}
	if has_quest:
		quest_picker.select(_selected_quest)
	for field: Array in QUEST_LINE_FIELDS + QUEST_TEXT_FIELDS:
		_line(str(field[0])).text = str(quest.get(str(field[0]), ""))
	_populate_option(
		_field_controls["giver_actor_id"], _source_values(&"giver_actor_ids"),
		str(quest.get("giver_actor_id", ""))
	)
	_populate_dialogue_option(str(quest.get("dialogue_title", "")))
	for row: Dictionary in outcome_rows:
		var panel := row["panel"] as Control
		outcomes_container.remove_child(panel)
		panel.queue_free()
	outcome_rows.clear()
	for outcome_value: Variant in quest.get("outcomes", []):
		if outcome_value is Dictionary:
			_add_outcome_row(outcome_value as Dictionary)
	_refresh_outcome_labels()
	_loading = false


func _add_outcome_row(outcome: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"EditorPanel"
	outcomes_container.add_child(panel)
	var column := VBoxContainer.new()
	column.theme_type_variation = &"EditorColumn"
	panel.add_child(column)
	var fields := _row()
	column.add_child(fields)
	var remove := Button.new()
	remove.name = "RemoveOutcome"
	remove.text = "Remove outcome"
	remove.theme_type_variation = &"EditorButton"
	remove.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var controls: Dictionary = {}
	var errors: Dictionary = {}
	for field: Array in OUTCOME_LINE_FIELDS.slice(0, 2):
		fields.add_child(_outcome_line(controls, errors, field, outcome))
	# The heading leads the ID field's line so it stays level with the controls when an
	# inline error grows the row.
	var heading := _label("Outcome", &"EditorHeading")
	var id_line := (controls["id"] as Control).get_parent()
	id_line.add_child(heading)
	id_line.move_child(heading, 0)
	var faction := _option("Faction")
	_populate_option(faction, _source_values(&"faction_ids"), str(outcome.get("faction_id", "")))
	fields.add_child(_outcome_group(controls, errors, "faction_id", "Faction", faction))
	var delta := SpinBox.new()
	delta.name = "ReputationDelta"
	delta.theme_type_variation = &"EditorSpinBox"
	delta.min_value = -1000.0
	delta.max_value = 1000.0
	delta.step = 0.5
	delta.value = float(outcome.get("reputation_delta", 0.0))
	fields.add_child(_outcome_group(controls, errors, "reputation_delta", "Reputation", delta))
	fields.add_child(remove)
	var text_fields := _row()
	column.add_child(text_fields)
	for field: Array in OUTCOME_LINE_FIELDS.slice(2):
		text_fields.add_child(_outcome_line(controls, errors, field, outcome))
	var row := {
		"panel": panel, "heading": heading, "remove": remove,
		"controls": controls, "errors": errors, "source": outcome.duplicate(true),
	}
	outcome_rows.append(row)
	remove.pressed.connect(remove_outcome_row.bind(row))


func _outcome_line(
	controls: Dictionary, errors: Dictionary, field: Array, outcome: Dictionary
) -> VBoxContainer:
	var key := str(field[0])
	var edit := LineEdit.new()
	edit.name = key.capitalize().replace(" ", "")
	edit.text = str(outcome.get(key, ""))
	return _outcome_group(controls, errors, key, str(field[1]), edit)


func _outcome_group(
	controls: Dictionary, errors: Dictionary, key: String, caption: String, control: Control
) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line := _row()
	group.add_child(line)
	line.add_child(_label(caption))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(control)
	var error := _error_label()
	group.add_child(error)
	controls[key] = control
	errors[key] = error
	return group


func _refresh_outcome_labels() -> void:
	for index: int in outcome_rows.size():
		(outcome_rows[index]["heading"] as Label).text = "Outcome %d" % (index + 1)
		(outcome_rows[index]["remove"] as Button).disabled = false
	outcome_requirement.text = "Minimum %d outcomes (runtime requirement). Current: %d." % [
		OUTCOME_MINIMUM, outcome_rows.size(),
	]
	outcome_requirement.theme_type_variation = (
		&"DangerLabel" if outcome_rows.size() < OUTCOME_MINIMUM else &"EditorLabel"
	)


func _on_quest_selected(index: int) -> void:
	if _loading or index < 0 or index >= _quests.size():
		return
	_store_form()
	_selected_quest = index
	_load_form()
	_clear_errors()


## Write the form back into the draft, keeping every field the form does not show.
func _store_form() -> void:
	if _loading or view != VIEW_FORM:
		return
	_campaign_data = _collect_campaign()
	if _selected_quest < 0 or _selected_quest >= _quests.size():
		return
	var quest: Dictionary = _quests[_selected_quest].duplicate(true)
	for field: Array in QUEST_LINE_FIELDS + QUEST_TEXT_FIELDS:
		quest[str(field[0])] = _line(str(field[0])).text.strip_edges()
	quest["giver_actor_id"] = str(_selected_metadata(_field_controls["giver_actor_id"]))
	quest["dialogue_title"] = str(_selected_metadata(_field_controls["dialogue_title"]))
	var outcomes: Array = []
	for row: Dictionary in outcome_rows:
		var controls: Dictionary = row["controls"]
		var outcome: Dictionary = (row["source"] as Dictionary).duplicate(true)
		for field: Array in OUTCOME_LINE_FIELDS:
			outcome[str(field[0])] = (controls[str(field[0])] as LineEdit).text.strip_edges()
		outcome["faction_id"] = str(_selected_metadata(controls["faction_id"]))
		outcome["reputation_delta"] = (controls["reputation_delta"] as SpinBox).value
		outcomes.append(outcome)
	quest["outcomes"] = outcomes
	_quests[_selected_quest] = quest
	var item_id := str(quest.get("quest_id", ""))
	quest_picker.set_item_text(_selected_quest, "%s — %s" % [
		item_id if not item_id.is_empty() else "<new quest>", str(quest.get("name", "")),
	])


func _collect_campaign() -> Dictionary:
	var campaign: Dictionary = _campaign_data.duplicate(true)
	campaign["id"] = _line("campaign.id").text.strip_edges()
	campaign["title"] = _line("campaign.title").text.strip_edges()
	var entry := str(_selected_metadata(_field_controls["campaign.entry_location"]))
	campaign["entry_location"] = entry
	var locations: Array = campaign.get("locations", [])
	if not entry.is_empty() and not locations.has(entry):
		locations.append(entry)
	campaign["locations"] = locations
	return campaign


func _write_json() -> void:
	campaign_editor.text = JSON.stringify(_campaign_data, "  ")
	quests_editor.text = JSON.stringify(_quests, "  ")


func _parse_json() -> Dictionary:
	var campaign: Variant = _json_value(campaign_editor.text)
	if not campaign is Dictionary:
		return {"valid": false, "error": "campaign.json must be a JSON object."}
	var quest_values: Variant = _json_value(quests_editor.text)
	if not quest_values is Array:
		return {"valid": false, "error": "Quests must be a JSON array of quest objects."}
	var quests: Array[Dictionary] = []
	for quest_value: Variant in quest_values:
		if not quest_value is Dictionary:
			return {"valid": false, "error": "Every quest must be a JSON object."}
		quests.append(quest_value as Dictionary)
	return {"valid": true, "campaign": campaign, "quests": quests}


## Parsed JSON, or null for text that does not parse (reported as a draft error, not logged).
static func _json_value(text: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null


## The draft quest a loader error file names: `<quest_id>.json`, or `draft-<n>.json` for a
## quest whose id is not yet a safe file name.
func _quest_index_for_file(file_path: String) -> int:
	var stem := file_path.get_file().get_basename()
	if stem.begins_with("draft-") and stem.trim_prefix("draft-").is_valid_int():
		return stem.trim_prefix("draft-").to_int()
	for index: int in _quests.size():
		if str(_quests[index].get("quest_id", "")) == stem:
			return index
	return -1


func _set_quest_error(field: String, text: String) -> void:
	if field.begins_with("outcomes["):
		var close := field.find("]")
		var index_text := field.substr(9, close - 9) if close > 9 else ""
		if not index_text.is_valid_int():
			return
		var index := index_text.to_int()
		if index >= 0 and index < outcome_rows.size():
			var row_errors: Dictionary = outcome_rows[index]["errors"]
			_set_error_text(row_errors.get(field.substr(close + 1).trim_prefix(".")) as Label, text)
		return
	_set_error_text(_field_errors.get(field) as Label, text)


func _clear_errors() -> void:
	for label: Label in _field_errors.values():
		_set_error_text(label, "")
	for row: Dictionary in outcome_rows:
		for label: Label in (row["errors"] as Dictionary).values():
			_set_error_text(label, "")


func _populate_option(control: OptionButton, values: Array[String], selected: String) -> void:
	control.clear()
	var options: Array[String] = values.duplicate()
	if not selected.is_empty() and not options.has(selected):
		options.push_front(selected)
	for value: String in options:
		control.add_item(value)
		control.set_item_metadata(control.item_count - 1, value)
		if value == selected:
			control.select(control.item_count - 1)


func _populate_dialogue_option(selected: String) -> void:
	var picker: OptionButton = _field_controls["dialogue_title"]
	picker.clear()
	var options: Array = model.call("dialogue_title_options", _line("campaign.id").text.strip_edges())
	var available := false
	for option: Dictionary in options:
		available = available or str(option.get("title", "")) == selected
	if not selected.is_empty() and not available:
		picker.add_item("[UNAVAILABLE] %s" % selected)
		picker.set_item_metadata(0, selected)
	for option: Dictionary in options:
		var title_value := str(option.get("title", ""))
		if title_value.is_empty():
			continue
		picker.add_item(str(option.get("label", title_value)))
		picker.set_item_metadata(picker.item_count - 1, title_value)
		if title_value == selected:
			picker.select(picker.item_count - 1)


static func _select_value(option: OptionButton, value: String) -> void:
	for index: int in option.item_count:
		if str(option.get_item_metadata(index)) == value:
			option.select(index)
			return
	option.add_item(value)
	option.set_item_metadata(option.item_count - 1, value)
	option.select(option.item_count - 1)


func _source_values(method: StringName) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in model.call(method):
		result.append(str(value))
	return result


func _line(key: String) -> LineEdit:
	return _field_controls[key] as LineEdit


static func _empty_outcome() -> Dictionary:
	return {
		"id": "", "label": "", "faction_id": "", "reputation_delta": 0.0,
		"cause": "", "readback": "",
	}
