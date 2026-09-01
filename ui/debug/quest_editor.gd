extends Control
## In-game editor for the exact campaign package format CampaignQuestLoader consumes.

var _editor: Node = null
var _campaign_picker: OptionButton = null
var _quest_list: ItemList = null
var _entry_location_picker: OptionButton = null
var _giver_picker: OptionButton = null
var _dialogue_picker: OptionButton = null
var _outcomes_container: VBoxContainer = null
var _outcome_requirement: Label = null
var _validation_container: VBoxContainer = null
var _registered_label: Label = null
var _status: Label = null
var _force_registration_button: Button = null
var _field_controls: Dictionary = {}
var _field_errors: Dictionary = {}
var _outcome_rows: Array[Dictionary] = []
var _campaign_data: Dictionary = {}
var _quests: Array[Dictionary] = []
var _selected_quest_index: int = -1
var _loading: bool = false
var _pending_force_action: StringName = &""
var _pending_force_conflict_identities: Array[String] = []


func configure(editor: Node) -> void:
	_editor = editor
	theme = UIManager.ui_theme
	_build_interface()
	_refresh_campaign_picker()
	var campaign_ids: Array[String] = _source_values(&"campaign_ids")
	if campaign_ids.is_empty():
		start_new_campaign()
	else:
		_load_campaign(campaign_ids[0])


func start_new_campaign() -> void:
	if _editor == null:
		return
	_store_selected_quest()
	_campaign_data = {}
	_quests.clear()
	_selected_quest_index = -1
	_loading = true
	_line_control("campaign.id").text = ""
	_line_control("campaign.title").text = ""
	_populate_option(_entry_location_picker, _source_values(&"location_ids"), "")
	_loading = false
	_refresh_quest_list()
	_clear_quest_form()
	_clear_errors()
	_clear_registration_confirmation()
	_set_status("NEW CAMPAIGN DRAFT · Add a quest, then validate and save.", "MutedLabel")


func create_new_quest() -> void:
	if _editor == null:
		return
	_store_selected_quest()
	var quest: Dictionary = {
		"schema": CampaignQuestLoader.QUEST_SCHEMA,
		"kind": "side_quest",
		"quest_id": "",
		"name": "",
		"giver_actor_id": _first_value(_source_values(&"giver_actor_ids")),
		"dialogue_title": _first_value(_source_values(&"dialogue_titles")),
		"decision_prompt": "",
		"resolution_flag": "",
		"outcomes": [_empty_outcome(), _empty_outcome()],
	}
	_quests.append(quest)
	_selected_quest_index = _quests.size() - 1
	_refresh_quest_list()
	_quest_list.select(_selected_quest_index)
	_load_quest_form(_selected_quest_index)
	_clear_errors()


func _build_interface() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = "WorldMapSidebar"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36.0
	panel.offset_top = 28.0
	panel.offset_right = -36.0
	panel.offset_bottom = -28.0
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.theme_type_variation = "ScreenWindowMargin"
	panel.add_child(margin)
	var shell: VBoxContainer = VBoxContainer.new()
	shell.theme_type_variation = "ScreenShellColumn"
	margin.add_child(shell)
	shell.add_child(_label("QUEST EDITOR", "TitleLabel"))
	shell.add_child(_label(
		"F6 · Authors user://campaigns packages. It never offers or resolves quests.",
		"MutedLabel"
	))
	_build_campaign_bar(shell)

	var body: HSplitContainer = HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(body)
	_build_quest_list(body)
	_build_editor_form(body)
	_build_footer(shell)


