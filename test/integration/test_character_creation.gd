extends GdUnitTestSuite
## Integration coverage for the one-screen register on DRAMGID (owner ruling 2026-11-02,
## docs/design/chargen-overhaul-plan-2026-11-02.md; model rules in
## docs/architecture-chargen-dramgid.md §7). The player test enters through the real main
## menu and GameFlow state; the recruit tests use the same scene in its tavern-owned mode.
## Tests drive the public API and live controls, then inspect what is shown and the
## registered PartyMember.

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


func test_the_register_opens_rolled_on_calling_with_only_the_name_left() -> void:
	var screen := await _open_screen()
	assert_int(ChargenSteps.TABS.size()).is_equal(4)
	assert_str(screen.current_tab_id()).is_equal("calling")
	assert_bool((screen.find_child("Page_calling", true, false) as Control).visible).is_true()
	assert_bool((screen.find_child("Page_origin", true, false) as Control).visible).is_false()
	assert_str(screen.build.display_name).is_empty()
	for step_id: StringName in ChargenSteps.ids():
		if step_id in [&"identity", &"summary"]:
			continue
		assert_bool(screen.build.validate(step_id)["valid"]).override_failure_message(String(step_id)).is_true()
	assert_int(screen.build.points_remaining()).is_equal(0)
	assert_str(screen._status_lbl.text).is_equal("Name the entry to begin")
	assert_str((screen.find_child("Tab_name", true, false) as Button).text).contains("•")
	screen.set_display_name("Sera")
	assert_bool(screen.build.is_complete()).is_true()
	assert_str(screen._status_lbl.text).is_equal("Entry ready — BEGIN when you are")
	screen.queue_free()


func test_tabs_open_in_any_order_and_begin_without_a_name_puts_the_cursor_in_it() -> void:
	var screen := await _open_screen()
	for tab_id: StringName in [&"name", &"origin", &"measures", &"calling", &"origin"]:
		(screen.find_child("Tab_%s" % tab_id, true, false) as Button).pressed.emit()
		assert_str(screen.current_tab_id()).is_equal(String(tab_id))
		for other: StringName in ChargenSteps.tab_ids():
			var page := screen.find_child("Page_%s" % other, true, false) as Control
			assert_bool(page.visible).is_equal(other == tab_id)

	var accepted: Array[PartyMember] = []
	screen.recruit_created.connect(func(member: PartyMember) -> void: accepted.append(member))
	var begin_btn := screen.find_child("BeginButton", true, false) as Button
	begin_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(accepted.size()).is_equal(0)
	assert_object(screen.get_viewport().gui_get_focus_owner()).is_same(screen._name_edit)
	assert_str(screen.current_tab_id()).is_equal("origin")
	screen.queue_free()


func test_a_retired_pairing_and_an_opposed_pair_are_refused_and_named() -> void:
	var screen := await _open_screen()
	screen.set_display_name("Sera")
	screen.select_discipline("chordblade")
	screen.select_class("ironbrand")
	# Threadwalker x Chordblade is retired: the tile is disabled and the pick refused.
	var threadwalker := screen.find_child("Class_threadwalker", true, false) as Button
	assert_bool(threadwalker.disabled).is_true()
	screen.select_class("threadwalker")
	assert_str(screen.build.class_id).is_equal("ironbrand")
	# Picking a class applies its suggested tones, so its tiles show the spells it is built on.
	assert_str(screen.build.major_element).is_equal("khash")
	assert_str(screen.build.minor_element).is_equal("mozh")
	assert_str(screen.build.kit_skill).is_equal("heft")
	assert_bool(screen.select_kit("grip")).is_true()
	assert_bool(screen.select_kit("loose")).is_false()

	screen.select_major("sul")
	screen.select_minor("vekh")
	assert_bool(screen.build.validate(&"elements")["valid"]).is_false()
	assert_str(screen._status_lbl.text).is_equal("CALLING  ·  Major and Minor cannot be an opposed pair.")
	assert_str((screen.find_child("Tab_calling", true, false) as Button).text).contains("•")
	var accepted: Array[PartyMember] = []
	screen.recruit_created.connect(func(member: PartyMember) -> void: accepted.append(member))
	screen.go_to_tab(&"name")
	screen.begin()
	assert_str(screen.current_tab_id()).is_equal("calling")
	assert_int(accepted.size()).is_equal(0)
	screen.select_minor("vel")
	assert_bool(screen.build.is_complete()).is_true()
	screen.queue_free()


