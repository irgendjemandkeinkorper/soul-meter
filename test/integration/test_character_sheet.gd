extends GdUnitTestSuite
## FR-604 / #100: the character sheet screen — identity, skill derivation
## (FR-205), the Wheel widget, and the #98 advancement point-spend surface.

var _original_party: Array[PartyMember]
var _original_skills: Dictionary
var _original_show_math: bool


func before_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	_original_party = GameState.party.duplicate()
	_original_skills = GameState.skills.duplicate(true)
	_original_show_math = bool(GameState.get_setting("interface", "show_check_math", true))


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false
	GameState.party = _original_party
	GameState.skills = _original_skills
	GameState.set_setting("interface", "show_check_math", _original_show_math)


func _vex() -> PartyMember:
	var vex := PartyMember.new()
	vex.id = GameState.PROTAGONIST_ID
	vex.display_name = "Vex"
	vex.epithet = "the Unwritten"
	vex.race = "Human"
	vex.char_class = "Mirrorblade"
	vex.level = 2
	vex.attributes = {"forge": 3, "edge": 4, "anchor": 3, "spark": 5, "pitch": 2, "voice": 4}
	vex.skill_tiers = {"recall": "trained"}
	vex.advancement_points = 3
	return vex


func test_sheet_renders_identity_and_advancement_points() -> void:
	GameState.party = [_vex()]

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	var name_label := runner.find_child("SheetName", true, false) as Label
	assert_object(name_label).is_not_null()
	assert_str(name_label.text).is_equal("Vex, the Unwritten")

	var points := runner.find_child("AdvancementPoints", true, false) as Label
	assert_object(points).is_not_null()
	assert_str(points.text).contains("3")

	assert_object(runner.find_child("WheelWidget", true, false)).is_not_null()


func test_buy_button_spends_a_point_and_refreshes_the_percent() -> void:
	var vex := _vex()
	GameState.party = [vex]

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	# recall: reason 5 (legacy "spark") × 8 + trained 20 = 60% effective →
	# next step lands in the ≤75 band.
	var percent := runner.find_child("Percent_recall", true, false) as Label
	assert_str(percent.text).is_equal("60%")

	var buy := runner.find_child("Buy_recall", true, false) as Button
	assert_object(buy).is_not_null()
	assert_bool(buy.disabled).is_false()
	buy.pressed.emit()
	await runner.simulate_frames(1)

	assert_float(float(vex.skill_percentages.get("recall", 0.0))).is_equal(5.0)
	# The sheet rebuilt: re-find the fresh nodes.
	percent = runner.find_child("Percent_recall", true, false) as Label
	assert_str(percent.text).is_equal("65%")
	var points := runner.find_child("AdvancementPoints", true, false) as Label
	assert_str(points.text).contains("%d" % vex.advancement_points)


func test_check_math_toggle_hides_the_log_and_persists() -> void:
	GameState.party = [_vex()]
	GameState.set_setting("interface", "show_check_math", true)
	var forced: Array[int] = [10]
	SkillCheck.resolve("recall", GameState.party[0], 0.0, "test-sheet", forced)

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	assert_object(runner.find_child("CheckLog", true, false)).is_not_null()

	var toggle := runner.find_child("CheckMathToggle", true, false) as CheckButton
	toggle.button_pressed = false
	toggle.toggled.emit(false)
	await runner.simulate_frames(1)

	assert_object(runner.find_child("CheckLog", true, false)).is_null()
	assert_bool(bool(GameState.get_setting("interface", "show_check_math", true))).is_false()


