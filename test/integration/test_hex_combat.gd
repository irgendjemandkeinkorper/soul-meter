extends GdUnitTestSuite
## Hex grid H2 (owner item 34; docs/design/hex-grid-plan-2026-11-03.md): the 5v5 class demo
## fought on hexes. With `soul_meter/grid/hex` on, the arena's field grid, the battlefield model
## and KitAI all speak hexes; the plan's proof is the demo over ten seeds, every fight played to
## an end by both AIs, with the dice still deciding it. The setting is restored after each test.

const SEEDS: Array[int] = [11, 22, 33, 44, 55, 66, 77, 88, 99, 110]
## The farthest a demo seat stands from the player. A line that a wall closes on one side grows
## on the other only (five bodies reach 26 hexes past Kesselford's Wayhouse); the broken fallback
## this guards against put the lines about 170 hexes apart.
const MAX_SEAT_HEXES := 40

var _game_state_before: Dictionary = {}
var _target_scene_before := ""
var _target_spawn_before: StringName = &"default"
var _setting_before: Variant


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	if GameFlow.class_demo_active():
		GameFlow._end_class_demo()
	EncounterCatalog.clear_debug_encounter(ClassDemo.ENCOUNTER_ID)
	FightDice.forced_seed = -1
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)
	GameState.from_dict(_game_state_before)
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	UIManager.close_all()


func test_the_demo_plays_itself_on_hexes_over_ten_seeds() -> void:
	var results := {}
	var logs := {}
	for fight_seed: int in SEEDS:
		var fight := await _autoplayed_fight(fight_seed)
		assert_bool(bool(fight["ended"])).override_failure_message("seed %d did not end: %s" % [fight_seed, fight]).is_true()
		assert_int(int(fight["player_orders"])).override_failure_message("autoplay gave a turn back").is_equal(0)
		assert_int((fight["log"] as Array).size()).is_greater(10)
		assert_bool(bool(fight["hex"])).override_failure_message("the fight was not on hexes").is_true()
		assert_bool(bool(fight["seats_ok"])).override_failure_message("seed %d seats: %s" % [fight_seed, fight["seats"]]).is_true()
		assert_int(int(fight["moves"])).override_failure_message("nobody walked a hex path").is_greater(0)
		results[fight["result"]] = int(results.get(fight["result"], 0)) + 1
		logs[str(fight["log"])] = true
		print("HEXDEMO seed=%d result=%s beats=%d moves=%d hexes_walked=%d ms=%d" % [
			fight_seed, fight["result"], (fight["log"] as Array).size(), fight["moves"], fight["hexes_walked"], fight["ms"],
		])
	print("HEXDEMO results %s" % results)
	# The dice still decide the fight: ten seeds never replay one fight.
	assert_int(logs.size()).is_equal(SEEDS.size())


## One whole demo fight under autoplay on hexes, with the dice pinned to `fight_seed`.
func _autoplayed_fight(fight_seed: int) -> Dictionary:
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
	var player_cell: Vector2i = field.party_cells()[0]
	var started := Time.get_ticks_msec()
	var opened := Battle.start_set_piece(field, ClassDemo.ENCOUNTER_ID)
	assert_bool(bool(opened.get("allowed", false))).override_failure_message(str(opened)).is_true()
	var controller := Battle.controller
	var model := controller.battlefield as GridBattlefieldModel
	var grid := field.iso_grid()
	# Ten distinct seats, each an open hex of the field.
	var seats := {}
	var seats_ok := true
	for actor: BattleActor in controller.allies + controller.enemies:
		var at: Variant = model.cell_of(actor)
		if not (at is Vector2i) or seats.has(at) or not grid.is_in_bounds(at as Vector2i):
			seats_ok = false
		# Both lines stand by the player. A seating that fails falls back to the model's default
		# seats at the grid origin, far off Kesselford (what the painted walls first caused).
		elif GridMetric.distance(at as Vector2i, player_cell) > MAX_SEAT_HEXES or grid.is_wall(at as Vector2i):
			seats_ok = false
		seats[at] = actor.combat_id
	var log: Array[String] = []
	var walked := {"moves": 0, "hexes": 0}
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type == &"action_resolved":
			var resolution: Dictionary = event.data.get("resolution", {})
			log.append("%s>%s %s d%d h%s c%s" % [
				event.actor_id, event.target_id, event.data.get("action_id", ""),
				int(event.data.get("damage", 0)), resolution.get("hit", "-"), resolution.get("critical", "-"),
			])
			var path: Variant = event.data.get("path_cells", [])
			if path is Array and (path as Array).size() > 1:
				walked["moves"] = int(walked["moves"]) + 1
				walked["hexes"] = int(walked["hexes"]) + (path as Array).size() - 1
	)
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
		"hex": grid.hex_mode and model._grid == grid,
		"seats": seats, "seats_ok": seats_ok,
		"moves": walked["moves"], "hexes_walked": walked["hexes"],
		"ms": Time.get_ticks_msec() - started,
	}
	if Battle.session_active:
		Battle._end_session(null)
	scene.queue_free()
	await get_tree().process_frame
	EncounterCatalog.clear_debug_encounter(ClassDemo.ENCOUNTER_ID)
	GameState.from_dict(world_before)
	return result
