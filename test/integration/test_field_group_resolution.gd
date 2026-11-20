extends GdUnitTestSuite
## #652 gap 1: an authored group fought on the field keeps its encounter's resolution routes.
##
## Since the Bloodbellow became a field `Hostile` (#281 D4, `d06a2ab8`), its fight is an ambient
## session with no encounter definition, so "Speak Its Muster-Name" and "Release the Bound
## Soldier" never loaded and the muster could only end `slain`. These cases pin the repair: the
## group's context actions join the session with the group, keep their authored gates, and a
## resolution resolves that group with its own outcome, flags, message and ledger entry.

const TEST_ROOM_SCENE := "res://world/test_room.tscn"
const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"
const MUSTER := &"dorthkor-muster"
const BLOODBELLOW := &"mustered-bloodbellow"
const RELEASE := &"release-bound-soldier"
const SPEAK_NAME := &"speak-muster-name"

var _game_state_before: Dictionary
var _reputation_before: Dictionary


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	# A hostile whose group is already beaten retires itself in `_ready`.
	GameState.set_flag(EncounterCatalog.defeated_flag(MUSTER), false)
	GameState.set_flag("dorthkor_muster_outcome", "")


func after_test() -> void:
	# Battle is an autoload; a suite that leaves a session live poisons every suite after it.
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	GameState.from_dict(_game_state_before)
	Reputation.from_dict(_reputation_before)


func _field() -> FieldMap:
	var scene: Node = (load(TEST_ROOM_SCENE) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	return scene.find_child("FieldMap", true, false) as FieldMap


func _hostile(field: FieldMap, unit_id: StringName, group_id: StringName) -> Hostile:
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = String(unit_id).to_pascal_case()
	hostile.unit_id = unit_id
	hostile.group_id = group_id
	hostile.realert_cooldown = 0.0
	field.get_parent().add_child(hostile)
	hostile.global_position = field.iso_grid().cell_to_world(
		field.iso_grid().cell_at_square(Vector2i(30, 30))
	)
	hostile.sync_cell()
	return hostile


func _open_muster_session() -> Hostile:
	var field := await _field()
	var muster := _hostile(field, BLOODBELLOW, MUSTER)
	var opened := Battle.start_session(field, muster)
	assert_bool(bool(opened.get("allowed", false))).override_failure_message(str(opened)).is_true()
	# The routes are what is under test, not survival: nobody falls while the clock runs.
	for ally: BattleActor in Battle.allies:
		ally.max_hp = 999
		ally.hp = 999
	return muster


func _action_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for action: CombatAction in Battle.available_actions():
		ids.append(action.id)
	return ids


## Guards (or ends the turn) until the party holds the clock after at least `rounds` enemy turns.
func _wait_for_enemy_rounds(rounds: int, guard: int = 200) -> bool:
	var steps := 0
	while steps < guard and not Battle.ended and Battle.controller != null:
		steps += 1
		var ally_turn := Battle.controller.state == CombatController.State.ALLY_TURN
		if ally_turn and Battle.enemy_rounds >= rounds:
			return true
		if ally_turn:
			var guarded: Dictionary = Battle.controller.submit_action(&"guard")
			if not bool(guarded.get("allowed", false)):
				Battle.controller.end_turn()
		else:
			Battle.controller.end_turn()
	fail("no ally turn after %d enemy rounds within %d steps (ended=%s, rounds=%d)" % [
		rounds, guard, Battle.ended, Battle.enemy_rounds
	])
	return false


func test_an_authored_groups_routes_join_its_field_session() -> void:
	await _open_muster_session()
	var ids := _action_ids()
	assert_array(ids).contains([SPEAK_NAME, RELEASE])
	assert_object(Battle.controller.action_by_id(RELEASE)).is_not_null()
	assert_object(Battle.controller.action_by_id(SPEAK_NAME)).is_not_null()
	# Each route appears once, however often the hotbar asks.
	assert_int(ids.count(RELEASE)).is_equal(1)
	assert_int(_action_ids().count(RELEASE)).is_equal(1)


func test_a_group_without_routes_adds_none() -> void:
	GameState.set_flag(EncounterCatalog.defeated_flag(&"bog-wight"), false)
	var field := await _field()
	var wight := _hostile(field, &"bog-wight", &"bog-wight")
	assert_bool(bool(Battle.start_session(field, wight).get("allowed", false))).is_true()
	for action: CombatAction in Battle.available_actions():
		assert_int(action.kind).override_failure_message(
			"%s is a resolution action in a fight with no authored routes" % action.id
		).is_not_equal(CombatAction.Kind.RESOLUTION)


func test_release_keeps_its_authored_gate_until_an_enemy_round_passes() -> void:
	await _open_muster_session()
	assert_int(Battle.controller.state).is_equal(CombatController.State.ALLY_TURN)
	# Under CT the foe can act before the party's first turn, which already counts as the enemy
	# round the gate asks for. Reset the counter to see the gate itself.
	Battle.enemy_rounds = 0
	var refusal := Battle.action_refusal(Battle.controller.action_by_id(RELEASE))
	assert_bool(bool(refusal.get("allowed", true))).is_false()
	assert_str(str(refusal.get("blocked_by", ""))).is_equal("enemy_rounds")
	assert_str(str(refusal.get("message", ""))).contains("Survive one enemy round")


func test_releasing_the_bound_soldier_resolves_the_muster_as_released() -> void:
	var muster := await _open_muster_session()
	if not _wait_for_enemy_rounds(1):
		return
	assert_int(Battle.balance).override_failure_message(
		"guarding moved Balance out of the release window"
	).is_between(-20, 20)
	var events_before := Reputation.event_count()

	assert_bool(Battle.use_action(RELEASE)).override_failure_message(
		str(Battle.action_refusal(Battle.controller.action_by_id(RELEASE)))
	).is_true()

	assert_bool(Battle.ended).is_true()
	assert_bool(Battle.session_active).is_false()
	var result := Battle.last_result
	assert_int(result.state).is_equal(BattleResult.State.VICTORY)
	assert_str(String(result.outcome_id)).is_equal("released")
	assert_str(String(result.encounter_id)).is_equal(String(MUSTER))
	assert_str(result.message).is_equal(
		str(EncounterCatalog.outcome(MUSTER, &"released").get("message", ""))
	)
	assert_str(str(GameState.get_flag("dorthkor_muster_outcome", ""))).is_equal("released")
	assert_bool(GameState.flag_is_true(EncounterCatalog.defeated_flag(MUSTER))).is_true()
	assert_int(Reputation.event_count()).override_failure_message(
		"one ledger entry for the resolved group"
	).is_equal(events_before + 1)
	assert_str(Reputation.history(1)[0].faction).is_equal("ironbrand-sentinels")
	# The binding is broken: the empty armor stays down instead of standing back up at IDLE.
	assert_int(muster.state).is_equal(Hostile.State.DOWNED)