func test_ability_tiles_come_from_the_kit_preview_and_show_their_card() -> void:
	var screen := await _open_screen()
	screen.select_discipline("thamshaper")
	screen.select_class("ironbrand")
	# The roll may already be Ironbrand on other tones; pin its suggested pair.
	screen.select_major("khash")
	screen.select_minor("mozh")
	var own := screen.find_child("ClassAbilities", true, false) as HFlowContainer
	var names: Array[String] = []
	for tile: Node in own.get_children():
		names.append(String(tile.name))
	assert_array(names).contains_exactly(["Ability_spend_scars", "Ability_debt_of_arms"])
	var debt := own.get_node("Ability_debt_of_arms") as Button
	assert_str(debt.theme_type_variation).is_equal("ChargenAbilityTileLocked")
	var tones := screen.find_child("ToneAbilities", true, false) as HFlowContainer
	assert_int(tones.get_child_count()).is_equal(
		(KitPreview.for_member(screen.build.scratch_member())[KitPreview.TONES] as Array).size())
	assert_object(tones.get_node_or_null("Ability_sentence_of_ash")).is_null()

	var crown := tones.get_node("Ability_crown_of_embers") as Button
	crown.mouse_entered.emit()
	var card := screen.ability_card_text()
	assert_str(str(card["title"])).is_equal("Crown of Embers")
	assert_str(str(card["effect"])).is_equal(CombatActionCatalog.by_id(&"crown-of-embers").summary())
	crown.mouse_exited.emit()
	assert_bool(screen.ability_card_text().is_empty()).is_true()
	debt.focus_entered.emit()
	assert_str(str(screen.ability_card_text()["effect"])).contains("Needs the Debt of Arms perk.")
	debt.focus_exited.emit()

	# Stormbearer adds nothing of its own and has no Zhur spells: both gaps are said, not filled.
	screen.select_class("stormbearer")
	assert_int((screen.find_child("ClassAbilities", true, false) as HFlowContainer).get_child_count()).is_equal(0)
	var texts: Array[String] = []
	for label: Node in screen._ability_groups.get_children():
		if label is Label:
			texts.append((label as Label).text)
	assert_array(texts).contains(["No actions of its own yet.", "No Zhur spells yet."])
	screen.queue_free()


