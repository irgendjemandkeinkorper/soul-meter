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
const BATTLE_STATE_PATH := "StateChart/Root/Playing/Battle"

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
	FightDice.forced_seed = -1
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


## 2026-11-04: with the arrival beside the Wayhouse, the enemy line's first seat fell inside the
## walls, the seating failed, and the demo fought from the model's default seats off the map (the
## hex suite grew past 7 GB). A set-piece that cannot seat both sides by the party does not open:
## Battle refuses it at once and leaves no session, controller or enemy bodies behind.
##
## Since T1 (2026-11-07) a first seat inside a wall moves to the party's side of it, so the fixture
## no longer walls in that seat: it seals the party inside the ring two steps out, which leaves the
## leader's neighbours (six hexes or eight cells) for ten bodies. The party seats; an enemy cannot.
func test_a_demo_that_cannot_seat_its_ten_does_not_open() -> void:
	assert_bool(ClassDemo.prepare()).is_true()
	var scene: Node = (load(GameFlow.CLASS_DEMO_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	SaveGame.pending_spawn_id = GameFlow.CLASS_DEMO_SPAWN
	SaveGame.has_pending_player_position = false
	SaveGame.apply_pending_location(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	var grid := field.iso_grid()
	var lead: Vector2i = field.party_cells()[0]
	# Seal the party in: every open cell two steps from the leader becomes solid.
	var walled: Array[Vector2i] = []
	for cell: Vector2i in GridMetric.ring(lead, 2):
		if grid.is_in_bounds(cell) and not grid.is_point_solid(cell):
			grid.set_point_solid(cell, true)
			walled.append(cell)
	Battle.ended = true
	Battle.controller = null
	var started := Time.get_ticks_msec()
	var opened := Battle.start_set_piece(field, ClassDemo.ENCOUNTER_ID)
	var took := Time.get_ticks_msec() - started
	for cell: Vector2i in walled:
		grid.set_point_solid(cell, false)

	assert_bool(bool(opened.get("allowed", true))).override_failure_message(str(opened)).is_false()
	assert_str(String(opened.get("blocked_by", ""))).is_equal("seating")
	# The line's first seat or a later enemy's, depending on how many neighbours the party left.
	assert_str(str(opened.get("message", ""))).contains("no open cell near")
	assert_bool(Battle.session_active).is_false()
	assert_bool(Battle.ended).is_true()
	assert_object(Battle.controller).is_null()
	assert_bool(Battle._spawned_hostiles.is_empty()).is_true()
	assert_int(took).override_failure_message("refused in %d ms" % took).is_less(2000)
	scene.queue_free()


## Owner 2026-11-02: "I'd like the 5v5 demo to be fully ai automated and it shouldn't be a
## predetermined outcome." KitAI plays both fives to an end; a fight's seed replays it exactly,
## and another seed plays it differently (hits, dodges and criticals land elsewhere).
func test_the_demo_plays_itself_and_fresh_dice_change_the_fight() -> void:
	var first := await _autoplayed_fight(101)
	var replay := await _autoplayed_fight(101)
	var other := await _autoplayed_fight(202)
	print("DEMO 101: %s, %d beats; 202: %s, %d beats" % [first["result"], first["log"].size(), other["result"], other["log"].size()])
	for fight: Dictionary in [first, other]:
		assert_bool(bool(fight["ended"])).override_failure_message("the fight must play to an end").is_true()
		assert_int((fight["log"] as Array).size()).is_greater(10)
		assert_int(int(fight["player_orders"])).override_failure_message("autoplay gives no player turn back").is_equal(0)
	assert_array(replay["log"]).is_equal(first["log"])
	assert_array(other["log"]).is_not_equal(first["log"])


## The real path: the title opens the demo straight into the fight (owner 2026-11-02, item 33:
## no deployment screens on a map), and the HUD's autopilot plays the party's turns with no
## input at all, at the presentation's pace.
func test_the_title_opens_the_demo_straight_into_a_fight_that_plays_itself() -> void:
	await _return_to_title()
	assert_bool(GameFlow.start_class_demo()).is_true()
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline and not (Battle.session_active and _state_is_active(BATTLE_STATE_PATH)):
		await get_tree().process_frame
	assert_bool(_state_is_active(BATTLE_STATE_PATH)).override_failure_message("the fight must open in place").is_true()
	assert_object(UIManager.get_node_or_null("Deployment")).override_failure_message("no deployment screen").is_null()
	var hud: BattleInterface = null
	while Time.get_ticks_msec() < deadline and hud == null:
		hud = get_tree().root.find_child("BattleInterface", true, false) as BattleInterface
		await get_tree().process_frame
	assert_object(hud).is_not_null()
	assert_bool(hud.autoplaying()).is_true()
	assert_bool(hud.end_turn_allowed()).override_failure_message("the player has no orders to give").is_false()
	var party_ids := {}
	for ally: BattleActor in Battle.allies:
		party_ids[ally.combat_id] = true
	var party_acts: Array[String] = []
	Battle.controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type == &"action_resolved" and party_ids.has(event.actor_id):
			party_acts.append(str(event.data.get("action_id", ""))))
	deadline = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < deadline and party_acts.size() < 4 and not Battle.ended:
		await get_tree().process_frame
	print("AUTOPILOT party acts: ", party_acts)
	assert_int(party_acts.size()).override_failure_message("the party must act on its own").is_greater_equal(4)
	# Watching, no tile reads as armed or pressable.
	var bar := hud.combat_bar
	if bar != null and not Battle.ended:
		await get_tree().process_frame
		for button: Button in bar.hotbar_buttons():
			assert_bool(button.disabled).override_failure_message("%s is pressable while watching" % button.text).is_true()
			assert_str(button.theme_type_variation).override_failure_message("%s reads as armed while watching" % button.text).is_equal("HudCommandTile")
	await _return_to_title()


func test_fresh_dice_are_drawn_unless_a_test_pins_them() -> void:
	FightDice.forced_seed = 7
	assert_int(FightDice.draw()).is_equal(7)
	FightDice.forced_seed = -1
	var fixed := OS.get_environment("SOUL_METER_FIXED_DICE")
	OS.set_environment("SOUL_METER_FIXED_DICE", "1")
	assert_int(FightDice.draw()).is_equal(0)
	OS.set_environment("SOUL_METER_FIXED_DICE", "0")
	var drawn := {}
	for i in 6:
		drawn[FightDice.draw()] = true
	OS.set_environment("SOUL_METER_FIXED_DICE", fixed)
	assert_bool(drawn.has(0)).is_false()
	assert_int(drawn.size()).is_greater(4)


## One whole demo fight under autoplay, with the dice pinned to `fight_seed`: what resolved, in
## order, and how it ended. `player_orders` counts ally turns autoplay handed back unplayed.
func _autoplayed_fight(fight_seed: int) -> Dictionary:
	# Each fight starts from the same world (the Soul Gauge a cast spends lives in GameState).
	var world_before := GameState.to_dict().duplicate(true)
	FightDice.forced_seed = fight_seed
	assert_bool(ClassDemo.prepare()).is_true()
	var scene: Node = (load(GameFlow.CLASS_DEMO_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	SaveGame.pending_spawn_id = GameFlow.CLASS_DEMO_SPAWN
	SaveGame.has_pending_player_position = false
	SaveGame.apply_pending_location(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	var log: Array[String] = []
	var opened := Battle.start_set_piece(field, ClassDemo.ENCOUNTER_ID)
	assert_bool(bool(opened.get("allowed", false))).override_failure_message(str(opened)).is_true()
	var controller := Battle.controller
	assert_bool(controller.autoplay_allies).is_true()
	assert_int(controller.fight_seed).is_equal(fight_seed)
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type == &"action_resolved":
			var resolution: Dictionary = event.data.get("resolution", {})
			log.append("%s>%s %s d%d h%s c%s" % [
				event.actor_id, event.target_id, event.data.get("action_id", ""),
				int(event.data.get("damage", 0)), resolution.get("hit", "-"), resolution.get("critical", "-"),
			]))
	var player_orders := 0
	var steps := 0
	while not Battle.ended and steps < 4000:
		if not controller.autoplay_step():
			player_orders += 1
			break
		steps += 1
	var result := {
		"ended": Battle.ended, "log": log, "player_orders": player_orders,
		"result": BattleResult.State.keys()[Battle.last_result.state] if Battle.last_result != null else "?",
	}
	if Battle.session_active:
		Battle._end_session(null)
	scene.queue_free()
	await get_tree().process_frame
	EncounterCatalog.clear_debug_encounter(ClassDemo.ENCOUNTER_ID)
	GameState.from_dict(world_before)
	return result


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
	# Mid-fight, as a player would: pause (Esc) out of the battle, then the main menu.
	if _state_is_active(ACTIVE_STATE_PATH) or _state_is_active(BATTLE_STATE_PATH):
		GameFlow.send_event("pause")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE_PATH):
		GameFlow.send_event("to_main_menu")
		await get_tree().process_frame
