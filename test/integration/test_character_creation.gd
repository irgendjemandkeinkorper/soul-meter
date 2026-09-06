extends GdUnitTestSuite
## Integration coverage for the shared player/recruit Form 7 wizard on DRAMGID
## (docs/architecture-chargen-dramgid.md §7, §11). The player test still enters through
## the real main menu and GameFlow state; the recruit tests use the same scene in its
## tavern-owned mode. Everything drives the screen's PUBLIC API — never private members.

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_custom_recruits: Array[PartyMember]
var _original_skills: Dictionary


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_custom_recruits = GameState.custom_recruits.duplicate()
	_original_skills = GameState.skills.duplicate(true)


func after_test() -> void:
	GameState.party = _original_party
	GameState.flags = _original_flags
	GameState.custom_recruits = _original_custom_recruits
	GameState.skills = _original_skills
	UIManager.close_all()


func test_wizard_gates_each_leaf_in_canon_order_and_supports_back_and_summary_jumps() -> void:
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame

	assert_int(ChargenSteps.count()).is_equal(9)
	assert_str(screen.current_step_id()).is_equal("ancestry")
	assert_bool(screen.can_advance()).is_false()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("ancestry")

	screen.select_ancestry("vael")
	assert_bool(screen.can_advance()).is_true()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("discipline")
	assert_bool(screen.can_advance()).is_false()
	screen.select_discipline("chordblade")
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("patron")

	# Threadwalker x Chordblade is retired: the card is disabled and the pick refused.
	screen.select_class("threadwalker")
	assert_str(screen.build.class_id).is_equal("")
	assert_bool(screen.can_advance()).is_false()
	screen.select_class("ironbrand")
	assert_bool(screen.can_advance()).is_true()
	assert_str(screen.build.kit_skill).is_equal("heft")
	assert_bool(screen.select_kit("grip")).is_true()
	assert_bool(screen.select_kit("loose")).is_false()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("elements")

	# The class pre-filled its suggestion; an opposed pair invalidates the leaf.
	assert_str(screen.build.major_element).is_equal("scor")
	screen.select_major("suul")
	screen.select_minor("daar")
	assert_bool(screen.can_advance()).is_false()
	screen.select_minor("bloei")
	assert_bool(screen.can_advance()).is_true()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("attributes")
	assert_bool(screen.can_advance()).is_false()
	assert_bool(screen.set_attribute("muster", 5)).is_true()
	assert_bool(screen.set_attribute("grit", 5)).is_true()
	assert_bool(screen.set_attribute("reason", 4)).is_true()
	assert_bool(screen.set_attribute("alacrity", 3)).is_false()
	assert_bool(screen.can_advance()).is_true()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("background")
	assert_bool(screen.can_advance()).is_false()
	screen.select_background("verlossen-miner")
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("skills")
	assert_bool(screen.can_advance()).is_true()
	var percent := screen.find_child("Percent_grip", true, false) as Label
	assert_object(percent).is_not_null()
	assert_str(percent.text).contains("%")
	assert_object(screen.find_child("Percent_tone_aqua", true, false)).is_null()
	assert_bool(screen.buy_skill("grip")["allowed"]).is_true()
	assert_bool(screen.buy_skill("tone_aqua")["allowed"]).is_false()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("identity")
	assert_bool(screen.can_advance()).is_false()
	screen.set_display_name("Sera")
	assert_bool(screen.can_advance()).is_true()
	screen.next_step()
	assert_str(screen.current_step_id()).is_equal("summary")
	assert_bool(screen._accept_btn.visible).is_true()
	assert_bool(screen._accept_btn.disabled).is_false()

	screen.go_to_step(&"patron")
	assert_str(screen.current_step_id()).is_equal("patron")
	screen.back_step()
	assert_str(screen.current_step_id()).is_equal("discipline")
	screen.queue_free()


func test_player_chargen_boots_from_main_menu_and_writes_every_field() -> void:
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

	screen.accept()
	await runner.simulate_frames(3)

	assert_bool(GameState.has_created_character()).is_true()
	var member: PartyMember = GameState.party[0]
	_assert_member_matches_picks(member, "Sera", "the unbowed")
	assert_str(member.id).is_equal(GameState.PROTAGONIST_ID)
	# Creation buys reached the ledger under the final id, so the Mirror can refund them.
	assert_int(Advancement.total_points_spent(member)).is_equal(2)
	var restored := PartyMember.from_dict(member.to_dict())
	assert_float(SkillCheck.preview("heft", restored)).is_equal(SkillCheck.preview("heft", member))


