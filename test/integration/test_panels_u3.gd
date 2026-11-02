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
	# Nothing completed yet: the "Quests entered" column waits (owner 2026-11-02).
	assert_bool((runner.find_child("CompletedQuestsPanel", true, false) as Control).visible).is_false()


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


func test_an_item_can_be_dragged_with_the_mouse_from_the_bag_to_its_slot() -> void:
	# Playtest 2026-11-02: dragging did nothing. The slot's frame took the press, so GLoot's
	# draggable wrapper never saw it.
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var axe := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(3)
	var screen := _on_top(runner.scene()) as InventoryScreen
	var from := _draggable_for(screen.find_child("BagGrid", true, false), axe).get_global_rect().get_center()
	var slot_name := InventoryScreen.slot_of(axe)
	var to := (screen.find_child("Equipment_%s" % slot_name, true, false) as Control).get_global_rect().get_center()

	await _drag(runner, from, to)

	assert_object(axe.get_inventory()).is_same(screen.find_child("EquipmentInventory_%s" % slot_name, true, false))


func test_dragging_onto_a_filled_slot_swaps_the_old_item_back_to_the_bag() -> void:
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var axe := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(3)
	var screen := _on_top(runner.scene()) as InventoryScreen
	var slot_name := InventoryScreen.slot_of(axe)
	var slot := screen.find_child("EquipmentInventory_%s" % slot_name, true, false) as Inventory
	screen._on_item_selected(axe)
	screen._equip_selected()
	assert_object(axe.get_inventory()).is_same(slot)
	var second := GameState.inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	await runner.simulate_frames(2)

	await _drag(runner, _draggable_for(screen.find_child("BagGrid", true, false), second).get_global_rect().get_center(),
		(screen.find_child("Equipment_%s" % slot_name, true, false) as Control).get_global_rect().get_center())

	assert_object(second.get_inventory()).is_same(slot)
	assert_object(axe.get_inventory()).is_same(GameState.inventory)


func test_an_item_can_be_dragged_to_another_cell_of_the_bag() -> void:
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var loaf := GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(3)
	var screen := _on_top(runner.scene()) as InventoryScreen
	var bag := screen.find_child("BagGrid", true, false) as CtrlInventoryGrid
	var grid := GameState.inventory.get_constraint(GridConstraint) as GridConstraint
	var before := grid.get_item_position(loaf)
	var from := _draggable_for(bag, loaf).get_global_rect().get_center()
	var cell := bag.field_dimensions.x + DS.ITEM_GRID_GAP

	await _drag(runner, from, from + Vector2(cell * 3.0, cell))

	assert_that(grid.get_item_position(loaf)).is_equal(before + Vector2i(3, 1))


func test_a_click_on_a_bag_item_selects_it() -> void:
	GameState.inventory.clear()
	GameState.equipped_slots.clear()
	var loaf := GameState.inventory.create_and_add_item(ItemIds.CONSUMABLES_HEARTHLOAF)
	var runner := scene_runner("res://ui/screens/inventory.tscn")
	await runner.simulate_frames(3)
	var screen := _on_top(runner.scene()) as InventoryScreen
	runner.simulate_mouse_move(_draggable_for(screen.find_child("BagGrid", true, false), loaf).get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()
	assert_bool((screen.find_child("ItemActions", true, false) as Control).visible).is_true()


func test_a_mythic_item_is_framed_by_an_edge_not_a_fill() -> void:
	# Owner 2026-11-02: amber edge on the dark well, like rare's violet edge.
	var theme := ThemeBuilder.build()
	var mythic := theme.get_stylebox("panel", "ItemSlotMythic") as StyleBoxTexture
	var rare := theme.get_stylebox("panel", "ItemSlotRare") as StyleBoxTexture
	assert_float((mythic.texture as AtlasTexture).region.position.x).is_equal(0.0)
	assert_float((rare.texture as AtlasTexture).region.position.x).is_equal(22.0 * 64.0)


# --- Stacked screens ----------------------------------------------------------------------------

func test_a_screen_opened_on_top_draws_above_the_screen_beneath() -> void:
	# Playtest 2026-11-02: battle spoils opened under the combat HUD, which raises its own
	# layers (battle_interface z 4, unit plate z 6 on top of that).
	var beneath := UIManager.open(load("res://ui/screens/journal.tscn") as PackedScene)
	var raised := Control.new()
	raised.z_index = 10
	beneath.add_child(raised)
	var loot := UIManager.open(UIManager.LOOT_PANEL) as LootPanel
	loot.configure("BATTLE SPOILS", [{"item_id": ItemIds.CONSUMABLES_HEARTHLOAF, "quantity": 1}] as Array[Dictionary])
	await await_idle_frame()

	assert_int(_absolute_z(loot)).is_greater(_absolute_z(raised))
	assert_int(_absolute_z(UIManager.get_node("RewardReveal") as CanvasItem)).is_greater(_absolute_z(raised))
	# The spoils cover what is beneath instead of mixing with it.
	assert_object(loot.find_child("Backdrop", false, false)).is_not_null()
	await UIManager.close_all()


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


func _draggable_for(grid: Node, item: InventoryItem) -> Control:
	for node: Node in grid.find_children("*", "Control", true, false):
		if node.get_script() == preload("res://addons/gloot/ui/ctrl_draggable_inventory_item.gd") and node.get("item") == item:
			return node as Control
	fail("no draggable control for %s" % item.get_title())
	return null


## The boot flow adds the main menu to the root after the runner's scene, where it would take
## the mouse; UIManager puts a real screen above everything beneath it.
func _on_top(scene: Node) -> Node:
	scene.get_parent().move_child(scene, -1)
	return scene


## A real mouse drag through the viewport: press, travel past the drag threshold, release.
## Built by hand because the runner's synthetic release lands at (0, 0) headless.
func _drag(runner: GdUnitSceneRunner, from: Vector2, to: Vector2) -> void:
	await _mouse(runner, _motion(from, from, 0))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = from
	press.global_position = from
	await _mouse(runner, press)
	for step: int in range(1, 9):
		var at := from.lerp(to, step / 8.0)
		await _mouse(runner, _motion(at, from.lerp(to, (step - 1) / 8.0), MOUSE_BUTTON_MASK_LEFT))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	release.global_position = to
	await _mouse(runner, release)


## Godot starts a drag from accumulated `relative` motion, so each step carries it.
func _motion(at: Vector2, previous: Vector2, mask: int) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.relative = at - previous
	motion.button_mask = mask
	return motion


func _mouse(runner: GdUnitSceneRunner, event: InputEventMouse) -> void:
	Input.warp_mouse(event.position)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await runner.await_input_processed()


## The z a canvas item draws at within its layer: its own z plus every relative parent's.
func _absolute_z(item: CanvasItem) -> int:
	var z := 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z