func _build_campaign_bar(parent: VBoxContainer) -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.theme_type_variation = "ScreenHeader"
	parent.add_child(bar)
	bar.add_child(_label("CAMPAIGN", "EyebrowLabel"))
	_campaign_picker = OptionButton.new()
	_campaign_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_campaign_picker.item_selected.connect(_on_campaign_selected)
	bar.add_child(_campaign_picker)
	var new_campaign: Button = Button.new()
	new_campaign.text = "NEW CAMPAIGN"
	new_campaign.pressed.connect(start_new_campaign)
	bar.add_child(new_campaign)
	var reload: Button = Button.new()
	reload.text = "RELOAD PACKAGE + REGISTER"
	reload.pressed.connect(_reload_current_campaign)
	bar.add_child(reload)

	var fields: HBoxContainer = HBoxContainer.new()
	fields.theme_type_variation = "ScreenHeader"
	parent.add_child(fields)
	_add_line_field(fields, "CAMPAIGN ID", "campaign.id", "my-campaign")
	_add_line_field(fields, "TITLE", "campaign.title", "Campaign title")
	var entry_group: VBoxContainer = VBoxContainer.new()
	entry_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_group.add_child(_label("ENTRY LOCATION", "EyebrowLabel"))
	_entry_location_picker = OptionButton.new()
	_entry_location_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_group.add_child(_entry_location_picker)
	var entry_error: Label = _label("", "DangerLabel")
	entry_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry_group.add_child(entry_error)
	_field_errors["campaign.entry_location"] = entry_error
	fields.add_child(entry_group)


func _build_quest_list(parent: HSplitContainer) -> void:
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(300.0, 0.0)
	parent.add_child(sidebar)
	sidebar.add_child(_label("PACKAGE QUESTS", "HeadingLabel"))
	_quest_list = ItemList.new()
	_quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_list.item_selected.connect(_on_quest_selected)
	sidebar.add_child(_quest_list)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.theme_type_variation = "ScreenHeader"
	sidebar.add_child(buttons)
	var add_quest: Button = Button.new()
	add_quest.text = "NEW QUEST"
	add_quest.theme_type_variation = "BronzeButton"
	add_quest.pressed.connect(create_new_quest)
	buttons.add_child(add_quest)
	var delete_quest: Button = Button.new()
	delete_quest.text = "REMOVE FROM DRAFT"
	delete_quest.theme_type_variation = "DangerButton"
	delete_quest.pressed.connect(_remove_selected_quest)
	buttons.add_child(delete_quest)


func _build_editor_form(parent: HSplitContainer) -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var form: VBoxContainer = VBoxContainer.new()
	form.theme_type_variation = "ScreenContentColumn"
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	form.add_child(_label("QUEST DRAFT", "HeadingLabel"))
	_add_line_field(form, "QUEST ID", "quest_id", "quest-id")
	_add_line_field(form, "NAME", "name", "Quest name")
	_add_option_field(form, "GIVER ACTOR", "giver_actor_id")
	_giver_picker = _field_controls["giver_actor_id"] as OptionButton
	_add_option_field(form, "DIALOGUE TITLE", "dialogue_title")
	_dialogue_picker = _field_controls["dialogue_title"] as OptionButton
	_add_line_field(form, "DECISION PROMPT", "decision_prompt", "What does the player decide?")
	_add_line_field(form, "RESOLUTION FLAG", "resolution_flag", "quest_resolution_flag")
	form.add_child(_label("OUTCOMES", "HeadingLabel"))
	_outcome_requirement = _label("Minimum 2 outcomes (runtime requirement).", "MutedLabel")
	form.add_child(_outcome_requirement)
	_outcomes_container = VBoxContainer.new()
	_outcomes_container.theme_type_variation = "ScreenContentColumn"
	form.add_child(_outcomes_container)
	var add_outcome: Button = Button.new()
	add_outcome.text = "ADD OUTCOME OBJECT"
	add_outcome.pressed.connect(_add_blank_outcome)
	form.add_child(add_outcome)
	form.add_child(_label("VALIDATION", "HeadingLabel"))
	_validation_container = VBoxContainer.new()
	_validation_container.theme_type_variation = "ScreenContentColumn"
	form.add_child(_validation_container)
	form.add_child(_label("LOADER-REGISTERED QUESTS · READ ONLY", "HeadingLabel"))
	_registered_label = _label("Nothing loaded through CampaignQuestLoader yet.", "MutedLabel")
	_registered_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(_registered_label)


func _build_footer(parent: VBoxContainer) -> void:
	_status = _label("", "MutedLabel")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(_status)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.theme_type_variation = "ScreenHeader"
	buttons.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(buttons)
	var validate: Button = Button.new()
	validate.text = "VALIDATE WITH LOADER"
	validate.pressed.connect(_validate_current)
	buttons.add_child(validate)
	_force_registration_button = Button.new()
	_force_registration_button.text = "CONFIRM RESET + REGISTER"
	_force_registration_button.theme_type_variation = "DangerButton"
	_force_registration_button.visible = false
	_force_registration_button.pressed.connect(_confirm_force_registration)
	buttons.add_child(_force_registration_button)
	var save: Button = Button.new()
	save.text = "SAVE + RELOAD + REGISTER"
	save.theme_type_variation = "BronzeButton"
	save.pressed.connect(_save_current)
	buttons.add_child(save)
	var close: Button = Button.new()
	close.text = "CLOSE (F6)"
	close.pressed.connect(func() -> void: _editor.call("close_overlay"))
	buttons.add_child(close)


