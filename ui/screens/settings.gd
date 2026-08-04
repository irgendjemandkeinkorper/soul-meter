extends Screen
## Display + Audio settings. Applies live and persists to user://settings.cfg via GameState.

func _build() -> void:
	var vbox := _make_window("Settings", Vector2(560, 500))

	vbox.add_child(_section("Display"))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fs.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(fs)

	vbox.add_child(_section("Accessibility"))
	var reduced_motion := CheckButton.new()
	reduced_motion.name = "ReducedMotion"
	reduced_motion.text = "Reduced motion"
	reduced_motion.tooltip_text = (
		"Keeps combat cues and numbers while removing shake, travel, and squash motion."
	)
	reduced_motion.button_pressed = bool(
		GameState.get_setting("accessibility", "reduced_motion", false)
	)
	reduced_motion.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reduced_motion.toggled.connect(_on_reduced_motion_toggled)
	vbox.add_child(reduced_motion)

	vbox.add_child(_section("Audio"))
	for bus: StringName in GameState.AUDIO_BUSES:
		vbox.add_child(_volume_row(bus))

	vbox.add_child(_section("Language"))
	var locale := OptionButton.new()
	locale.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	locale.custom_minimum_size = Vector2(220, 36)
	locale.add_item("English", 0)
	locale.add_item("Español", 1)
	locale.select(GameState.SUPPORTED_LOCALES.find(GameState.get_locale()))
	locale.item_selected.connect(
		func(index: int) -> void:
			GameState.set_locale(GameState.SUPPORTED_LOCALES[index])
	)
	vbox.add_child(locale)

	_add_back_button(vbox)


func _on_fullscreen_toggled(on: bool) -> void:
	GameState.apply_fullscreen(on)
	GameState.set_setting("display", "fullscreen", on)


func _on_reduced_motion_toggled(enabled: bool) -> void:
	GameState.set_setting("accessibility", "reduced_motion", enabled)
	Juicee.accessibility.reduced_motion = enabled


func _volume_row(bus: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = String(bus)
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = GameState.get_bus_volume(bus)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		GameState.set_bus_volume(bus, v, true))
	row.add_child(slider)
	return row
