extends GdUnitTestSuite
## U3 (owner-approved plan, docs/design/ui-rework-plan-2026-11-01.md): one shell with BACK at
## the left of the HUD bar; the Party screen folded into the Register of Persons, which opens on
## a summary and keeps skills on their own tab; a compact journal and standing; and inventory
## actions that wait for a selection.

const SHEET := "res://ui/screens/character_sheet.tscn"

var _party_before: Array[PartyMember] = []
var _inventory_before: Dictionary
var _equipped_before: Dictionary
var _quest_pools_before: Dictionary
var _quest_resources_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary


func before_test() -> void:
	UIManager.close_all()
	UIManager.reset_reward_reveals()
	get_tree().paused = false
	_party_before = GameState.party.duplicate()
	_inventory_before = GameState.inventory.serialize()
	_equipped_before = GameState.equipped_slots.duplicate(true)
	_quest_pools_before = QuestRegistry.to_dict().duplicate(true)
	_quest_resources_before = {}
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		_quest_resources_before[quest.id] = quest.serialize().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)


func after_test() -> void:
	UIManager.close_all()
	UIManager.reset_reward_reveals()
	get_tree().paused = false
	GameState.party = _party_before
	GameState.inventory.deserialize(_inventory_before)
	GameState.equipped_slots = _equipped_before
	for quest: Quest in QuestRegistry.ALL_QUESTS:
		if _quest_resources_before.has(quest.id):
			quest.deserialize(_quest_resources_before[quest.id])
	QuestRegistry.from_dict(_quest_pools_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)


# --- One shell ----------------------------------------------------------------------------------

func test_every_panel_puts_back_at_the_left_of_its_hud_bar() -> void:
	GameState.party = [_hero(0)]
	for path: String in [
		SHEET, "res://ui/screens/journal.tscn", "res://ui/screens/standing.tscn",
		"res://ui/screens/inventory.tscn", "res://ui/screens/settings.tscn",
		"res://ui/screens/load_game.tscn",
	]:
		var runner := scene_runner(path)
		await runner.simulate_frames(2)
		var screen := runner.scene() as Screen
		var back := screen.shell_back_button
		assert_object(back).override_failure_message("%s has no BACK" % path).is_not_null()
		assert_object(back.get_parent()).override_failure_message(
			"%s: BACK is not in the HUD bar" % path
		).is_same(screen.shell_hud_bar)
		assert_int(back.get_index()).is_equal(0)
		# The gauge stays rightmost (DS rule).
		var last := screen.shell_hud_bar.get_child(screen.shell_hud_bar.get_child_count() - 1)
		assert_str(last.scene_file_path).is_equal("res://ui/hud/soul_gauge.tscn")
		screen.queue_free()
		await runner.simulate_frames(1)


# --- Register of Persons ------------------------------------------------------------------------

func test_the_sheet_opens_on_the_summary_with_condition_bio_and_quest() -> void:
	GameState.party = [_hero(0), _serai_lun()]
	var runner := scene_runner(SHEET)
	await runner.simulate_frames(2)

	assert_bool((runner.find_child("Tab_summary", true, false) as Button).button_pressed).is_true()
	assert_bool((runner.find_child("SummaryPage", true, false) as Control).visible).is_true()
	assert_bool((runner.find_child("SkillsPage", true, false) as Control).visible).is_false()
	assert_str((runner.find_child("HPNumbers", true, false) as Label).text).is_equal("15 / 30")
	assert_float((runner.find_child("HPMeter", true, false) as MeterBar).value).is_equal_approx(0.5, 0.001)
	assert_object(runner.find_child("BreathMeter", true, false)).is_not_null()

	var list := runner.find_child("MemberList", true, false) as ItemList
	list.select(1)
	list.item_selected.emit(1)
	await runner.simulate_frames(1)
	var bio := runner.find_child("MemberBio", true, false) as Label
	assert_object(bio).is_not_null()
	assert_str(bio.text).is_not_empty()
	var quest := runner.find_child("PersonalQuestButton", true, false) as Button
	assert_bool(quest.visible).is_true()


func test_the_roster_shows_names_whole_with_the_level_on_hover() -> void:
	var hero := _hero(0)
	hero.display_name = "Vex the Unbowed"
	hero.level = 4
	GameState.party = [hero]
	var runner := scene_runner(SHEET)
	await runner.simulate_frames(2)
	var list := runner.find_child("MemberList", true, false) as ItemList
	assert_str(list.get_item_text(0)).is_equal("Vex the Unbowed")
	assert_str(list.get_item_tooltip(0)).is_equal("Level 4")


func test_skills_have_their_own_tab_which_survives_a_member_switch() -> void:
	GameState.party = [_hero(2), _hero(0, "second")]
	var runner := scene_runner(SHEET)
	await runner.simulate_frames(2)
	var skills_tab := runner.find_child("Tab_skills", true, false) as Button
	assert_str(skills_tab.text).is_equal("SKILLS  ·  2 TO SPEND")
	skills_tab.pressed.emit()
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("SkillsPage", true, false) as Control).visible).is_true()
	assert_bool((runner.find_child("SummaryPage", true, false) as Control).visible).is_false()

	var list := runner.find_child("MemberList", true, false) as ItemList
	list.select(1)
	list.item_selected.emit(1)
	await runner.simulate_frames(1)
	assert_bool((runner.find_child("SkillsPage", true, false) as Control).visible).is_true()
	assert_bool(skills_tab.button_pressed).is_true()
	assert_str(skills_tab.text).is_equal("SKILLS")


