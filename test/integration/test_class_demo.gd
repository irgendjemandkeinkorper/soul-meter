extends GdUnitTestSuite
## The 5v5 class demo launcher (combat polish, owner 2026-11-02: "a demo of 5 v 5 battle with 1
## of each class"; "you lead 5, AI runs 5"). The title opens it on a save sandbox and the title
## takes it back; in the arena the AI five open as a set-piece, each in its member's body.

const TITLE_STATE_PATH := "StateChart/Root/Menus/Title"
const CHARGEN_STATE_PATH := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE_PATH := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE_PATH := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE_PATH := "StateChart/Root/Playing/Active"
const PAUSED_STATE_PATH := "StateChart/Root/Playing/Paused"

var _game_state_before: Dictionary = {}
var _loading_handler_was_connected := false
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	if GameFlow.class_demo_active():
		GameFlow._end_class_demo()
	EncounterCatalog.clear_debug_encounter(ClassDemo.ENCOUNTER_ID)
	GameState.from_dict(_game_state_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	UIManager.close_all()


func test_the_title_opens_the_demo_on_a_sandbox_and_the_title_takes_it_back() -> void:
	await _return_to_title()
	_hold_loading()
	var party_before := _party_ids()
	assert_bool(GameFlow.start_class_demo()).is_true()
	await get_tree().process_frame

	assert_bool(_state_is_active(LOADING_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.CLASS_DEMO_SCENE)
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_true()
	assert_bool(SaveGame.save()).override_failure_message("the sandbox must refuse saves").is_false()
	var classes: Array[String] = []
	for member: PartyMember in GameState.party:
		classes.append(member.class_id)
	assert_array(classes).is_equal(ClassDemo.PLAYER_SIDE)
	assert_str(GameState.party[0].id).is_equal(GameState.PROTAGONIST_ID)
	assert_int((EncounterCatalog.definition(ClassDemo.ENCOUNTER_ID).get("enemies", []) as Array).size()).is_equal(5)
	assert_bool(GameFlow.start_class_demo()).override_failure_message("one demo at a time").is_false()

	await _return_to_title()
	_release_loading()
	assert_bool(GameFlow.class_demo_active()).is_false()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()
	assert_array(_party_ids()).is_equal(party_before)
	assert_dict(EncounterCatalog.definition(ClassDemo.ENCOUNTER_ID)).is_empty()


## Owner 2026-11-02: a debug shortcut to walk the lived-in Kesselford. Same sandbox and player
## five as the demo, Kesselford at the wayhouse, no fight registered; the title takes it back.
func test_the_title_opens_a_kesselford_walk_on_a_sandbox_and_the_title_takes_it_back() -> void:
	await _return_to_title()
	_hold_loading()
	var party_before := _party_ids()
	assert_bool(GameFlow.start_kesselford_walk()).is_true()
	await get_tree().process_frame

	assert_bool(_state_is_active(LOADING_STATE_PATH)).is_true()
	assert_str(GameFlow._target_scene).is_equal(GameFlow.KESSELFORD_WALK_SCENE)
	assert_str(String(SaveGame.pending_spawn_id)).is_equal(String(GameFlow.KESSELFORD_WALK_SPAWN))
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_true()
	assert_bool(SaveGame.save()).override_failure_message("the sandbox must refuse saves").is_false()
	var classes: Array[String] = []
	for member: PartyMember in GameState.party:
		classes.append(member.class_id)
	assert_array(classes).is_equal(ClassDemo.PLAYER_SIDE)
	assert_dict(EncounterCatalog.definition(ClassDemo.ENCOUNTER_ID)).override_failure_message("a walk opens no fight").is_empty()
	assert_bool(GameFlow._class_demo_pending).is_false()
	assert_bool(GameFlow.start_class_demo()).override_failure_message("one sandbox at a time").is_false()

	await _return_to_title()
	_release_loading()
	assert_bool(GameFlow.class_demo_active()).is_false()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()
	assert_array(_party_ids()).is_equal(party_before)


func test_the_title_shows_the_walk_button_in_debug_builds() -> void:
	var menu: Node = auto_free((load(GameFlow.MAIN_MENU_SCENE) as PackedScene).instantiate())
	add_child(menu)
	await get_tree().process_frame
	assert_object(menu.find_child("WalkKesselfordButton", true, false)).is_not_null()
	assert_object(menu.find_child("ClassDemoButton", true, false)).is_not_null()


func test_the_demo_only_opens_from_the_title() -> void:
	await _return_to_title()
	_hold_loading()
	GameFlow.send_event("start_chargen")
	await get_tree().process_frame
	assert_bool(GameFlow.start_class_demo()).is_false()
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()
	await _return_to_title()
	_release_loading()


## The arena seats all ten; each AI enemy is a whole member of its class, and its body wears
## that member's likeness, so the five enemy bodies are five different figures.
func test_the_arena_seats_ten_and_each_enemy_wears_its_members_body() -> void:
	assert_bool(ClassDemo.prepare()).is_true()
	var scene: Node = (load(GameFlow.CLASS_DEMO_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	# Arrive where production puts the lead (GameFlow.CLASS_DEMO_SPAWN).
	SaveGame.pending_spawn_id = GameFlow.CLASS_DEMO_SPAWN
	SaveGame.has_pending_player_position = false
	SaveGame.apply_pending_location(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	assert_object(field).is_not_null()

	var opened := Battle.start_set_piece(field, ClassDemo.ENCOUNTER_ID)
	assert_bool(bool(opened.get("allowed", false))).override_failure_message(str(opened)).is_true()
	assert_int(Battle.allies.size()).is_equal(5)
	assert_int(Battle.enemies.size()).is_equal(5)
	var model := Battle.controller.battlefield as GridBattlefieldModel
	var cells := {}
	for actor: BattleActor in Battle.allies + Battle.enemies:
		var cell: Variant = model.cell_of(actor)
		assert_bool(cell is Vector2i).override_failure_message("%s unseated" % actor.display_name).is_true()
		cells[cell] = true
	assert_int(cells.size()).override_failure_message("ten actors, ten cells").is_equal(10)

	var enemy_classes: Array[String] = []
	for enemy: BattleActor in Battle.enemies:
		assert_object(enemy.source_member).is_not_null()
		enemy_classes.append(enemy.source_member.class_id)
	assert_array(enemy_classes).is_equal(ClassDemo.AI_SIDE)
	var bodies := {}
	for hostile: Hostile in Battle._spawned_hostiles:
		assert_bool(UnitArt.has_unit(String(hostile.unit_id))).override_failure_message(String(hostile.unit_id)).is_true()
		bodies[hostile.unit_id] = true
	assert_int(bodies.size()).is_equal(5)
	scene.queue_free()


func _party_ids() -> Array[String]:
	var ids: Array[String] = []
	for member: PartyMember in GameState.party:
		ids.append(member.id)
	return ids


## Loading would really load the arena; these flow tests only need the chart to reach it.
func _hold_loading() -> void:
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)


func _release_loading() -> void:
	var loading_state := GameFlow.get_node(LOADING_STATE_PATH)
	if _loading_handler_was_connected and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	_loading_handler_was_connected = false


func _state_is_active(path: String) -> bool:
	var state := GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))


func _return_to_title() -> void:
	if _state_is_active(TITLE_STATE_PATH):
		return
	if _state_is_active(CHARGEN_STATE_PATH):
		GameFlow.send_event("new_game")
		await get_tree().process_frame
	if _state_is_active(INTRO_STATE_PATH):
		GameFlow.send_event("intro_done")
		await get_tree().process_frame
	if _state_is_active(LOADING_STATE_PATH):
		GameFlow.send_event("level_ready")
		await get_tree().process_frame
	if _state_is_active(ACTIVE_STATE_PATH):
		GameFlow.send_event("pause")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE_PATH):
		GameFlow.send_event("to_main_menu")
		await get_tree().process_frame
