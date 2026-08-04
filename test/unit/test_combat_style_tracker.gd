extends GdUnitTestSuite

const TrackerScript := preload("res://globals/combat_style_tracker.gd")
const SaveGameScript := preload("res://globals/save_game.gd")

var tracker: CombatStyleTracker
var ng_plus_before_test: Dictionary
var test_save_paths: Array[String] = []


func before_test() -> void:
	tracker = auto_free(TrackerScript.new())
	ng_plus_before_test = SaveGame.ng_plus.duplicate(true)
	test_save_paths.clear()


func after_test() -> void:
	SaveGame.ng_plus = ng_plus_before_test
	for path: String in test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_each_ratified_scoring_dimension_accrues() -> void:
	_score_all_dimensions()
	var score := tracker.score_breakdown()
	assert_int(score[CombatStyleTracker.VERB_VARIETY]).is_equal(2)
	assert_int(score[CombatStyleTracker.BALANCE_MANAGEMENT]).is_equal(1)
	assert_int(score[CombatStyleTracker.NO_DAMAGE_TURNS]).is_equal(1)
	assert_int(score[CombatStyleTracker.SPEECH_RESOLUTIONS]).is_equal(1)
	assert_int(score[&"total"]).is_equal(5)


func test_battle_finish_adds_points_to_existing_save_game_ng_plus_block() -> void:
	SaveGame.ng_plus = {
		"style_points": 7,
		"purchased_carry_overs": ["keep-renown"],
		"completion_metadata": {"ending": "restore"},
	}
	_score_all_dimensions()
	tracker.consume_event(_event(&"battle_finished", &"", {}, _snapshot(10, 10, 0)))
	assert_int(SaveGame.ng_plus["style_points"]).is_equal(12)
	assert_array(SaveGame.ng_plus["purchased_carry_overs"]).contains("keep-renown")
	assert_str(SaveGame.ng_plus["completion_metadata"]["ending"]).is_equal("restore")


func test_accrued_points_round_trip_through_save_game() -> void:
	_score_all_dimensions()
	var saves = auto_free(SaveGameScript.new())
	add_child(saves)
	var prefix := OS.get_temp_dir().path_join("soul-meter-style-points-%s" % Time.get_ticks_usec())
	saves.save_path = prefix + ".save"
	saves.temp_path = prefix + ".save.tmp"
	saves.backup_path = prefix + ".save.bak"
	test_save_paths = [saves.save_path, saves.temp_path, saves.backup_path]
	saves.ng_plus = tracker.accrue_into({"style_points": 7})

	assert_bool(saves.save()).is_true()
	saves.ng_plus = NGPlus.default_block()
	assert_bool(saves.load_save()).is_true()
	assert_int(saves.ng_plus["style_points"]).is_equal(12)


func _score_all_dimensions() -> void:
	var start := _snapshot(10, 10, 40)
	tracker.consume_event(_event(&"battle_started", &"", {}, start))
	tracker.consume_event(_event(&"round_started", &"", {}, start))
	tracker.consume_event(_event(
		&"action_resolved", &"ally-0", {"verb": CombatAction.Verb.ATTACK}, start
	))
	tracker.consume_event(_event(
		&"action_resolved", &"ally-0", {"verb": CombatAction.Verb.DEFEND}, start
	))
	tracker.consume_event(_event(
		&"balance_changed", &"ally-0", {"balance": 10, "delta": -30}, _snapshot(10, 10, 10)
	))
	tracker.consume_event(_event(
		&"action_resolved",
		&"ally-0",
		{"verb": CombatAction.Verb.SPEECH, "outcome_id": &"released"},
		_snapshot(10, 10, 10)
	))
	tracker.consume_event(_event(&"round_ended", &"", {}, _snapshot(10, 10, 10)))


func _snapshot(hp: int, max_hp: int, balance: int) -> Dictionary:
	return {
		"balance": balance,
		"active_actor_id": &"ally-0",
		"allies": [
			{
				"id": &"ally-0",
				"display_name": "Vex",
				"hp": hp,
				"max_hp": max_hp,
				"ap": 2,
				"max_ap": 4,
				"position": &"front",
				"side": &"ally",
			}
		],
		"enemies": [],
	}


func _event(
	type: StringName, actor_id: StringName, data: Dictionary, snapshot: Dictionary
) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = type
	event.actor_id = actor_id
	event.data = data.duplicate(true)
	event.data["snapshot"] = snapshot.duplicate(true)
	return event
