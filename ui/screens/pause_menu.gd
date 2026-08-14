extends Screen
## Opened by Esc during gameplay. Routes to the sub-screens; the tree stays paused until closed.

const SAVE_FAILURE_MESSAGE := (
	"Could not save your progress. Please check your available storage and try again."
)

var _save_status: Label
var _save_button: Button


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
	var overwrite_armed := false
	_save_button = _menu_button(
		vbox,
		"Manual Save",
		func() -> void:
			if SaveGame.has_save() and not overwrite_armed:
				overwrite_armed = true
				_save_button.text = "Confirm Overwrite"
				_save_status.text = "The current chapter slot will be replaced."
				return
			if SaveGame.save():
				_save_status.text = "Chapter saved."
			else:
				_show_save_failure()
			overwrite_armed = false
			_save_button.text = "Manual Save"
	)
	_save_button.name = "ManualSaveButton"
	_save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_save_status)
	SaveGame.save_failed.connect(_on_save_failed)
	_menu_button(
		vbox, "Settings", func() -> void: UIManager.open(load("res://ui/screens/settings.tscn"))
	)
	_menu_button(vbox, "Main Menu", func() -> void: GameFlow.send_event("to_main_menu"))
	_menu_button(vbox, "Quit", func() -> void: get_tree().quit())


func _on_save_failed(_message: String) -> void:
	_show_save_failure()


func _show_save_failure() -> void:
	if is_instance_valid(_save_status):
		_save_status.text = SAVE_FAILURE_MESSAGE