func test_every_class_fits_its_tiles_inside_the_1080p_tab_panel() -> void:
	var size_before := get_tree().root.size
	get_tree().root.size = Vector2i(1920, 1080)
	var runner := scene_runner("res://ui/screens/character_creation.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as CharacterCreationScreen
	screen.select_discipline("thamshaper")
	var panel := (screen.find_child("TabPages", true, false) as Control).get_parent() as Control
	for entry: Dictionary in ClassCatalog.ALL:
		screen.select_class(str(entry["id"]))
		await runner.simulate_frames(2)
		var tiles_bottom := screen._ability_groups.get_global_rect().end.y
		var detail_bottom := (screen.find_child("ClassDetail", true, false) as Control).get_global_rect().end.y
		assert_float(maxf(tiles_bottom, detail_bottom)).override_failure_message(
			"%s overflows: %s > %s" % [entry["name"], maxf(tiles_bottom, detail_bottom), panel.get_global_rect().end.y]
		).is_less_equal(panel.get_global_rect().end.y)
	var frame := Rect2(Vector2.ZERO, Vector2(1920, 1080))
	for name: String in ["BeginButton", "RandomizeButton", "RollTabButton"]:
		var button := screen.find_child(name, true, false) as Control
		assert_bool(frame.encloses(button.get_global_rect())).override_failure_message(name).is_true()
	get_tree().root.size = size_before


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
	assert_bool(screen._cancel_btn.visible).is_false()
	_fill_out_valid_build(screen, "Sera", "the unbowed")
	assert_bool(screen.build.is_complete()).is_true()

	screen.begin()
	await runner.simulate_frames(3)

	assert_bool(GameState.has_created_character()).is_true()
	var member: PartyMember = GameState.party[0]
	_assert_member_matches_picks(member, "Sera", "the unbowed")
	assert_str(member.id).is_equal(GameState.PROTAGONIST_ID)
	# Creation buys reached the ledger under the final id, so the Mirror can refund them.
	assert_int(Advancement.total_points_spent(member)).is_equal(2)
	var restored := PartyMember.from_dict(member.to_dict())
	assert_float(SkillCheck.preview("heft", restored)).is_equal(SkillCheck.preview("heft", member))


func test_recruit_mode_uses_the_same_register_and_only_writes_the_custom_roster() -> void:
	var party_before := GameState.party.size()
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	screen.mode = CharacterCreationScreen.Mode.RECRUIT
	add_child(screen)
	await get_tree().process_frame
	assert_bool(screen.flow_owned).is_false()
	assert_bool(screen._cancel_btn.visible).is_true()
	_fill_out_valid_build(screen, "Tamsin", "the quiet")
	var emitted: Array[PartyMember] = []
	screen.recruit_created.connect(func(member: PartyMember) -> void: emitted.append(member))
	screen.begin()
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
	screen.go_to_tab(&"measures")
	assert_bool(is_instance_valid(screen) and screen.is_inside_tree()).is_true()

	# CANCEL ENTRY closes the screen back to the caller from any tab. The close is animated
	# (`DS.DUR_FAST`, and `UIManager.back()` awaits the exit tween before freeing), so a fixed
	# handful of frames is not a wait — poll on the condition with a frame budget instead.
	(screen.find_child("CancelEntryButton", true, false) as Button).pressed.emit()
	for _frame: int in 60:
		if not is_instance_valid(screen) or not screen.is_inside_tree():
			break
		await get_tree().process_frame
	assert_bool(not is_instance_valid(screen) or not screen.is_inside_tree()).is_true()
	UIManager.close_all()


func test_randomize_all_keeps_the_players_words_and_registers_the_roll() -> void:
	var runner := scene_runner("res://ui/screens/character_creation.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as CharacterCreationScreen
	var randomize_btn := runner.find_child("RandomizeButton", true, false) as Button
	assert_str(randomize_btn.text).is_equal("RANDOMIZE ALL")
	screen._random_rng.seed = 64
	screen.set_display_name("Sera")
	screen.set_epithet("the unbowed")
	screen.set_flaw("Will not leave a debt uncounted")
	var previous := screen.build.to_party_member().to_dict()
	for tab_id: StringName in ChargenSteps.tab_ids():
		screen.go_to_tab(tab_id)
		randomize_btn.pressed.emit()
		await runner.simulate_frames(2)
		assert_str(screen.current_tab_id()).is_equal(String(tab_id))
		assert_bool(screen.build.is_complete()).is_true()
		assert_int(screen.build.points_remaining()).is_equal(0)
		assert_str(screen.build.display_name).is_equal("Sera")
		assert_str(screen.build.epithet).is_equal("the unbowed")
		assert_str(screen.build.flaw).is_equal("Will not leave a debt uncounted")
		var rolled := screen.build.to_party_member().to_dict()
		assert_bool(rolled == previous).is_false()
		previous = rolled
		assert_str(screen._name_edit.text).is_equal("Sera")
		for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
			assert_str((screen._measure_value_lbls[attribute_id] as Label).text).is_equal(
				str(screen.build.attributes[attribute_id]))
	var expected := screen.build.to_party_member().to_dict()
	var likeness := screen.build.likeness_id
	var spent := screen.build.points_spent()
	(runner.find_child("BeginButton", true, false) as Button).pressed.emit()
	await runner.simulate_frames(2)

	assert_bool(GameState.has_created_character()).is_true()
	var member: PartyMember = GameState.party[0]
	var actual := member.to_dict()
	for field: String in ["display_name", "epithet", "race", "discipline", "patron",
		"class_id", "char_class", "kit_weapon_skill", "background", "major_element",
		"minor_element", "mastery_element", "starting_mastery", "flaw", "attributes",
		"skill_tiers", "skill_percentages", "advancement_points"]:
		assert_bool(actual[field] == expected[field]).override_failure_message(
			"Confirmed member must retain rolled %s" % field).is_true()
	assert_int(Advancement.total_points_spent(member)).is_equal(spent)
	assert_str(member.portrait.resource_path).contains("portraits/player/%s" % likeness)


func test_roll_this_tab_rolls_only_the_open_tab() -> void:
	var runner := scene_runner("res://ui/screens/character_creation.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as CharacterCreationScreen
	screen.set_display_name("Sera")
	var roll_btn := runner.find_child("RollTabButton", true, false) as Button
	screen._random_rng.seed = 11
	screen.go_to_tab(&"origin")
	var before := screen.build.copy()
	var changed := false
	for _attempt: int in 6:
		roll_btn.pressed.emit()
		changed = changed or screen.build.ancestry_id != before.ancestry_id or screen.build.background_id != before.background_id
		for field: String in ["class_id", "discipline_id", "major_element", "minor_element", "attributes", "likeness_id", "display_name"]:
			assert_that(screen.build.get(field)).override_failure_message(field).is_equal(before.get(field))
		# Rolled creation points follow the entry: the refund the new origin forced is re-spent.
		assert_int(screen.build.points_remaining()).is_equal(0)
	assert_bool(changed).is_true()
	assert_str(screen.current_tab_id()).is_equal("origin")


func test_points_bought_by_hand_are_never_re_spent_behind_the_player() -> void:
	var screen := await _open_screen()
	screen.set_display_name("Sera")
	screen.select_discipline("thamshaper")
	screen.select_class("ironbrand")
	assert_int(screen.build.points_remaining()).is_equal(0)
	# Changing class refunds creation points (model rule); rolled ones are re-spent at once.
	screen.select_class("mirrorblade")
	assert_int(screen.build.points_remaining()).is_equal(0)
	# The first hand-made refund hands the pool to the player.
	var bought: String = screen.build.creation_buys.keys()[0]
	assert_bool(screen.refund_skill(bought)["allowed"]).is_true()
	screen.select_class("ironbrand")
	assert_int(screen.build.points_remaining()).is_equal(screen.build.creation_pool())
	assert_str(screen._status_lbl.text).contains("unspent")
	screen.queue_free()


func test_randomize_during_an_attribute_animation_keeps_the_rolled_readout() -> void:
	var runner := scene_runner("res://ui/screens/character_creation.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as CharacterCreationScreen
	screen.go_to_tab(&"measures")
	_reset_measures(screen)
	screen.set_attribute("muster", DramgidSchema.ATTRIBUTE_CAP)
	await runner.simulate_frames(2)
	var minus := runner.find_child("Minus_muster", true, false) as Button
	minus.pressed.emit()
	screen._random_rng.seed = 64
	var randomize_btn := runner.find_child("RandomizeButton", true, false) as Button
	randomize_btn.pressed.emit()
	await runner.simulate_frames(20)
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		var bar := screen._attribute_bars[attribute_id] as ProgressBar
		assert_float(bar.value).is_equal(float(screen.build.attributes[attribute_id]))


func _open_screen() -> CharacterCreationScreen:
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	add_child(screen)
	await get_tree().process_frame
	return screen


func _reset_measures(screen: CharacterCreationScreen) -> void:
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		screen.set_attribute(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR)


## The register opens rolled; pin every pick so the registered member is predictable. Rolled
## creation points are refunded by hand first, which also stops them being re-spent.
func _fill_out_valid_build(screen: CharacterCreationScreen, name: String, epithet: String) -> void:
	screen.select_ancestry("vael")
	screen.select_discipline("thamshaper")
	screen.select_class("ironbrand")
	screen.select_kit("heft")
	screen.select_major("sul")
	screen.select_minor("vel")
	assert_bool(screen.select_mastery("sul")).is_true()
	screen.select_background("verlossen-miner")
	screen.set_display_name(name)
	screen.set_epithet(epithet)
	screen.set_flaw("Will not leave a debt uncounted")
	screen.select_likeness(str(ChargenData.LIKENESSES[1]["id"]))
	_reset_measures(screen)
	screen.set_attribute("muster", 5)
	screen.set_attribute("grit", 5)
	screen.set_attribute("reason", 4)
	for skill_id: String in screen.build.creation_buys.keys():
		while screen.build.steps_bought(skill_id) > 0:
			screen.refund_skill(skill_id)
	# heft: 5 × 8 + Trained 20 = 60 → the step to 65 costs 2 points.
	assert_int(screen.buy_skill("heft")["cost"]).is_equal(2)


func _assert_member_matches_picks(member: PartyMember, name: String, epithet: String) -> void:
	assert_str(member.display_name).is_equal(name)
	assert_str(member.epithet).is_equal(epithet)
	assert_str(member.race).is_equal("Vael")
	assert_str(member.discipline).is_equal("thamshaper")
	assert_str(member.patron).is_equal("Kero")
	assert_str(member.class_id).is_equal("ironbrand")
	assert_str(member.char_class).is_equal("Ironbrand (Kero)")
	assert_str(member.kit_weapon_skill).is_equal("heft")
	assert_str(member.background).is_equal("verlossen-miner")
	assert_str(member.major_element).is_equal("sul")
	assert_str(member.minor_element).is_equal("vel")
	assert_str(member.mastery_element).is_equal("sul")
	assert_str(member.flaw).is_equal("Will not leave a debt uncounted")
	assert_str(member.starting_mastery).is_equal("Root Note of choice")
	assert_int(member.attribute_value(&"muster")).is_equal(5)
	assert_int(member.attribute_value(&"doctrine")).is_equal(2)
	assert_int(member.max_hp).is_equal(
		DramgidDerived.max_hp(member.attribute_value(&"grit"))
	)
	assert_str(str(member.skill_tiers["strain"])).is_equal("trained")
	assert_str(str(member.skill_tiers["heft"])).is_equal("trained")
	assert_str(str(member.skill_tiers["tone_sul"])).is_equal("trained")
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
