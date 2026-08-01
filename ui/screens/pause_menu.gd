extends Screen
## Opened by Esc during gameplay. Routes to the sub-screens; the tree stays paused until closed.


func _build() -> void:
	var vbox := _make_window("Paused", Vector2(360, 120))
	# Flow buttons send chart events; overlay buttons stack views above this screen.
	_menu_button(vbox, "Resume", func() -> void: GameFlow.send_event("resume"))
	_menu_button(
		vbox, "Inventory", func() -> void: UIManager.open(load("res://ui/screens/inventory.tscn"))
	)
	_menu_button(vbox, "Party", func() -> void: UIManager.open(load("res://ui/screens/party.tscn")))
	_menu_button(vbox, "Journal", func() -> void: UIManager.open(UIManager.JOURNAL))
	var save_status := Label.new()
	var overwrite_armed := false
	var save_button: Button
	save_button = _menu_button(
		vbox,
		"Manual Save",
		func() -> void:
			if SaveGame.has_save() and not overwrite_armed:
				overwrite_armed = true
				save_button.text = "Confirm Overwrite"
				save_status.text = "The current chapter slot will be replaced."
				return
			save_status.text = "Chapter saved." if SaveGame.save() else "Save failed."
			overwrite_armed = false
			save_button.text = "Manual Save"
	)
	save_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(save_status)
	_menu_button(
		vbox, "Settings", func() -> void: UIManager.open(load("res://ui/screens/settings.tscn"))
	)
	_menu_button(vbox, "Main Menu", func() -> void: GameFlow.send_event("to_main_menu"))
	_menu_button(vbox, "Quit", func() -> void: get_tree().quit())