func test_party_screen_offers_a_character_sheet_button() -> void:
	GameState.party = [_vex()]

	var runner := scene_runner("res://ui/screens/party.tscn")
	await runner.simulate_frames(2)

	var button := runner.find_child("CharacterSheetButton", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(button.visible).is_true()


func test_skills_are_grouped_under_schema_headings() -> void:
	GameState.party = [_vex()]

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	for group: String in [
		DramgidSchema.GROUP_ARMS, DramgidSchema.GROUP_BODY,
		DramgidSchema.GROUP_MIND, DramgidSchema.GROUP_SOUL, DramgidSchema.GROUP_VOICE,
	]:
		var heading := runner.find_child("SkillGroup_%s" % group, true, false) as Label
		assert_object(heading).override_failure_message(
			"no heading rendered for skill group '%s'" % group
		).is_not_null()
		assert_str(heading.text).is_equal(DramgidSchema.group_label(group))


func test_every_field_and_arms_skill_gets_a_row() -> void:
	# The sheet used to list twelve legacy ids. It now lists the schema's own slate,
	# so a skill added to DramgidSchema appears here without a second edit.
	GameState.party = [_vex()]

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	for skill_id: String in DramgidSchema.FIELD_SKILL_IDS:
		assert_object(runner.find_child("Percent_%s" % skill_id, true, false)).override_failure_message(
			"field skill '%s' has no row on the sheet" % skill_id
		).is_not_null()
	for skill_id: String in DramgidSchema.ARMS_SKILL_IDS:
		assert_object(runner.find_child("Percent_%s" % skill_id, true, false)).override_failure_message(
			"ARMS skill '%s' has no row on the sheet" % skill_id
		).is_not_null()


func test_only_the_tones_a_member_holds_are_listed() -> void:
	# Ten tone rows on every sheet would be eight dead ones for most builds, since a
	# member can only raise the tones their elements grant.
	var vex := _vex()
	vex.major_element = "khash"
	vex.minor_element = "luth"
	GameState.party = [vex]

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	assert_object(runner.find_child("Percent_tone_khash", true, false)).is_not_null()
	assert_object(runner.find_child("Percent_tone_luth", true, false)).is_not_null()
	assert_object(runner.find_child("Percent_tone_zhur", true, false)).override_failure_message(
		"a tone the member does not hold was listed"
	).is_null()


func test_a_tone_with_progress_stays_listed_but_cannot_be_raised() -> void:
	# Points already spent must not disappear from the sheet because an element changed.
	var vex := _vex()
	vex.major_element = "khash"
	vex.minor_element = "luth"
	vex.skill_percentages["tone_zhur"] = 15.0
	GameState.party = [vex]

	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	assert_object(runner.find_child("Percent_tone_zhur", true, false)).is_not_null()
	var buy := runner.find_child("Buy_tone_zhur", true, false) as Button
	assert_object(buy).is_not_null()
	assert_bool(buy.disabled).is_true()
	assert_str(buy.text).is_equal("not held")


# --- Called-shots 10C: field treatment on the sheet -----------------------------------------

var _treatment_gs: Dictionary


func _injured_party() -> Array[PartyMember]:
	var vex := _vex()
	vex.hp = 9
	vex.max_hp = 20
	_wound(vex, "throat", "k1")
	_wound(vex, "arm", "k2")
	var serai := PartyMember.new()
	serai.id = "serai"
	serai.display_name = "Serai"
	serai.hp = 12
	serai.max_hp = 12
	serai.skill_tiers = {"mending": "trained"}
	var party: Array[PartyMember] = [vex, serai]
	return party


static func _wound(member: PartyMember, location: String, key: String) -> void:
	var injury_id := "throat-crushed" if location == "throat" else "arm-severed"
	member.injuries[location] = {
		"injury_id": injury_id, "instance_id": "%s@%s|%s" % [injury_id, location, key],
		"location_id": location, "severity": "serious", "applications": 1,
		"effects": {"voice_blocked": true} if location == "throat" else {"attack_accuracy_pp": -10},
		"recovery": "untreated",
	}


func test_field_treatment_picks_the_qualified_practitioner_and_cures_only_the_selected_injury() -> void:
	var gp_before := GameState.gp
	var soul_before := GameState.soul_meter
	GameState.party = _injured_party()
	GameState.remove_items(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE, GameState.item_count(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE))
	Battle.controller = null
	Battle.ended = true
	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)
	assert_str((runner.find_child("InjuryTitle_throat", true, false) as Label).text).contains("Throat  •  serious  •  voice")
	var button := runner.find_child("FieldTreat_throat", true, false) as Button
	assert_str(button.text).contains("1 × Bitterleaf Poultice  (carry 0)")
	assert_bool(button.disabled).is_true()
	assert_str((runner.find_child("InjuryWhy_throat", true, false) as Label).text).contains("No bitterleaf_poultice to hand")
	# Last supply unit arrives; the qualified practitioner is picked by default.
	GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)
	(runner.scene() as Node).call("_rebuild_sheet")
	await runner.simulate_frames(1)
	var pick := runner.find_child("Practitioner_throat", true, false) as OptionButton
	assert_str(pick.get_item_text(pick.selected)).is_equal("Serai")
	button = runner.find_child("FieldTreat_throat", true, false) as Button
	assert_bool(button.disabled).is_false()
	# Switching to the untrained patient herself gives a precise reason.
	pick.select(0)
	pick.item_selected.emit(0)
	await runner.simulate_frames(1)
	button = runner.find_child("FieldTreat_throat", true, false) as Button
	assert_bool(button.disabled).is_true()
	assert_str((runner.find_child("InjuryWhy_throat", true, false) as Label).text).contains("Vex lacks Trained Mending")
	pick = runner.find_child("Practitioner_throat", true, false) as OptionButton
	pick.select(1)
	pick.item_selected.emit(1)
	await runner.simulate_frames(1)
	button = runner.find_child("FieldTreat_throat", true, false) as Button
	button.pressed.emit()
	await runner.simulate_frames(1)
	var vex: PartyMember = GameState.party[0]
	assert_array(vex.injuries.keys()).is_equal(["arm"])
	assert_int(vex.hp).is_equal(9)
	assert_int(GameState.item_count(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)).is_equal(0)
	assert_int(GameState.gp).is_equal(gp_before)
	assert_float(GameState.soul_meter).is_equal_approx(soul_before, 0.001)
	assert_str((runner.find_child("TreatmentStatus", true, false) as Label).text).contains("Serai treated Vex's throat; used 1 × Bitterleaf Poultice.")
	assert_object(runner.find_child("Injury_throat", true, false)).is_null()
	assert_object(runner.find_child("Injury_arm", true, false)).is_not_null()
	var notice := runner.find_child("TreatmentNotice", true, false) as PanelContainer
	assert_bool(notice.visible).is_true()
	assert_str((notice.get_node("Column/Top/Heading") as Label).text).is_equal("VEX — THROAT INJURY CLEARED")
	assert_str((notice.get_node("Column/Penalties") as Label).text).contains("voice block")
	assert_str((notice.get_node("Column/Payment") as Label).text).is_equal("Used 1 × Bitterleaf Poultice")
	assert_bool((notice.get_node("Column/Top/Dismiss") as Button).has_focus()).is_true()
	# Refreshing the sheet must not erase the success receipt or its focus.
	runner.scene().call("_rebuild_sheet")
	await runner.simulate_frames(1)
	assert_bool(notice.visible).is_true()
	runner.simulate_action_pressed("ui_accept")
	await runner.simulate_frames(1)
	assert_bool(notice.visible).is_false()
	assert_bool((runner.find_child("MemberList", true, false) as ItemList).has_focus()).is_true()


