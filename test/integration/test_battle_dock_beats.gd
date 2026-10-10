extends GdUnitTestSuite
## #473: grid combat leftovers on the battle screen.
##   1. a cell battlefield has no zone MOVE cards (moves are clicks on cells); zones keep them;
##   3. the dock, unit plate and CT strip follow the field's presented beats, and ENCOUNTER
##      RESOLVED waits for the field to present the finishing blow.

const TEST_ROOM_SCENE := "res://world/test_room.tscn"
const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"

var _game_state_before: Dictionary
var _saved_party: Array[PartyMember] = []


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_saved_party = GameState.party.duplicate()


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._combat_history.clear()
	Battle.ended = true
	GameState.from_dict(_game_state_before)
	GameState.party.clear()
	for member: PartyMember in _saved_party:
		GameState.party.append(member)


func test_grid_battlefield_hides_the_zone_move_cards() -> void:
	var session := await _grid_session("MoveCardWight")
	var screen: Screen = session.screen
	var buttons: Array = screen.get("_action_buttons")
	var actions := Battle.available_actions()
	var hidden := 0
	for index: int in actions.size():
		var button := buttons[index] as Button
		if actions[index].kind == CombatAction.Kind.MOVE:
			hidden += 1
			assert_bool(button.visible).override_failure_message(
				"%s must not show on a grid battlefield" % button.text
			).is_false()
		else:
			assert_bool(button.visible).is_true()
	assert_int(hidden).override_failure_message("FRONT/BACK/FLANK and MOVE").is_equal(4)
	await _close(session)


func test_zone_battlefield_keeps_its_zone_move_cards() -> void:
	GameState.party.clear()
	var member := PartyMember.new()
	member.display_name = "Zone Tester"
	member.hp = 20
	member.max_hp = 20
	GameState.party.append(member)
	var enemy := BattleActor.new()
	enemy.display_name = "Zone Target"
	enemy.hp = 30
	enemy.max_hp = 30
	Battle.start(enemy)
	assert_bool(Battle.controller.battlefield.capabilities().get("cells", false)).is_false()
	var screen := load("res://ui/screens/battle.tscn").instantiate() as Screen
	add_child(screen)
	await get_tree().process_frame
	var buttons: Array = screen.get("_action_buttons")
	var actions := Battle.available_actions()
	var zone_cards := 0
	for index: int in actions.size():
		if actions[index].kind == CombatAction.Kind.MOVE and not actions[index].destination.is_empty():
			zone_cards += 1
			assert_bool((buttons[index] as Button).visible).is_true()
	assert_int(zone_cards).is_equal(3)
	screen.free()


func test_dock_plate_and_ct_strip_follow_the_presented_enemy_phase() -> void:
	# The demo company is the one the Bog Wight can actually wound (the rendered #281 pack).
	GameState._seed_demo_data()
	var session := await _grid_session("BeatWight", Vector2i(1, 0))
	var screen: Screen = session.screen
	var stage := (screen.get("_battle_interface") as BattleInterface).stage
	var plate := (screen.get("_battle_interface") as BattleInterface).active_unit_plate
	var timeline := (screen.get("_battle_interface") as BattleInterface).turn_timeline
	var ally: BattleActor = Battle.allies[0]
	# Fixture: combat rolls are seeded by the clock tick, so this seating misses every time.
	# A keen, strong wight lands its strikes and wounds, giving the dock an end state it could
	# read ahead of the field. Presentation is what is under test, not the to-hit roll.
	var wight := (session.hostile as Hostile).battle_actor()
	wight.attributes["alacrity"] = 40
	wight.attack = 30
	var checked := false
	for _attempt: int in 12:
		await _until_presented(stage)
		if Battle.ended:
			break
		if Battle.controller.state != CombatController.State.ALLY_TURN:
			Battle.controller.end_turn()
			continue
		var hp_before := ally.hp
		Battle.controller.end_turn()
		if ally.hp == hp_before or Battle.ended:
			continue
		await get_tree().process_frame
		assert_bool(stage.is_presenting_beats()).is_true()
		var shown := _presented_snapshot(stage)
		var shown_hp := int(_row(shown, ally.combat_id).get("hp", -1))
		assert_int(shown_hp).override_failure_message(
			"the field has not presented the hit yet"
		).is_equal(hp_before)
		assert_str(_party_hp_text(screen, ally)).is_equal("HP %d / %d" % [hp_before, ally.max_hp])
		var active_row := _row(shown, StringName(str(shown.get("active_actor_id", ""))))
		assert_int(int(plate.unit_snapshot().get("hp", -1))).is_equal(int(active_row.get("hp", -2)))
		assert_str(plate.ct_label.text).is_equal(plate._ct_line(active_row))
		assert_int(timeline._snapshot_order.size()).is_equal((shown.get("turn_order", []) as Array).size())
		if not timeline._snapshot_order.is_empty():
			assert_int(int(timeline._snapshot_order[0].get("charge", -1))) \
				.is_equal(int((shown.get("turn_order", []) as Array)[0].get("charge", -2)))
		await _until_presented(stage)
		await get_tree().process_frame
		assert_str(_party_hp_text(screen, ally)).is_equal("HP %d / %d" % [ally.hp, ally.max_hp])
		var live_active := Battle.controller.snapshot()
		assert_int(int(plate.unit_snapshot().get("hp", -1))).is_equal(
			int(_row(live_active, StringName(str(live_active.get("active_actor_id", "")))).get("hp", -2))
		)
		checked = true
		break
	assert_bool(checked).override_failure_message("no enemy hit landed in 12 enemy phases").is_true()
	await _close(session)


