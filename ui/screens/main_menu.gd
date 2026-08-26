extends Screen
## The entry scene. New Game loads the field room; Settings stacks over this via UIManager.

var _overwrite_armed := false
var _new_game_button: Button


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = DS.STONE_0  # --bg-app; the vignette/grain pass comes with the notch nine-patches
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.theme_type_variation = "MainMenuColumn"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# Wordmark treatment (no mark supplied): the name in Cinzel, uppercase, tracked.
	var title := Label.new()
	title.text = "SOUL METER"
	title.theme_type_variation = "HeroLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "The Loom is fraying. The ledger is exact."
	sub.theme_type_variation = "QuoteLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, DS.SPACE_8)
	vbox.add_child(spacer)

	# Buttons send flow events — they never name a destination scene (see GameFlow).
	_overwrite_armed = false
	_new_game_button = _menu_button(
		vbox,
		"New Game",
		_on_new_game_pressed
	)
	var continue_button := _menu_button(
		vbox,
		"Continue",
		func() -> void:
			if SaveGame.load_save():
				GameFlow.send_event("new_game")
	)
	continue_button.disabled = not SaveGame.has_save()
	var any_manual_save := false
	for slot in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		any_manual_save = any_manual_save or SaveGame.has_manual_save(slot)
	var load_button := _menu_button(
		vbox, "Load Game", func() -> void: UIManager.open(UIManager.LOAD_GAME)
	)
	load_button.name = "LoadGameButton"
	load_button.disabled = not (SaveGame.has_save() or any_manual_save)
	_menu_button(
		vbox, "Settings", func() -> void: UIManager.open(UIManager.SETTINGS)
	)
	_menu_button(vbox, "Quit", func() -> void: get_tree().quit())


func _on_new_game_pressed() -> void:
	if SaveGame.has_save() and not _overwrite_armed:
		_overwrite_armed = true
		_new_game_button.text = "Confirm New Game — Overwrite Save"
		_new_game_button.theme_type_variation = "DangerButton"
		return
	SaveGame.new_game()
	GameFlow.send_event("start_chargen")
