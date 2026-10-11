extends GdUnitTestSuite
## E4.2 (#346): the `[debug] respawn now` / `[debug] clear slot` console verbs. They act on
## `SaveGame.spawn_director` and the live scene, are `[debug] `-tagged, leave a valid
## `spawn_state`, and do nothing from an unhosted (release) model.

const DevConsoleScript := preload("res://weftlumin/panels/models/dev_console.gd")
## A scene with a `wilderness` location, so `SpawnDirector.live_context()` allows spawns.
const SCENE := "res://world/test_room.tscn"
const TABLE_ID := "verb-fixture"
const SLOT_ID := "hollow-east"
const KEY := "verb-fixture:hollow-east"

var _console: Node
var _root: Node2D
var _previous_scene: Node
var _spawns_before: Dictionary
var _clock_before: Dictionary
var _game_state_before: Dictionary


func before_test() -> void:
	_spawns_before = SaveGame.spawn_director.to_dict()
	_clock_before = WorldClock.to_dict()
	_game_state_before = GameState.to_dict().duplicate(true)
	SaveGame.spawn_director.from_dict({})
	SpawnDirector.set_tables_for_testing({SCENE: [{
		"schema": SpawnDirector.TABLE_SCHEMA, "id": TABLE_ID, "scene_path": SCENE,
		"slots": [{
			"id": SLOT_ID, "anchor": "SpawnSlotHollowEast", "respawn_days": 2,
			"entries": [{"archetype_id": "bog-wight", "weight": 1}], "pack_size": {"min": 3, "max": 3},
		}],
		"caps": {},
	}]})
	_root = Node2D.new()
	_root.name = "SpawnVerbFixture"
	_root.scene_file_path = SCENE
	var anchor := Marker2D.new()
	anchor.name = "SpawnSlotHollowEast"
	anchor.position = Vector2(400, 300)
	_root.add_child(anchor)
	get_tree().root.add_child(_root)
	_previous_scene = get_tree().current_scene
	get_tree().current_scene = _root
	_console = DevConsoleScript.new() as Node
	add_child(_console)
	assert_bool(bool(_console.call("host_in_panel"))).is_true()


func after_test() -> void:
	if _console != null:
		_console.free()
		_console = null
	get_tree().current_scene = _previous_scene if is_instance_valid(_previous_scene) else null
	if is_instance_valid(_root):
		_root.free()
	SpawnDirector.set_tables_for_testing({}, true)
	SaveGame.spawn_director.from_dict(_spawns_before)
	WorldClock.from_dict(_clock_before)
	assert_bool(GameState.from_dict(_game_state_before)).is_true()


func _execute(command: String) -> bool:
	return bool(_console.call("execute_command", command))


func _last() -> String:
	return str((_console.call("last_log_entry") as Dictionary).get("text", ""))


func _hostiles() -> Array[Hostile]:
	var found: Array[Hostile] = []
	for node: Node in _root.find_children("*", "", true, false):
		if node is Hostile and not node.is_queued_for_deletion():
			found.append(node as Hostile)
	return found


func _state() -> Dictionary:
	return SaveGame.spawn_director.slot_state(TABLE_ID, SLOT_ID)


func test_help_lists_both_verbs_debug_tagged() -> void:
	assert_bool(_execute("help")).is_true()
	var tagged := false
	for entry: Dictionary in _console.call("log_entries"):
		var text := str(entry["text"])
		if text.contains("respawn now") and text.contains("clear slot"):
			tagged = text.begins_with(DevConsoleScript.DEBUG_CAUSE_PREFIX) \
				and text.contains(DevConsoleScript.DEBUG_CAUSE_PREFIX + "clear slot")
	assert_bool(tagged).is_true()