func test_encounter_resolved_waits_for_the_presented_finishing_blow() -> void:
	var session := await _grid_session("KoWight", Vector2i(1, 0))
	var screen: Screen = session.screen
	var stage := (screen.get("_battle_interface") as BattleInterface).stage
	var foe := (session.hostile as Hostile).battle_actor()
	foe.hp = 1
	for _attempt: int in 12:
		await _until_presented(stage)
		if Battle.ended:
			break
		if Battle.controller.state != CombatController.State.ALLY_TURN:
			Battle.controller.end_turn()
			continue
		var result := Battle.controller.submit_action(&"strike", foe)
		if not foe.is_alive():
			break
		if not bool(result.get("allowed", false)) or foe.is_alive():
			Battle.controller.end_turn()
	assert_bool(Battle.ended).is_true()
	assert_bool(foe.is_alive()).is_false()
	await get_tree().process_frame
	assert_bool(stage.is_presenting_beats()).is_true()
	assert_bool(screen.call("outcome_shown")).override_failure_message(
		"ENCOUNTER RESOLVED must wait for the field to present the finishing blow"
	).is_false()
	await _until_presented(stage)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(screen.call("outcome_shown")).is_true()
	var outcome := screen.get("_outcome_box") as VBoxContainer
	assert_str((outcome.get_child(0) as Label).text).is_equal("ENCOUNTER RESOLVED")
	await _close(session)


func _grid_session(hostile_name: String, offset: Vector2i = Vector2i(4, 0)) -> Dictionary:
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	var anchor := field.party_cells()[0]
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = hostile_name
	hostile.unit_id = &"bog-wight"
	hostile.realert_cooldown = 0.0
	field.get_parent().add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(anchor + offset)
	hostile.sync_cell()
	assert_bool(Battle.start_session(field, hostile).get("allowed", false)).is_true()
	assert_bool(Battle.controller.battlefield.capabilities().get("cells", false)).is_true()
	var screen := load("res://ui/screens/battle.tscn").instantiate() as Screen
	add_child(screen)
	await get_tree().process_frame
	return {"scene": scene, "field": field, "hostile": hostile, "screen": screen}


func _close(session: Dictionary) -> void:
	(session.screen as Node).free()
	if Battle.session_active:
		Battle._end_session(null)
	(session.scene as Node).queue_free()
	await get_tree().process_frame


func _until_presented(stage: BattleStageRegion, limit_ms: int = 8000) -> void:
	var deadline := Time.get_ticks_msec() + limit_ms
	while Time.get_ticks_msec() < deadline and stage.is_presenting_beats():
		await get_tree().process_frame


func _presented_snapshot(stage: BattleStageRegion) -> Dictionary:
	var event := stage.presented_event()
	return event.data.get("snapshot", {}) if event != null else {}


func _row(snapshot: Dictionary, id: StringName) -> Dictionary:
	for side: String in ["allies", "enemies"]:
		for row: Dictionary in snapshot.get(side, []):
			if StringName(str(row.get("id", ""))) == id:
				return row
	return {}


## The HP label of `ally`'s dock row (rows follow Battle.allies order).
func _party_hp_text(screen: Screen, ally: BattleActor) -> String:
	var rows := (screen.get("_party_box") as Node).get_children()
	var row := rows[Battle.allies.find(ally)]
	return (row.get_child(2) as Label).text
