extends GdUnitTestSuite
## Unit tests for the music context director (audio/music_director.gd).

const MusicDirectorScript := preload("res://audio/music_director.gd")

var director: Node


func before_test() -> void:
	director = auto_free(MusicDirectorScript.new() as Node)


func test_context_mapping_stable_ids() -> void:
	# Verify that the expected stable IDs exist in TRACK_MAP and map to expected file paths.
	var track_map: Dictionary = MusicDirectorScript.TRACK_MAP
	assert_bool(track_map.has("title")).is_true()
	assert_bool(track_map.has("field")).is_true()
	assert_bool(track_map.has("battle")).is_true()
	assert_bool(track_map.has("chapter_complete")).is_true()

	assert_str(track_map["title"]).is_equal("res://assets/audio/music/title.ogg")
	assert_str(track_map["field"]).is_equal("res://assets/audio/music/field.ogg")
	assert_str(track_map["battle"]).is_equal("res://assets/audio/music/battle.ogg")
	assert_str(track_map["chapter_complete"]).is_equal("res://assets/audio/music/chapter_complete.ogg")


func test_missing_asset_fallback_leaves_game_playable() -> void:
	# Requesting a context whose asset does not exist should update current_context
	# but not crash, logging a warning and falling back to silence cleanly.
	director.play_context("field")
	assert_str(director.get_current_context()).is_equal("field")
	assert_bool(is_instance_valid(director.get("_active_player"))).is_false()


func test_play_context_is_idempotent() -> void:
	# Repeated requests for the same context should be ignored and not trigger re-loading
	director.play_context("field")
	var initial_context = director.get_current_context()

	director.play_context("field")
	assert_str(director.get_current_context()).is_equal(initial_context)


func test_context_stack_battle_enter_exit() -> void:
	# Field music starts
	director.play_context("field")
	assert_str(director.get_current_context()).is_equal("field")
	assert_array(director.get_context_stack()).is_equal(["field"])

	# Enter battle: Battle music starts
	director.push_context("battle")
	assert_str(director.get_current_context()).is_equal("battle")
	assert_array(director.get_context_stack()).is_equal(["field", "battle"])

	# Exit battle: Resumes prior context (field)
	director.pop_context()
	assert_str(director.get_current_context()).is_equal("field")
	assert_array(director.get_context_stack()).is_equal(["field"])


func test_context_stack_push_duplicate_is_idempotent() -> void:
	# Pushing the same context consecutively should be idempotent
	director.push_context("field")
	director.push_context("field")
	assert_array(director.get_context_stack()).is_equal(["field"])


func test_pop_empty_stack_safely_falls_back() -> void:
	director.pop_context()
	assert_str(director.get_current_context()).is_equal("")
	assert_array(director.get_context_stack()).is_empty()
