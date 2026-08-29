extends Screen
## The entry scene. New Game loads the field room; Settings stacks over this via UIManager.

const REFLECTION_SHADER := preload("res://ui/screens/main_menu_reflection.gdshader")

var _overwrite_armed := false
var _new_game_button: Button


func _build() -> void:
	_configure_backdrop()

	var safe_margin := MarginContainer.new()
	safe_margin.theme_type_variation = "MainMenuSafeMargin"
	safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_margin.add_child(center)

	var mirror_frame := PanelContainer.new()
	mirror_frame.theme_type_variation = "MainMenuMirrorFrame"
	mirror_frame.custom_minimum_size.x = DS.RAIL_W + DS.SPACE_9 * 4
	center.add_child(mirror_frame)

	var vbox := VBoxContainer.new()
	vbox.theme_type_variation = "MainMenuColumn"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	mirror_frame.add_child(vbox)

	_build_title_treatment(vbox)
	vbox.add_child(HSeparator.new())

	var button_well := PanelContainer.new()
	button_well.theme_type_variation = "MainMenuButtonWell"
	vbox.add_child(button_well)

	var button_column := VBoxContainer.new()
	button_column.theme_type_variation = "MainMenuColumn"
	button_column.alignment = BoxContainer.ALIGNMENT_CENTER
	button_well.add_child(button_column)

	# Buttons send flow events — they never name a destination scene (see GameFlow).
	_overwrite_armed = false
	_new_game_button = _main_menu_button(
		button_column,
		"New Game",
		_on_new_game_pressed,
		"MainMenuPrimaryButton",
	)
	var continue_button := _main_menu_button(
		button_column,
		"Continue",
		func() -> void:
			if SaveGame.load_save():
				GameFlow.send_event("new_game")
	)
	continue_button.disabled = not SaveGame.has_save()
	var any_manual_save := false
	for slot: int in range(1, SaveGame.MANUAL_SLOT_COUNT + 1):
		any_manual_save = any_manual_save or SaveGame.has_manual_save(slot)
	var load_button := _main_menu_button(
		button_column, "Load Game", func() -> void: UIManager.open(UIManager.LOAD_GAME)
	)
	load_button.name = "LoadGameButton"
	load_button.disabled = not (SaveGame.has_save() or any_manual_save)
	_main_menu_button(
		button_column, "Settings", func() -> void: UIManager.open(UIManager.SETTINGS)
	)
	_main_menu_button(button_column, "Quit", func() -> void: get_tree().quit())


func _configure_backdrop() -> void:
	var backdrop := get_node_or_null("Visuals/ObsidianMirror") as ColorRect
	if backdrop == null:
		return
	var source_material := backdrop.material as ShaderMaterial
	if source_material == null:
		return
	var backdrop_material := source_material.duplicate() as ShaderMaterial
	backdrop.material = backdrop_material
	backdrop_material.set_shader_parameter("void_color", DS.VOID_0)
	backdrop_material.set_shader_parameter("stone_color", DS.STONE_1)
	backdrop_material.set_shader_parameter("iron_color", DS.IRON_1)
	backdrop_material.set_shader_parameter("bronze_color", DS.BRONZE_3)
	backdrop_material.set_shader_parameter("mote_color", DS.MOTE_3)
	backdrop_material.set_shader_parameter("motion_scale", _motion_scale())


func _build_title_treatment(parent: VBoxContainer) -> void:
	var title_column := VBoxContainer.new()
	title_column.theme_type_variation = "MainMenuTitleColumn"
	title_column.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(title_column)

	# Wordmark treatment (no mark supplied): the name in Cinzel, uppercase, tracked.
	var title := Label.new()
	title.name = "Title"
	title.text = "SOUL METER"
	title.theme_type_variation = "HeroLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_column.add_child(title)

	var reflection_host := Control.new()
	reflection_host.name = "TitleReflection"
	reflection_host.custom_minimum_size.y = DS.FS_900
	reflection_host.clip_contents = true
	reflection_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_column.add_child(reflection_host)

	var reflected_title := Label.new()
	reflected_title.text = title.text
	reflected_title.theme_type_variation = "HeroLabel"
	reflected_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reflected_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reflected_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	reflected_title.offset_top = DS.FS_900
	reflected_title.offset_bottom = DS.FS_900 + DS.FS_1000
	reflected_title.scale = Vector2(1.0, -0.68)
	var reflection_material := ShaderMaterial.new()
	reflection_material.shader = REFLECTION_SHADER
	var reflection_tint := DS.BRONZE_4
	reflection_tint.a = 0.28
	reflection_material.set_shader_parameter("reflection_tint", reflection_tint)
	reflection_material.set_shader_parameter("reflection_height", float(DS.FS_1000))
	reflection_material.set_shader_parameter("motion_scale", _motion_scale())
	reflected_title.material = reflection_material
	reflection_host.add_child(reflected_title)

	var sub := Label.new()
	sub.text = "The Loom is fraying. The ledger is exact."
	sub.theme_type_variation = "QuoteLabel"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_column.add_child(sub)


func _main_menu_button(
	box: VBoxContainer,
	text: String,
	callback: Callable,
	type_variation: String = "MainMenuButton",
) -> Button:
	var button := _menu_button(box, text, callback)
	button.custom_minimum_size = Vector2(DS.RAIL_W, DS.CONTROL_H_LG)
	button.theme_type_variation = type_variation
	return button


func _motion_scale() -> float:
	return 0.0 if bool(GameState.get_setting("accessibility", "reduced_motion", false)) else 1.0


func _on_new_game_pressed() -> void:
	if SaveGame.has_save() and not _overwrite_armed:
		_overwrite_armed = true
		_new_game_button.text = "Confirm New Game — Overwrite Save"
		_new_game_button.theme_type_variation = "DangerButton"
		return
	SaveGame.new_game()
	GameFlow.send_event("start_chargen")