func test_recovery_receipt_closes_when_switching_patients() -> void:
	GameState.party = _injured_party()
	GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)
	Battle.controller = null
	Battle.ended = true
	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)
	(runner.find_child("FieldTreat_arm", true, false) as Button).pressed.emit()
	await runner.simulate_frames(1)
	var notice := runner.find_child("TreatmentNotice", true, false) as PanelContainer
	assert_bool(notice.visible).is_true()
	assert_object(runner.find_child("Injury_arm", true, false)).is_null()
	assert_object(runner.find_child("Injury_throat", true, false)).is_not_null()
	runner.scene().call("select_member", "serai")
	assert_bool(notice.visible).is_false()
	runner.scene().call("select_member", GameState.PROTAGONIST_ID)
	assert_bool(notice.visible).is_false()


func test_injured_hands_block_field_care_but_a_hurt_throat_does_not_and_combat_start_refuses() -> void:
	GameState.party = _injured_party()
	var serai: PartyMember = GameState.party[1]
	GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)
	_wound(serai, "arm", "m1")
	Battle.controller = null
	Battle.ended = true
	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)
	var pick := runner.find_child("Practitioner_throat", true, false) as OptionButton
	pick.select(1)
	pick.item_selected.emit(1)
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("FieldTreat_throat", true, false) as Button).disabled).is_true()
	assert_str((runner.find_child("InjuryWhy_throat", true, false) as Label).text).contains("Serai's arm injury prevents this treatment")
	serai.injuries.erase("arm")
	_wound(serai, "throat", "m2")
	(runner.scene() as Node).call("_rebuild_sheet")
	await runner.simulate_frames(1)
	pick = runner.find_child("Practitioner_throat", true, false) as OptionButton
	pick.select(1)
	pick.item_selected.emit(1)
	await runner.simulate_frames(1)
	var button := runner.find_child("FieldTreat_throat", true, false) as Button
	assert_bool(button.disabled).is_false()
	# Combat begins between the quote and the press: nothing is spent.
	Battle.controller = CombatController.new()
	Battle.ended = false
	button.pressed.emit()
	await runner.simulate_frames(1)
	Battle.controller = null
	Battle.ended = true
	assert_str((runner.find_child("TreatmentStatus", true, false) as Label).text).contains("combat active")
	assert_bool((runner.find_child("TreatmentNotice", true, false) as PanelContainer).visible).is_false()
	assert_bool((GameState.party[0] as PartyMember).injuries.has("throat")).is_true()
	assert_int(GameState.item_count(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE)).is_equal(1)
	GameState.remove_items(ItemIds.CONSUMABLES_BITTERLEAF_POULTICE, 1)


