extends Screen
## Opened by Esc during gameplay. Routes to the sub-screens; the tree stays paused until closed.

const SAVE_FAILURE_MESSAGE := (
	"Could not save your progress. Please check your available storage and try again."
)

var _save_status: Label
var _slot_buttons: Array[Button] = []
var _armed_slot := 0


func _build() -> void:
	var vbox := _make_shell_window("Paused")
	# Flow buttons send chart events; overlay buttons stack views above this screen.
	_menu_button(vbox, "Resume", func() -> void: GameFlow.send_event("resume"))
	_menu_button(
		vbox, "Inventory", func() -> void: UIManager.open(load("res://ui/screens/inventory.tscn"))
	)
	_menu_button(vbox, "Party", func() -> void: UIManager.open(load("res://ui/screens/party.tscn")))
	_menu_button(vbox, "Journal", func() -> void: UIManager.open(UIManager.JOURNAL))
	var region_map_button := _menu_button(
		vbox, "Region Map", func() -> void: UIManager.open(UIManager.REGION_MAP)
	)
	region_map_button.name = "RegionMapButton"
	_save_status = Label.new()
	_save_status.name = "SaveStatus"
	_save_status.theme_type_variation = "EyebrowLabel"
	_save_status.focus_mode = Control.FOCUS_NONE
	_save_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# FR-905: three player-facing manual slots, each with its own overwrite confirm.
	_slot_buttons.clear()
	_armed_slot = 0
	for slot in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		var button := _menu_button(vbox, _slot_label(slot), _on_slot_pressed.bind(slot))
		button.name = "ManualSaveSlot%d" % slot
		_slot_buttons.append(button)
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_save_status)
	SaveGame.save_failed.connect(_on_save_failed)
	_menu_button(
		vbox, "Settings", func() -> void: UIManager.open(UIManager.SETTINGS)
	)
	_menu_button(vbox, "Main Menu", func() -> void: GameFlow.send_event("to_main_menu"))
	_menu_button(vbox, "Quit", func() -> void: get_tree().quit())


func _on_slot_pressed(slot: int) -> void:
	if SaveGame.has_manual_save(slot) and _armed_slot != slot:
		_disarm()
		_armed_slot = slot
		_slot_buttons[slot - 1].text = "Confirm Overwrite — Slot %d" % slot
		_save_status.text = "Slot %d will be replaced." % slot
		return
	if SaveGame.save_to_slot(slot):
		_save_status.text = "Saved to slot %d." % slot
	else:
		_show_save_failure()
	_disarm()


func _disarm() -> void:
	_armed_slot = 0
	for slot in range(1, _slot_buttons.size() + 1):
		_slot_buttons[slot - 1].text = _slot_label(slot)


func _slot_label(slot: int) -> String:
	var summary := SaveGame.manual_slot_summary(slot)
	if not bool(summary.get("exists", false)):
		return "Save — Slot %d (empty)" % slot
	var location_id := str(summary.get("location_id", ""))
	var place := location_id.replace("-", " ").capitalize() if not location_id.is_empty() else "Chapter save"
	var minutes := int(summary.get("elapsed_seconds", 0)) / 60
	return "Save — Slot %d (%s · %dm)" % [slot, place, minutes]


func _on_save_failed(_message: String) -> void:
	_show_save_failure()


func _show_save_failure() -> void:
	if is_instance_valid(_save_status):
		_save_status.text = SAVE_FAILURE_MESSAGE