func _add_line_field(
	parent: Container, caption: String, key: String, placeholder: String
) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(_label(caption, "EyebrowLabel"))
	var control: LineEdit = LineEdit.new()
	control.placeholder_text = placeholder
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(control)
	var error: Label = _label("", "DangerLabel")
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(error)
	parent.add_child(group)
	_field_controls[key] = control
	_field_errors[key] = error


func _add_option_field(parent: Container, caption: String, key: String) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_child(_label(caption, "EyebrowLabel"))
	var control: OptionButton = OptionButton.new()
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_child(control)
	var error: Label = _label("", "DangerLabel")
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(error)
	parent.add_child(group)
	_field_controls[key] = control
	_field_errors[key] = error


func _refresh_campaign_picker(selected_id: String = "") -> void:
	_loading = true
	_campaign_picker.clear()
	var summaries_value: Variant = _editor.call("campaign_summaries")
	if summaries_value is Array:
		for summary_value: Variant in summaries_value:
			if not summary_value is Dictionary:
				continue
			var summary: Dictionary = summary_value as Dictionary
			var campaign_id: String = str(summary.get("id", ""))
			var title: String = str(summary.get("title", campaign_id))
			_campaign_picker.add_item("%s · %s" % [campaign_id, title])
			_campaign_picker.set_item_metadata(_campaign_picker.item_count - 1, campaign_id)
			if campaign_id == selected_id:
				_campaign_picker.select(_campaign_picker.item_count - 1)
	_loading = false


func _on_campaign_selected(index: int) -> void:
	if _loading or index < 0:
		return
	var campaign_id: String = str(_campaign_picker.get_item_metadata(index))
	_load_campaign(campaign_id)


func _load_campaign(campaign_id: String) -> void:
	_store_selected_quest()
	var draft_value: Variant = _editor.call("campaign_draft", campaign_id)
	if not draft_value is Dictionary:
		return
	var draft: Dictionary = draft_value as Dictionary
	var campaign_value: Variant = draft.get("campaign", {})
	_campaign_data = (
		(campaign_value as Dictionary).duplicate(true) if campaign_value is Dictionary else {}
	)
	_quests.clear()
	var quest_values: Variant = draft.get("quests", [])
	if quest_values is Array:
		for quest_value: Variant in quest_values:
			if quest_value is Dictionary:
				_quests.append((quest_value as Dictionary).duplicate(true))
	_loading = true
	_line_control("campaign.id").text = str(_campaign_data.get("id", campaign_id))
	_line_control("campaign.title").text = str(_campaign_data.get("title", ""))
	_populate_option(
		_entry_location_picker,
		_source_values(&"location_ids"),
		str(_campaign_data.get("entry_location", ""))
	)
	_loading = false
	_selected_quest_index = 0 if not _quests.is_empty() else -1
	_refresh_quest_list()
	if _selected_quest_index >= 0:
		_quest_list.select(_selected_quest_index)
		_load_quest_form(_selected_quest_index)
	else:
		_clear_quest_form()
	_render_errors(draft.get("errors", []))
	_render_registered()
	_clear_registration_confirmation()
	_set_status("LOADED %s FROM DISK" % campaign_id, "MutedLabel")


func _refresh_quest_list() -> void:
	_quest_list.clear()
	for index: int in _quests.size():
		var quest: Dictionary = _quests[index]
		var quest_id: String = str(quest.get("quest_id", ""))
		var quest_name: String = str(quest.get("name", ""))
		var display_id: String = quest_id if not quest_id.is_empty() else "<new quest>"
		_quest_list.add_item("%s\n%s" % [display_id, quest_name])
		_quest_list.set_item_metadata(index, index)


func _on_quest_selected(index: int) -> void:
	if _loading or index < 0 or index >= _quests.size():
		return
	_store_selected_quest()
	_selected_quest_index = index
	_load_quest_form(index)
	_clear_errors()


