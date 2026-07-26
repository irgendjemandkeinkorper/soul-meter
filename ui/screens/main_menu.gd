extends Screen
## The entry scene. New Game loads the field room; Settings stacks over this via UIManager.

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = DS.STONE_0  # --bg-app; the vignette/grain pass comes with the notch nine-patches
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
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
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	# Buttons send flow events — they never name a destination scene (see GameFlow).
	_menu_button(vbox, "New Game", func() -> void: GameFlow.send_event("new_game"))
	_menu_button(vbox, "Continue", func() -> void: GameFlow.send_event("new_game"))  # no saves yet
	_menu_button(vbox, "Settings", func() -> void: UIManager.open(load("res://ui/screens/settings.tscn")))
	_menu_button(vbox, "Quit", func() -> void: get_tree().quit())
