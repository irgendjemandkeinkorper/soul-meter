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
	vex.skill_tiers = {"lore": "trained"}
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

	# lore: spark 5 × 8 + trained 20 = 60% effective → next step lands ≤75 band.
	var percent := runner.find_child("Percent_lore", true, false) as Label
	assert_str(percent.text).is_equal("60%")

	var buy := runner.find_child("Buy_lore", true, false) as Button
	assert_object(buy).is_not_null()
	assert_bool(buy.disabled).is_false()
	buy.pressed.emit()
	await runner.simulate_frames(1)

	assert_float(float(vex.skill_percentages.get("lore", 0.0))).is_equal(5.0)
	# The sheet rebuilt: re-find the fresh nodes.
	percent = runner.find_child("Percent_lore", true, false) as Label
	assert_str(percent.text).is_equal("65%")
	var points := runner.find_child("AdvancementPoints", true, false) as Label
	assert_str(points.text).contains("%d" % vex.advancement_points)


func test_check_math_toggle_hides_the_log_and_persists() -> void:
	GameState.party = [_vex()]
	GameState.set_setting("interface", "show_check_math", true)
	var forced: Array[int] = [10]
	SkillCheck.resolve("lore", GameState.party[0], 0.0, "test-sheet", forced)

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