func _load_quest_form(index: int) -> void:
	if index < 0 or index >= _quests.size():
		_clear_quest_form()
		return
	var quest: Dictionary = _quests[index]
	_loading = true
	for key: String in ["quest_id", "name", "decision_prompt", "resolution_flag"]:
		_line_control(key).text = str(quest.get(key, ""))
	_populate_option(_giver_picker, _source_values(&"giver_actor_ids"), str(quest.get("giver_actor_id", "")))
	_populate_option(_dialogue_picker, _source_values(&"dialogue_titles"), str(quest.get("dialogue_title", "")))
	var outcomes: Array[Dictionary] = []
	var outcome_values: Variant = quest.get("outcomes", [])
	if outcome_values is Array:
		for outcome_value: Variant in outcome_values:
			if outcome_value is Dictionary:
				outcomes.append((outcome_value as Dictionary).duplicate(true))
	_rebuild_outcomes(outcomes)
	_loading = false


func _clear_quest_form() -> void:
	_loading = true
	for key: String in ["quest_id", "name", "decision_prompt", "resolution_flag"]:
		_line_control(key).text = ""
	_populate_option(_giver_picker, _source_values(&"giver_actor_ids"), "")
	_populate_option(_dialogue_picker, _source_values(&"dialogue_titles"), "")
	_rebuild_outcomes([])
	_loading = false


func _store_selected_quest() -> void:
	if _loading or _selected_quest_index < 0 or _selected_quest_index >= _quests.size():
		return
	var quest: Dictionary = _quests[_selected_quest_index].duplicate(true)
	quest["schema"] = CampaignQuestLoader.QUEST_SCHEMA
	quest["kind"] = "side_quest"
	for key: String in ["quest_id", "name", "decision_prompt", "resolution_flag"]:
		quest[key] = _line_control(key).text.strip_edges()
	quest["giver_actor_id"] = _selected_option_value(_giver_picker)
	quest["dialogue_title"] = _selected_option_value(_dialogue_picker)
	quest["outcomes"] = _collect_outcomes()
	_quests[_selected_quest_index] = quest


func _remove_selected_quest() -> void:
	if _selected_quest_index < 0 or _selected_quest_index >= _quests.size():
		return
	_quests.remove_at(_selected_quest_index)
	_selected_quest_index = mini(_selected_quest_index, _quests.size() - 1)
	_refresh_quest_list()
	if _selected_quest_index >= 0:
		_quest_list.select(_selected_quest_index)
		_load_quest_form(_selected_quest_index)
	else:
		_clear_quest_form()
	_clear_errors()
	_set_status("QUEST REMOVED FROM DRAFT · Save to delete its package file.", "MutedLabel")


func _rebuild_outcomes(outcomes: Array[Dictionary]) -> void:
	_clear_children(_outcomes_container)
	_outcome_rows.clear()
	for outcome: Dictionary in outcomes:
		_add_outcome_row(outcome)
	_refresh_outcome_labels()


func _add_blank_outcome() -> void:
	_add_outcome_row(_empty_outcome())
	_refresh_outcome_labels()