func test_plus_buttons_appear_only_with_points_to_spend() -> void:
	GameState.party = [_hero(0)]
	var runner := scene_runner(SHEET)
	await runner.simulate_frames(2)
	assert_object(runner.find_child("Percent_recall", true, false)).is_not_null()
	assert_object(runner.find_child("Buy_recall", true, false)).is_null()
	assert_int((runner.find_child("SkillGrid_*", true, false) as GridContainer).columns).is_equal(2)

	GameState.party[0].advancement_points = 1
	(runner.scene() as Screen).call("_rebuild_sheet")
	await runner.simulate_frames(1)
	assert_object(runner.find_child("Buy_recall", true, false)).is_not_null()
	assert_int((runner.find_child("SkillGrid_*", true, false) as GridContainer).columns).is_equal(3)


func test_the_summary_lists_the_heros_equipment() -> void:
	GameState.party = [_hero(0)]
	GameState.equipped_slots = {"main": ItemIds.WEAPONS_TAUBSTUMMER_AXE}
	var runner := scene_runner(SHEET)
	await runner.simulate_frames(2)
	var equipped := runner.find_child("Equipped", true, false) as Label
	assert_object(equipped).is_not_null()
	assert_str(equipped.text).starts_with("MAIN  ·  ")
	assert_str(equipped.text).contains("Axe")


func test_no_injuries_means_no_injuries_heading() -> void:
	GameState.party = [_hero(0)]
	var runner := scene_runner(SHEET)
	await runner.simulate_frames(2)
	assert_bool((runner.find_child("InjuriesHeading", true, false) as Label).visible).is_false()


# --- Journal and standing -----------------------------------------------------------------------

func test_a_journal_entry_is_title_objective_and_one_who_where_line() -> void:
	QuestRegistry.reset()
	QuestRegistry.offer(QuestRegistry.FIELD_DEBT)
	var runner := scene_runner("res://ui/screens/journal.tscn")
	await runner.simulate_frames(2)

	assert_str((runner.find_child("NextObjective", true, false) as Label).text).is_equal(
		ChapterOneProgress.objective()
	)
	var entry := (runner.find_child("ActiveQuests", true, false) as Node).find_child("Quest*", false, false)
	assert_object(entry).is_not_null()
	# Active: no state badge. One context line with no labels or line breaks.
	assert_object(entry.find_child("QuestState", true, false)).is_null()
	var context := entry.find_child("QuestContext", true, false) as Label
	assert_bool(context.text.contains("\n")).is_false()
	assert_str(context.text).contains("  ·  ")
	var title := entry.find_child("QuestTitle", true, false) as Label
	assert_str(title.tooltip_text).is_not_empty()


func test_standing_with_no_factions_is_one_line() -> void:
	Reputation.from_dict({})
	var runner := scene_runner("res://ui/screens/standing.tscn")
	await runner.simulate_frames(2)
	assert_object(runner.find_child("NoFactions", true, false)).is_not_null()
	assert_object(runner.find_child("FactionList", true, false)).is_null()


func test_standing_with_a_faction_lists_it_beside_its_reasons() -> void:
	Reputation.from_dict({})
	Reputation.record("player", "mirror-choir", 1.0, "Test cause", "test-room")
	var runner := scene_runner("res://ui/screens/standing.tscn")
	await runner.simulate_frames(2)
	assert_object(runner.find_child("NoFactions", true, false)).is_null()
	assert_int((runner.find_child("FactionList", true, false) as ItemList).item_count).is_equal(1)
	assert_int((runner.find_child("FactionHistory", true, false) as Node).get_child_count()).is_greater(0)


# --- Inventory ----------------------------------------------------------------------------------

func test_inventory_actions_wait_for_a_selection_and_selection_is_a_violet_edge() -> void:
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var item := GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(2)
	var screen := runner.scene() as InventoryScreen
	var actions := screen.find_child("ItemActions", true, false) as Control
	assert_bool(actions.visible).is_false()
	screen._on_item_selected(item)
	assert_bool(actions.visible).is_true()

	var selection := (screen.find_child("BagGrid", true, false) as CtrlInventoryGrid).selection_style as StyleBoxFlat
	assert_object(selection).is_not_null()
	assert_bool(selection.draw_center).is_false()
	assert_str(selection.border_color.to_html()).is_equal(DS.VIOLET_4.to_html())


# --- helpers ------------------------------------------------------------------------------------

func _hero(points: int, id: String = GameState.PROTAGONIST_ID) -> PartyMember:
	var hero := PartyMember.new()
	hero.id = id
	hero.display_name = "Tester" if id == GameState.PROTAGONIST_ID else "Second"
	hero.max_hp = 30
	hero.hp = 15
	hero.attributes = {"forge": 3, "edge": 4, "anchor": 3, "spark": 5, "pitch": 2, "voice": 4}
	hero.advancement_points = points
	return hero


func _serai_lun() -> PartyMember:
	for candidate: PartyMember in GameState.recruitable_candidates():
		if candidate.id == "serai-lun":
			return candidate
	fail("serai-lun is no longer a recruitable candidate")
	return null