func test_respawn_now_rolls_the_slot_at_its_anchor_without_duplicating_survivors() -> void:
	WorldClock.phase_count = 5 * WorldClock.PHASES.size()
	assert_bool(_execute("respawn now %s" % KEY)).is_true()
	assert_bool(DevConsoleScript.is_debug_caused(_last())).is_true()
	assert_str(_last()).contains("spawned 3 × bog-wight as %s:5" % KEY)
	assert_int(_hostiles().size()).is_equal(3)
	assert_int((_state()["members"] as Array).size()).is_equal(3)
	assert_bool(bool(GameState.get_flag(DevConsoleScript.USED_FLAG, false))).is_true()
	# Again on the same day: the old pack leaves the field, the same deterministic roll returns.
	assert_bool(_execute("respawn now %s" % KEY)).is_true()
	assert_int(_hostiles().size()).is_equal(3)
	for hostile: Hostile in _hostiles():
		assert_str(String(hostile.group_id)).is_equal("%s:5" % KEY)
	assert_bool(SpawnDirector.validate_save_data(SaveGame.spawn_director.to_dict())).is_true()


func test_clear_slot_records_a_clear_and_respawn_now_bypasses_the_cadence() -> void:
	WorldClock.phase_count = 7 * WorldClock.PHASES.size()
	assert_bool(_execute("respawn now %s" % KEY)).is_true()
	assert_bool(_execute("clear slot %s" % KEY)).is_true()
	assert_bool(DevConsoleScript.is_debug_caused(_last())).is_true()
	assert_str(_last()).contains("removed 3 hostile(s); cleared on day 7")
	assert_int(_hostiles().size()).is_equal(0)
	assert_array(_state()["members"] as Array).is_empty()
	assert_int(int(_state()["cleared_day"])).is_equal(7)
	# A re-entry the same day leaves the cleared slot empty (respawn_days = 2)...
	assert_int(SaveGame.spawn_director.populate(_root).size()).is_equal(0)
	# ...but the debug verb rolls it now.
	assert_bool(_execute("respawn now %s" % KEY)).is_true()
	assert_int(_hostiles().size()).is_equal(3)
	assert_bool(SpawnDirector.validate_save_data(SaveGame.spawn_director.to_dict())).is_true()
	# The state survives a save round trip.
	var restored := SpawnDirector.new()
	restored.from_dict(JSON.parse_string(JSON.stringify(SaveGame.spawn_director.to_dict())))
	assert_dict(restored.slot_state(TABLE_ID, SLOT_ID)).is_equal(_state())


func test_clear_slot_on_a_never_rolled_slot_is_a_valid_clear() -> void:
	assert_bool(_execute("clear slot %s" % KEY)).is_true()
	assert_int(int(_state()["cleared_day"])).is_equal(WorldClock.day_index())
	assert_bool(SpawnDirector.validate_save_data(SaveGame.spawn_director.to_dict())).is_true()


func test_bad_targets_are_refused_and_change_nothing() -> void:
	var before: Dictionary = SaveGame.spawn_director.to_dict()
	for command: String in [
		"respawn now", "respawn later %s" % KEY, "respawn now nope", "respawn now %s:elsewhere" % TABLE_ID,
		"clear slot", "clear slot other-table:%s" % SLOT_ID,
	]:
		assert_bool(_execute(command)).override_failure_message(command).is_false()
		assert_str(_last()).starts_with("ERROR:")
	assert_dict(SaveGame.spawn_director.to_dict()).is_equal(before)
	assert_int(_hostiles().size()).is_equal(0)
	# The plain `clear` verb still clears the log.
	assert_bool(_execute("clear")).is_true()
	assert_str(_last()).is_equal("Cleared console log.")


func test_an_unhosted_model_refuses_the_verbs() -> void:
	var unhosted: Node = auto_free(DevConsoleScript.new()) as Node
	add_child(unhosted)
	var before: Dictionary = SaveGame.spawn_director.to_dict()
	assert_bool(bool(unhosted.call("execute_command", "respawn now %s" % KEY))).is_false()
	assert_bool(bool(unhosted.call("execute_command", "clear slot %s" % KEY))).is_false()
	assert_dict(SaveGame.spawn_director.to_dict()).is_equal(before)
	assert_int(_hostiles().size()).is_equal(0)