func _add_outcome_row(outcome: Dictionary) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = "ConsequenceNoticePanel"
	_outcomes_container.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = "ScreenContentColumn"
	panel.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	header.theme_type_variation = "ScreenHeader"
	column.add_child(header)
	var heading: Label = _label("OUTCOME", "EyebrowLabel")
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var remove: Button = Button.new()
	remove.text = "REMOVE"
	remove.theme_type_variation = "DangerButton"
	header.add_child(remove)

	var controls: Dictionary = {}
	var errors: Dictionary = {}
	_add_outcome_line(column, controls, errors, "id", "ID", str(outcome.get("id", "")))
	_add_outcome_line(column, controls, errors, "label", "LABEL", str(outcome.get("label", "")))
	var faction_group: VBoxContainer = VBoxContainer.new()
	faction_group.add_child(_label("FACTION", "EyebrowLabel"))
	var faction: OptionButton = OptionButton.new()
	_populate_option(faction, _source_values(&"faction_ids"), str(outcome.get("faction_id", "")))
	faction_group.add_child(faction)
	var faction_error: Label = _label("", "DangerLabel")
	faction_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction_group.add_child(faction_error)
	column.add_child(faction_group)
	controls["faction_id"] = faction
	errors["faction_id"] = faction_error

	var delta_group: VBoxContainer = VBoxContainer.new()
	delta_group.add_child(_label("REPUTATION DELTA", "EyebrowLabel"))
	var delta: SpinBox = SpinBox.new()
	delta.min_value = -1000.0
	delta.max_value = 1000.0
	delta.step = 0.5
	delta.value = float(outcome.get("reputation_delta", 0.0))
	delta_group.add_child(delta)
	var delta_error: Label = _label("", "DangerLabel")
	delta_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delta_group.add_child(delta_error)
	column.add_child(delta_group)
	controls["reputation_delta"] = delta
	errors["reputation_delta"] = delta_error
	_add_outcome_line(column, controls, errors, "cause", "CAUSE", str(outcome.get("cause", "")))
	_add_outcome_line(column, controls, errors, "readback", "READBACK", str(outcome.get("readback", "")))

	var row: Dictionary = {
		"panel": panel,
		"heading": heading,
		"remove": remove,
		"controls": controls,
		"errors": errors,
	}
	_outcome_rows.append(row)
	remove.pressed.connect(_remove_outcome_row.bind(row))


func _add_outcome_line(
	parent: VBoxContainer,
	controls: Dictionary,
	errors: Dictionary,
	key: String,
	caption: String,
	value: String
) -> void:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_child(_label(caption, "EyebrowLabel"))
	var control: LineEdit = LineEdit.new()
	control.text = value
	group.add_child(control)
	var error: Label = _label("", "DangerLabel")
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	group.add_child(error)
	parent.add_child(group)
	controls[key] = control
	errors[key] = error


func _remove_outcome_row(row: Dictionary) -> void:
	var index: int = _outcome_rows.find(row)
	if index < 0:
		return
	var panel: PanelContainer = row.get("panel") as PanelContainer
	_outcome_rows.remove_at(index)
	_outcomes_container.remove_child(panel)
	panel.queue_free()
	_refresh_outcome_labels()


func _refresh_outcome_labels() -> void:
	for index: int in _outcome_rows.size():
		var row: Dictionary = _outcome_rows[index]
		var heading: Label = row.get("heading") as Label
		var remove: Button = row.get("remove") as Button
		heading.text = "OUTCOME %d" % (index + 1)
		remove.disabled = false
	_outcome_requirement.text = "Minimum 2 outcomes (runtime requirement). Current: %d." % _outcome_rows.size()
	_outcome_requirement.theme_type_variation = (
		"DangerLabel" if _outcome_rows.size() < 2 else "MutedLabel"
	)


func _collect_outcomes() -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	for row: Dictionary in _outcome_rows:
		var controls: Dictionary = row.get("controls", {})
		var faction: OptionButton = controls.get("faction_id") as OptionButton
		var delta: SpinBox = controls.get("reputation_delta") as SpinBox
		outcomes.append({
			"id": (controls.get("id") as LineEdit).text.strip_edges(),
			"label": (controls.get("label") as LineEdit).text.strip_edges(),
			"faction_id": _selected_option_value(faction),
			"reputation_delta": delta.value,
			"cause": (controls.get("cause") as LineEdit).text.strip_edges(),
			"readback": (controls.get("readback") as LineEdit).text.strip_edges(),
		})
	return outcomes


func _collect_campaign() -> Dictionary:
	var campaign: Dictionary = _campaign_data.duplicate(true)
	campaign["id"] = _line_control("campaign.id").text.strip_edges()
	campaign["title"] = _line_control("campaign.title").text.strip_edges()
	var entry_location: String = _selected_option_value(_entry_location_picker)
	campaign["entry_location"] = entry_location
	var locations: Array = campaign.get("locations", [])
	if not locations.has(entry_location) and not entry_location.is_empty():
		locations.append(entry_location)
	campaign["locations"] = locations
	return campaign


func _validate_current() -> void:
	_clear_registration_confirmation()
	_store_selected_quest()
	var campaign: Dictionary = _collect_campaign()
	var result_value: Variant = _editor.call("validate_draft", campaign, _quests)
	if not result_value is Dictionary:
		return
	var result: Dictionary = result_value as Dictionary
	_render_errors(result.get("errors", []))
	if (result.get("errors", []) as Array).is_empty():
		_set_status("VALID · CampaignQuestLoader accepts this draft.", "PositiveLabel")
	else:
		_set_status("NOT VALID · Fix the loader errors shown inline.", "DangerLabel")