func test_recruit_mode_uses_the_same_leaves_and_only_writes_the_custom_roster() -> void:
	var party_before := GameState.party.size()
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	screen.mode = CharacterCreationScreen.Mode.RECRUIT
	add_child(screen)
	await get_tree().process_frame
	assert_bool(screen.flow_owned).is_false()
	assert_bool(screen._back_btn.disabled).is_false()
	_fill_out_valid_build(screen, "Tamsin", "the quiet")
	_drive_to_summary(screen)
	var emitted: Array[PartyMember] = []
	screen.recruit_created.connect(func(member: PartyMember) -> void: emitted.append(member))
	screen.accept()
	await get_tree().process_frame

	assert_int(emitted.size()).is_equal(1)
	assert_int(GameState.party.size()).is_equal(party_before)
	assert_int(GameState.custom_recruits.size()).is_equal(_original_custom_recruits.size() + 1)
	var recruit: PartyMember = GameState.custom_recruits.back()
	_assert_member_matches_picks(recruit, "Tamsin", "the quiet")
	assert_bool(recruit.id.begins_with("recruit")).is_true()
	assert_int(Advancement.total_points_spent(recruit)).is_equal(2)
	screen.queue_free()


func test_recruit_mode_cancels_through_the_production_ui_stack() -> void:
	var runner := scene_runner("res://ui/screens/tavern.tscn")
	await runner.simulate_frames(2)
	var screen := UIManager.open(load("res://ui/screens/character_creation.tscn")) as CharacterCreationScreen
	screen.mode = CharacterCreationScreen.Mode.RECRUIT
	await runner.simulate_frames(2)

	screen.select_ancestry("vael")
	screen.go_to_step(&"elements")
	screen.back_step()
	assert_str(screen.current_step_id()).is_equal("patron")
	assert_bool(is_instance_valid(screen) and screen.is_inside_tree()).is_true()

	screen.go_to_step(&"ancestry")
	screen.back_step()
	await runner.simulate_frames(6)
	assert_bool(not is_instance_valid(screen) or not screen.is_inside_tree()).is_true()


func _fill_out_valid_build(screen: CharacterCreationScreen, name: String, epithet: String) -> void:
	screen.select_ancestry("vael")
	screen.select_discipline("terrashaper")
	screen.select_class("ironbrand")
	screen.select_major("suul")
	screen.select_minor("bloei")
	screen.select_background("verlossen-miner")
	screen.set_display_name(name)
	screen.set_epithet(epithet)
	screen.set_flaw("Will not leave a debt uncounted")
	screen.select_likeness(str(ChargenData.LIKENESSES[1]["id"]))
	screen.set_attribute("muster", 5)
	screen.set_attribute("grit", 5)
	screen.set_attribute("reason", 4)
	# heft: 5 × 8 + Trained 20 = 60 → the step to 65 costs 2 points.
	assert_int(screen.buy_skill("heft")["cost"]).is_equal(2)


func _drive_to_summary(screen: CharacterCreationScreen) -> void:
	screen.go_to_step(&"ancestry")
	for step: Dictionary in ChargenSteps.STEPS:
		if step["id"] == &"summary":
			break
		assert_bool(screen.can_advance()).override_failure_message(
			"leaf %s should be valid" % step["id"]).is_true()
		screen.next_step()
	assert_str(screen.current_step_id()).is_equal("summary")


func _assert_member_matches_picks(member: PartyMember, name: String, epithet: String) -> void:
	assert_str(member.display_name).is_equal(name)
	assert_str(member.epithet).is_equal(epithet)
	assert_str(member.race).is_equal("Vael")
	assert_str(member.discipline).is_equal("terrashaper")
	assert_str(member.patron).is_equal("Kero")
	assert_str(member.class_id).is_equal("ironbrand")
	assert_str(member.char_class).is_equal("Ironbrand (Kero)")
	assert_str(member.kit_weapon_skill).is_equal("heft")
	assert_str(member.background).is_equal("verlossen-miner")
	assert_str(member.major_element).is_equal("suul")
	assert_str(member.minor_element).is_equal("bloei")
	assert_str(member.mastery_element).is_equal("suul")
	assert_str(member.flaw).is_equal("Will not leave a debt uncounted")
	assert_str(member.starting_mastery).is_equal("Root Note of choice")
	assert_int(member.attribute_value(&"muster")).is_equal(5)
	assert_int(member.attribute_value(&"doctrine")).is_equal(2)
	assert_int(member.max_hp).is_equal(40)
	assert_str(str(member.skill_tiers["strain"])).is_equal("trained")
	assert_str(str(member.skill_tiers["heft"])).is_equal("trained")
	assert_str(str(member.skill_tiers["tone_suul"])).is_equal("trained")
	assert_float(float(member.skill_percentages["heft"])).is_equal(5.0)
	assert_int(member.advancement_points).is_equal(DramgidSchema.CREATION_POOL_BASE + 4 + 2 + 1 - 2)
	assert_bool(ClassResourceRegistry.for_patron(member.patron).patron_id == &"kero").is_true()
	assert_object(member.portrait).is_not_null()
	# The gallery selection persists its PAINTERLY plate (not the fallback).
	assert_str(member.portrait.resource_path).contains(
		"portraits/player/%s" % str(ChargenData.LIKENESSES[1]["id"])
	)


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
