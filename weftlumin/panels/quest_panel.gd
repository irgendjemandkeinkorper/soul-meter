class_name WeftluminQuestPanel
extends SoulMeterToolPanel
## Quest editor tab (§4.8): the quest editor model behind the panel contract — validate in
## memory, transactional write, reload through the same loader, register, and refuse to reset
## live progress without explicit authorisation. All of that is the model's.
##
## The draft is edited as the exact JSON documents CampaignQuestLoader consumes (`campaign.json`
## and the quest files), so the panel can express every field the package format carries.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/quest_editor.gd")

var campaign_picker: OptionButton = null
var campaign_editor: TextEdit = null
var quests_editor: TextEdit = null
var errors_label: Label = null
var registered_label: Label = null
var authorize_button: Button = null
var last_result: Dictionary = {}
var _pending_action: StringName = &""
var _pending_identities: Array[String] = []


func _init() -> void:
	title = "Quest editor"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


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
	bar.add_child(_button("Validate", "Validate", validate))
	bar.add_child(_button("Save", "Save", func() -> void: save()))
	bar.add_child(_button("Reload", "Reload", func() -> void: reload()))
	authorize_button = _button("Authorize reset of listed live quests", "Authorize", authorize)
	authorize_button.visible = false
	bar.add_child(authorize_button)
	var editors := _row()
	content.add_child(editors)
	campaign_editor = _text_box("CampaignJson", true)
	campaign_editor.placeholder_text = "campaign.json"
	editors.add_child(campaign_editor)
	quests_editor = _text_box("QuestsJson", true)
	quests_editor.placeholder_text = "[ quest documents ]"
	editors.add_child(quests_editor)
	errors_label = _label("", &"EditorLabel", true)
	errors_label.name = "Errors"
	content.add_child(errors_label)
	registered_label = _label("", &"EditorLabel", true)
	registered_label.name = "Registered"
	content.add_child(registered_label)


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
	campaign_editor.text = "{}"
	quests_editor.text = "[]"
	errors_label.text = ""
	_set_status("NEW CAMPAIGN DRAFT · Add quests, then validate and save.")


func load_campaign(campaign_id: String) -> void:
	_clear_authorization()
	var draft: Dictionary = model.call("campaign_draft", campaign_id)
	if draft.is_empty():
		_set_status("No campaign '%s'." % campaign_id)
		return
	campaign_editor.text = JSON.stringify(draft.get("campaign", {}), "  ")
	quests_editor.text = JSON.stringify(draft.get("quests", []), "  ")
	_render_errors(draft.get("errors", []))
	_set_status("Loaded %s." % campaign_id)


## The draft as `{valid, campaign, quests}` or `{valid: false, error}`.
func current_draft() -> Dictionary:
	var campaign: Variant = JSON.parse_string(campaign_editor.text)
	if not campaign is Dictionary:
		return {"valid": false, "error": "campaign.json must be a JSON object."}
	var quest_values: Variant = JSON.parse_string(quests_editor.text)
	if not quest_values is Array:
		return {"valid": false, "error": "Quests must be a JSON array of quest objects."}
	var quests: Array[Dictionary] = []
	for quest_value: Variant in quest_values:
		if not quest_value is Dictionary:
			return {"valid": false, "error": "Every quest must be a JSON object."}
		quests.append(quest_value as Dictionary)
	return {"valid": true, "campaign": campaign, "quests": quests}


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
		_refresh_campaigns(str((draft["campaign"] as Dictionary).get("id", "")))
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
	var lines: PackedStringArray = []
	for error: Dictionary in errors:
		lines.append("%s · %s · expected %s · %s" % [
			str(error.get("file", "")), str(error.get("field", "$")),
			str(error.get("expected", "")), str(error.get("message", "")),
		])
	errors_label.text = "No loader errors." if lines.is_empty() else "\n".join(lines)


func _render_registered() -> void:
	var rows: Array = model.call("registered_view")
	var lines: PackedStringArray = []
	for row: Dictionary in rows:
		lines.append("%s — %s" % [str(row.get("identity", "")), str(row.get("name", ""))])
	registered_label.text = "REGISTERED: %s" % ("none" if lines.is_empty() else ", ".join(lines))