func _save_current(
	force: bool = false, authorized_conflict_identities: Array[String] = []
) -> void:
	_clear_registration_confirmation()
	_store_selected_quest()
	var campaign: Dictionary = _collect_campaign()
	var result_value: Variant = _editor.call(
		"save_campaign", campaign, _quests, force, authorized_conflict_identities
	)
	if not result_value is Dictionary:
		return
	var result: Dictionary = result_value as Dictionary
	_render_errors(result.get("errors", []))
	_render_registered()
	if not (result.get("registration_conflicts", []) as Array).is_empty():
		if bool(result.get("saved", false)):
			_campaign_data = campaign
			_refresh_campaign_picker(str(campaign.get("id", "")))
		_show_registration_conflict(result, &"save", true)
		return
	if bool(result.get("saved", false)):
		_campaign_data = campaign
		_refresh_campaign_picker(str(campaign.get("id", "")))
		_set_status("SAVED · RELOADED THROUGH CAMPAIGNQUESTLOADER · REGISTERED", "PositiveLabel")
	else:
		_set_status("NOT SAVED · Loader errors must be resolved.", "DangerLabel")


func _reload_current_campaign(
	force: bool = false, authorized_conflict_identities: Array[String] = []
) -> void:
	_clear_registration_confirmation()
	var campaign_id: String = _line_control("campaign.id").text.strip_edges()
	if campaign_id.is_empty() and _campaign_picker.selected >= 0:
		campaign_id = str(_campaign_picker.get_selected_metadata())
	var result_value: Variant = _editor.call(
		"reload_campaign", campaign_id, force, authorized_conflict_identities
	)
	if not result_value is Dictionary:
		return
	var result: Dictionary = result_value as Dictionary
	_render_errors(result.get("errors", []))
	_render_registered()
	if not (result.get("registration_conflicts", []) as Array).is_empty():
		_show_registration_conflict(result, &"reload", false)
		return
	if (result.get("errors", []) as Array).is_empty():
		_load_campaign(campaign_id)
		_set_status("RELOADED THROUGH CAMPAIGNQUESTLOADER · REGISTERED", "PositiveLabel")
	else:
		_set_status("RELOAD REJECTED · Loader errors are shown inline.", "DangerLabel")


func _show_registration_conflict(
	result: Dictionary, action: StringName, saved_to_disk: bool
) -> void:
	var names: PackedStringArray = []
	var conflicts: Array = result.get("registration_conflicts", [])
	for conflict_value: Variant in conflicts:
		if not conflict_value is Dictionary:
			continue
		var conflict: Dictionary = conflict_value as Dictionary
		var identity: String = str(conflict.get("identity", "unknown quest"))
		var name: String = str(conflict.get("name", identity))
		var state: String = str(conflict.get("state", "live"))
		names.append("%s (%s, %s)" % [name, identity, state])
		_pending_force_conflict_identities.append(identity)
	_pending_force_action = action
	_force_registration_button.visible = true
	var prefix: String = "SAVED TO DISK · " if saved_to_disk else ""
	_set_status(
		prefix + "REGISTRATION REFUSED · Would reset live progress for: %s"
		% ", ".join(names),
		"DangerLabel"
	)


func _confirm_force_registration() -> void:
	var action: StringName = _pending_force_action
	var authorized_conflict_identities: Array[String] = (
		_pending_force_conflict_identities.duplicate()
	)
	_clear_registration_confirmation()
	if action == &"save":
		_save_current(true, authorized_conflict_identities)
	elif action == &"reload":
		_reload_current_campaign(true, authorized_conflict_identities)


func _clear_registration_confirmation() -> void:
	_pending_force_action = &""
	_pending_force_conflict_identities.clear()
	if _force_registration_button != null:
		_force_registration_button.visible = false