## #285: the Perks section offers the pending pick, records it, and shows a gated capstone
## with its refusal instead of hiding it.
func test_perks_section_offers_the_pick_and_records_it() -> void:
	var vex := _vex()
	vex.class_id = "mirrorblade"
	GameState.party = [vex]
	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	var choice := runner.find_child("PerkChoice", true, false) as Label
	assert_object(choice).is_not_null()
	assert_str(choice.text).contains("level-2")
	var button := runner.find_child("Perk_mirrorblade-second-footing", true, false) as Button
	assert_object(button).is_not_null()
	assert_bool(button.disabled).is_false()
	button.pressed.emit()
	await runner.simulate_frames(1)

	assert_array(Array(vex.perk_ids)).is_equal(["mirrorblade-second-footing"])
	var picked := runner.find_child("Picked_mirrorblade-second-footing", true, false) as Label
	assert_object(picked).is_not_null()
	# In play since #285 slice 2, so no "(planned)" marker.
	assert_str(picked.text).is_equal("Lv 2  Second Footing")
	assert_object(runner.find_child("PerkChoice", true, false)).is_null()
	assert_str((runner.find_child("NextPerk", true, false) as Label).text).is_equal("Next pick at level 4.")


func test_a_gated_capstone_is_shown_disabled_with_its_refusal() -> void:
	var renown_before := Renown.to_dict().duplicate(true)
	Renown.from_dict({})
	var vex := _vex()
	vex.class_id = "mirrorblade"
	vex.level = 6
	vex.perk_ids = PackedStringArray(["mirrorblade-second-footing", "mirrorblade-reflection"])
	GameState.party = [vex]
	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)

	assert_str((runner.find_child("Picked_mirrorblade-reflection", true, false) as Label).text).is_equal(
		"Lv 4  Reflection  (planned)"
	)
	var gated := runner.find_child("Perk_mirrorblade-known-edge", true, false) as Button
	var open := runner.find_child("Perk_mirrorblade-even-hand", true, false) as Button
	assert_object(gated).is_not_null()
	assert_object(open).is_not_null()
	assert_bool(gated.disabled).is_true()
	assert_bool(open.disabled).is_false()
	var column := runner.find_child("PerksColumn", true, false) as VBoxContainer
	var texts: Array[String] = []
	for child: Node in column.get_children():
		if child is Label:
			texts.append((child as Label).text)
	assert_bool(texts.any(func(t: String) -> bool: return t.contains("Needs Fame: Known or more."))).is_true()
	Renown.from_dict(renown_before)


func test_a_member_without_a_patron_class_has_no_perks() -> void:
	GameState.party = [_vex()]
	var runner := scene_runner("res://ui/screens/character_sheet.tscn")
	await runner.simulate_frames(2)
	assert_object(runner.find_child("NoPerks", true, false)).is_not_null()
	assert_object(runner.find_child("PerkChoice", true, false)).is_null()
