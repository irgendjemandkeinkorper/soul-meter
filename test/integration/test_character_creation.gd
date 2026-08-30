extends GdUnitTestSuite
## Integration coverage for the shared player/recruit Form 7 wizard. The player test
## still enters through the real main menu and GameFlow state; the recruit test uses
## the same scene in its tavern-owned mode.

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_custom_recruits: Array[PartyMember]


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_custom_recruits = GameState.custom_recruits.duplicate()


func after_test() -> void:
	GameState.party = _original_party
	GameState.flags = _original_flags
	GameState.custom_recruits = _original_custom_recruits
	UIManager.close_all()


func test_wizard_gates_each_ratified_step_and_supports_back_and_summary_jumps() -> void:
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame

	assert_int(screen._step_pages.size()).is_equal(7)
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_ANCESTRY)
	assert_bool(screen._next_btn.disabled).is_true()
	screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_ANCESTRY)

	screen._on_ancestry_pressed("vael")
	assert_bool(screen._next_btn.disabled).is_false()
	screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_CALLING)

	# Calling remains optional, preserving the old ACCEPT rules.
	screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_ELEMENTS)
	screen._major_element = "suul"
	screen._minor_element = "daar"
	screen._refresh_summary_and_gate()
	assert_bool(screen._next_btn.disabled).is_true()
	screen._minor_element = "bloei"
	screen._refresh_summary_and_gate()
	assert_bool(screen._next_btn.disabled).is_false()
	screen._on_next()

	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_ATTRIBUTES)
	assert_bool(screen._next_btn.disabled).is_true()
	_set_valid_attributes(screen)
	assert_bool(screen._next_btn.disabled).is_false()
	screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_SKILLS)
	assert_str((screen._skill_pct_lbls["athletics"] as Label).text).contains("%")

	screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_IDENTITY)
	assert_bool(screen._next_btn.disabled).is_true()
	screen._name_edit.text = "Sera"
	screen._name_edit.text_changed.emit("Sera")
	assert_bool(screen._next_btn.disabled).is_false()
	screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_SUMMARY)
	assert_bool(screen._accept_btn.visible).is_true()
	assert_bool(screen._accept_btn.disabled).is_false()

	screen._show_step(CharacterCreationScreen.STEP_CALLING)
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_CALLING)
	screen._on_back()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_ANCESTRY)

	screen.queue_free()


func test_player_chargen_boots_from_main_menu_and_writes_every_existing_field() -> void:
	var runner := scene_runner("res://ui/screens/main_menu.tscn")
	await runner.simulate_frames(3)

	var new_game_btn := _find_button_with_text(runner.scene(), "New Game")
	assert_object(new_game_btn).is_not_null()
	new_game_btn.pressed.emit()
	await runner.simulate_frames(1)
	new_game_btn.pressed.emit()
	await runner.simulate_frames(3)

	var screen := _find_chargen_screen()
	assert_object(screen).is_not_null()
	assert_bool(screen.flow_owned).is_true()
	assert_bool(screen._back_btn.disabled).is_true()
	_fill_out_valid_build(screen, "Sera", "the unbowed")
	_drive_to_summary(screen)
	assert_bool(screen._accept_btn.disabled).is_false()

	screen._on_accept()
	await runner.simulate_frames(3)

	assert_bool(GameState.has_created_character()).is_true()
	var member: PartyMember = GameState.party[0]
	_assert_member_matches_picks(member, "Sera", "the unbowed")
	assert_str(member.id).is_equal(GameState.PROTAGONIST_ID)


func test_recruit_mode_uses_the_same_steps_and_only_writes_the_custom_roster() -> void:
	var lead_before: PartyMember = GameState.protagonist()
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	screen.mode = CharacterCreationScreen.Mode.RECRUIT
	add_child(screen)
	await get_tree().process_frame

	assert_bool(screen.flow_owned).is_false()
	assert_bool(screen._back_btn.disabled).is_false()
	_fill_out_valid_build(screen, "Vann", "the quiet")
	_drive_to_summary(screen)

	var emitted: Array[PartyMember] = []
	screen.recruit_created.connect(func(member: PartyMember) -> void: emitted.append(member))
	screen._on_accept()
	await get_tree().process_frame

	assert_int(emitted.size()).is_equal(1)
	_assert_member_matches_picks(emitted[0], "Vann", "the quiet")
	assert_bool(GameState.custom_recruits.any(
		func(member: PartyMember) -> bool: return member.display_name == "Vann"
	)).is_true()
	assert_object(GameState.protagonist()).is_equal(lead_before)

	screen.queue_free()


func _fill_out_valid_build(screen: CharacterCreationScreen, name: String, epithet: String) -> void:
	screen._on_ancestry_pressed("vael")
	screen._on_discipline_selected(1)
	screen._on_patron_selected(2)
	screen._on_background_selected(1)
	screen._major_element = "suul"
	screen._minor_element = "bloei"
	screen._name_edit.text = name
	screen._name_edit.text_changed.emit(name)
	screen._epithet_edit.text = epithet
	screen._epithet_edit.text_changed.emit(epithet)
	screen._on_flaw_changed("Will not leave a debt uncounted")
	screen._on_likeness_pressed("crowd-guard-a", screen._likeness_buttons[1])
	_set_valid_attributes(screen)


func _set_valid_attributes(screen: CharacterCreationScreen) -> void:
	screen._attributes = {
		"forge": 5, "edge": 5, "anchor": 4, "spark": 2, "pitch": 2, "voice": 2,
	}
	screen._refresh_all()


func _drive_to_summary(screen: CharacterCreationScreen) -> void:
	for index: int in CharacterCreationScreen.STEP_SUMMARY:
		screen._show_step(index)
		assert_bool(screen._next_btn.disabled).is_false()
		screen._on_next()
	assert_int(screen._step_index).is_equal(CharacterCreationScreen.STEP_SUMMARY)


func _assert_member_matches_picks(member: PartyMember, name: String, epithet: String) -> void:
	assert_str(member.display_name).is_equal(name)
	assert_str(member.epithet).is_equal(epithet)
	assert_str(member.race).is_equal("Vael")
	assert_str(member.discipline).is_equal("terrashaper")
	assert_str(member.patron).is_equal("ironbrand")
	assert_str(member.background).is_equal("verlossen-miner")
	assert_str(member.major_element).is_equal("suul")
	assert_str(member.minor_element).is_equal("bloei")
	assert_str(member.flaw).is_equal("Will not leave a debt uncounted")
	assert_str(member.starting_mastery).is_equal("Root Note of choice")
	assert_int(member.attributes["forge"]).is_equal(5)
	assert_str(member.skill_tiers["athletics"]).is_equal("trained")
	assert_object(member.portrait).is_not_null()
	assert_str(member.portrait.resource_path).contains("crowd-guard-a")


func _find_chargen_screen() -> CharacterCreationScreen:
	for child: Node in UIManager.get_children():
		if child is CharacterCreationScreen:
			return child as CharacterCreationScreen
	return null


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null