func _render_errors(error_values: Variant) -> void:
	_clear_errors()
	if not error_values is Array:
		return
	var errors: Array = error_values as Array
	if errors.is_empty():
		_validation_container.add_child(_label("No loader errors.", "PositiveLabel"))
		return
	var selected_quest_id: String = ""
	if _selected_quest_index >= 0 and _selected_quest_index < _quests.size():
		selected_quest_id = str(_quests[_selected_quest_index].get("quest_id", ""))
	for error_value: Variant in errors:
		if not error_value is Dictionary:
			continue
		var error: Dictionary = error_value as Dictionary
		var file_path: String = str(error.get("file", ""))
		var field: String = str(error.get("field", "$"))
		var expected: String = str(error.get("expected", ""))
		var message: String = str(error.get("message", ""))
		var rendered: String = "%s · %s · expected %s · %s" % [
			file_path, field, expected, message,
		]
		var row_label: Label = _label(rendered, "DangerLabel")
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_validation_container.add_child(row_label)
		if file_path.ends_with("campaign.json"):
			_set_inline_error("campaign." + field, expected, message)
		elif selected_quest_id.is_empty() or file_path.ends_with("/%s.json" % selected_quest_id):
			_set_quest_inline_error(field, expected, message)


func _set_inline_error(key: String, expected: String, message: String) -> void:
	var label: Label = _field_errors.get(key) as Label
	if label != null:
		label.text = "%s · Expected %s" % [message, expected]


func _set_quest_inline_error(field: String, expected: String, message: String) -> void:
	if field.begins_with("outcomes["):
		var close_index: int = field.find("]")
		if close_index < 0:
			return
		var index_text: String = field.substr(9, close_index - 9)
		if not index_text.is_valid_int():
			return
		var outcome_index: int = index_text.to_int()
		var child_field: String = field.substr(close_index + 1).trim_prefix(".")
		if outcome_index >= 0 and outcome_index < _outcome_rows.size():
			var row_errors: Dictionary = _outcome_rows[outcome_index].get("errors", {})
			var label: Label = row_errors.get(child_field) as Label
			if label != null:
				label.text = "%s · Expected %s" % [message, expected]
		return
	_set_inline_error(field, expected, message)


func _clear_errors() -> void:
	for label_value: Variant in _field_errors.values():
		var label: Label = label_value as Label
		if label != null:
			label.text = ""
	for row: Dictionary in _outcome_rows:
		var row_errors: Dictionary = row.get("errors", {})
		for label_value: Variant in row_errors.values():
			var label: Label = label_value as Label
			if label != null:
				label.text = ""
	_clear_children(_validation_container)


func _render_registered() -> void:
	var rows_value: Variant = _editor.call("registered_view")
	if not rows_value is Array or (rows_value as Array).is_empty():
		_registered_label.text = "Nothing is currently registered from a loader round trip."
		return
	var lines: PackedStringArray = []
	for row_value: Variant in rows_value as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		lines.append("%s · runtime %d · %s · %d outcomes" % [
			str(row.get("identity", "")),
			int(row.get("runtime_id", -1)),
			str(row.get("name", "")),
			int(row.get("outcome_count", 0)),
		])
	_registered_label.text = "\n".join(lines)


func _populate_option(control: OptionButton, values: Array[String], selected_value: String) -> void:
	control.clear()
	var options: Array[String] = values.duplicate()
	if not selected_value.is_empty() and not options.has(selected_value):
		options.push_front(selected_value)
	for value: String in options:
		control.add_item(value)
		control.set_item_metadata(control.item_count - 1, value)
		if value == selected_value:
			control.select(control.item_count - 1)


func _selected_option_value(control: OptionButton) -> String:
	if control == null or control.item_count == 0 or control.selected < 0:
		return ""
	return str(control.get_selected_metadata())


func _source_values(method_name: StringName) -> Array[String]:
	var result: Array[String] = []
	if _editor == null:
		return result
	var values: Variant = _editor.call(method_name)
	if values is Array:
		for value: Variant in values:
			result.append(str(value))
	return result


func _line_control(key: String) -> LineEdit:
	return _field_controls.get(key) as LineEdit


func _set_status(text: String, variation: String) -> void:
	_status.text = text
	_status.theme_type_variation = variation


static func _empty_outcome() -> Dictionary:
	return {
		"id": "",
		"label": "",
		"faction_id": "",
		"reputation_delta": 0.0,
		"cause": "",
		"readback": "",
	}


static func _first_value(values: Array[String]) -> String:
	return values[0] if not values.is_empty() else ""


static func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


static func _label(text: String, variation: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
