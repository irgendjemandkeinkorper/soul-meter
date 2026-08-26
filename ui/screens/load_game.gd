extends Screen
## FR-905 load surface, stacked over the main menu: the autosave/continue slot
## plus the manual slots. A successful load routes through the same flow event
## the main menu's Continue button sends — never a direct scene change.

var _status: Label


func _build() -> void:
	var vbox := _make_shell_window("Load Game")
	var autosave_button := _menu_button(vbox, "Autosave — latest chapter save", _on_load_autosave)
	autosave_button.name = "LoadAutosaveButton"
	autosave_button.disabled = not SaveGame.has_save()
	for slot in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		var button := _menu_button(vbox, _slot_label(slot), _on_load_slot.bind(slot))
		button.name = "LoadSlot%d" % slot
		button.disabled = not SaveGame.has_manual_save(slot)
	_status = Label.new()
	_status.name = "LoadStatus"
	_status.theme_type_variation = "EyebrowLabel"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.focus_mode = Control.FOCUS_NONE
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_status)
	_add_back_button(vbox)


func _on_load_autosave() -> void:
	_start_loaded_game(SaveGame.load_save())


func _on_load_slot(slot: int) -> void:
	_start_loaded_game(SaveGame.load_slot(slot))


func _start_loaded_game(loaded: bool) -> void:
	if loaded:
		GameFlow.send_event("new_game")
	elif is_instance_valid(_status):
		_status.text = "That save could not be loaded."


func _slot_label(slot: int) -> String:
	var summary := SaveGame.manual_slot_summary(slot)
	if not bool(summary.get("exists", false)):
		return "Slot %d (empty)" % slot
	var location_id := str(summary.get("location_id", ""))
	var place := location_id.replace("-", " ").capitalize() if not location_id.is_empty() else "Chapter save"
	var minutes := int(summary.get("elapsed_seconds", 0)) / 60
	return "Slot %d — %s · %dm" % [slot, place, minutes]
