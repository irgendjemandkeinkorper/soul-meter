extends GdUnitTestSuite
## Explicit rendered QA for #285: the character sheet's Perks section with two picks recorded
## and the level-6 capstone pair on offer, one gated on Fame, at both supported sizes.

var _state_before: Dictionary
var _renown_before: Dictionary


func before_test() -> void:
	_state_before = GameState.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	Renown.from_dict({})
	var vex := PartyMember.new()
	vex.id = GameState.PROTAGONIST_ID
	vex.display_name = "Vex"
	vex.epithet = "the Unwritten"
	vex.race = "Human"
	vex.char_class = "Mirrorblade"
	vex.class_id = "mirrorblade"
	vex.level = 6
	vex.hp = 20
	vex.max_hp = 20
	for attribute: String in DramgidSchema.ATTRIBUTE_IDS:
		vex.attributes[attribute] = 3
	vex.major_element = "khash"
	vex.minor_element = "luth"
	vex.perk_ids = PackedStringArray(["mirrorblade-second-footing", "mirrorblade-reflection"])
	GameState.set_party([vex])
	Battle.controller = null
	Battle.ended = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))


func after_test() -> void:
	GameState.from_dict(_state_before)
	Renown.from_dict(_renown_before)


func test_perks_1080p() -> void:
	await _capture_perks(Vector2i(1920, 1080))


func test_perks_720p() -> void:
	await _capture_perks(Vector2i(1280, 720))


func _capture_perks(resolution: Vector2i) -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = resolution
	add_child(viewport)
	var screen := (load("res://ui/screens/character_sheet.tscn") as PackedScene).instantiate() as Screen
	viewport.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _settle()
	var scroll := screen.find_child("SheetColumn", true, false).get_parent() as ScrollContainer
	var column := screen.find_child("PerksColumn", true, false) as Control
	scroll.ensure_control_visible(column)
	await _settle()
	await _capture(viewport, "perks-%d" % resolution.x)
	for button_name: String in ["Perk_mirrorblade-known-edge", "Perk_mirrorblade-even-hand"]:
		var button := screen.find_child(button_name, true, false) as Button
		assert_bool(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(button.get_global_rect())).override_failure_message(
			"%s must fit the screen" % button_name
		).is_true()
	screen.free()


func _settle() -> void:
	await get_tree().create_timer(0.25).timeout
	for frame: int in 4:
		await get_tree().process_frame


func _capture(viewport: SubViewport, filename: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/%s.png" % filename)).is_equal(OK)
